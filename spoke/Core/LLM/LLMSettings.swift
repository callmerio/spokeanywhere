import Foundation
import os

/// LLM 设置管理
/// 管理 LLM Provider 配置、Prompt 等
@Observable
@MainActor
final class LLMSettings {
    
    // MARK: - Singleton
    
    static let shared = LLMSettings()
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "LLMSettings")
    
    // MARK: - UserDefaults Keys
    
    private enum Keys {
        static let isEnabled = "llm.isEnabled"
        static let selectedProvider = "llm.selectedProvider"
        static let providerConfigs = "llm.providerConfigs"
        static let systemPrompt = "llm.systemPrompt"
        static let includeClipboard = "llm.includeClipboard"
        static let includeActiveApp = "llm.includeActiveApp"
        static let temperature = "llm.temperature"
        static let timeout = "llm.timeout"
        // 新版 Profile 系统
        static let profiles = "llm.profiles"
        static let selectedProfileId = "llm.selectedProfileId"
        static let hasMigrated = "llm.hasMigratedToProfiles"
        static let hasConsolidatedAPIKeys = "llm.hasConsolidatedAPIKeys"
        static let transcriptionProfileId = "llm.transcriptionProfileId"
        static let chatProfileId = "llm.chatProfileId"
        // AI 生成标题
        static let aiGeneratedTitleEnabled = "llm.aiGeneratedTitleEnabled"
    }
    
    // MARK: - Default Prompt
    
    static let defaultSystemPrompt = """
    你是语音转写后处理专家。任务：清洗口语 + 消歧义技术术语。

    规则：
    1. **保留原意**：中文句子结构不变，只清理口语填充词（嗯、啊、那个）。
    2. **术语消歧义**：
       - 仅当转写中的**英文/拼音词**发音接近<剪贴板历史>中的某个术语时，才替换为该术语。
       - 例：转写"default system prompt" + 历史有"defaultSystemPrompt" → 输出"defaultSystemPrompt"
       - 例：转写"我要修改" + 历史有"defaultSystemPrompt" → 输出"我要修改"（中文不变）
    3. **同音纠错**：修正明显错别字（如 "脱风"→"驼峰"，"rodmap"→"roadmap"）。
    4. **中西文空格**：中文与英文/数字之间加空格。

    <剪贴板历史>仅用于消歧义，不要把无关内容塞进输出。
    只输出最终文本。
    """
    
    // MARK: - Properties
    
    /// 是否启用 LLM 处理
    var isEnabled: Bool {
        didSet { save() }
    }
    
    /// 当前选择的 Provider 类型 (旧版，保留兼容)
    var selectedProviderType: LLMProviderType? {
        didSet { save() }
    }
    
    /// 各 Provider 的配置 (旧版，保留兼容)
    var providerConfigs: [LLMProviderType: ProviderConfig] {
        didSet { save() }
    }
    
    // MARK: - Profile System (新版)
    
    /// 所有配置文件
    var profiles: [ProviderProfile] {
        didSet { save() }
    }
    
    /// 当前选中的 Profile ID
    var selectedProfileId: UUID? {
        didSet { save() }
    }
    
    /// 当前选中的 Profile
    var selectedProfile: ProviderProfile? {
        guard let id = selectedProfileId else { return nil }
        return profiles.first { $0.id == id }
    }
    
    /// 按 Provider 类型分组的 Profiles
    var profilesByProvider: [LLMProviderType: [ProviderProfile]] {
        Dictionary(grouping: profiles, by: \.providerType)
    }
    
    /// 系统提示词
    var systemPrompt: String {
        didSet { save() }
    }
    
    /// 是否包含剪贴板内容作为上下文
    var includeClipboard: Bool {
        didSet { save() }
    }
    
    /// 是否包含当前活跃 App 名称作为上下文
    var includeActiveApp: Bool {
        didSet { save() }
    }
    
    /// Temperature (0.0 - 1.0)
    var temperature: Double {
        didSet { save() }
    }
    
    /// 请求超时时间（秒）
    var timeout: TimeInterval {
        didSet { save() }
    }
    
    /// AI 生成标题（用于历史记录）
    var aiGeneratedTitleEnabled: Bool {
        didSet { save() }
    }
    
    // MARK: - Role Based Profiles
    
    /// 转录模型 Profile ID
    var transcriptionProfileId: UUID? {
        didSet { save() }
    }
    
    /// 对话模型 Profile ID
    var chatProfileId: UUID? {
        didSet { save() }
    }
    
    /// 获取转录模型 Profile
    var transcriptionProfile: ProviderProfile? {
        guard let id = transcriptionProfileId else { return nil }
        return profiles.first { $0.id == id }
    }
    
    /// 获取对话模型 Profile
    var chatProfile: ProviderProfile? {
        guard let id = chatProfileId else { return nil }
        return profiles.first { $0.id == id }
    }
    
    // MARK: - Computed
    
    /// 当前 Provider 配置
    var currentConfig: ProviderConfig? {
        guard let type = selectedProviderType else { return nil }
        return providerConfigs[type]
    }
    
    /// 是否已完整配置 (基于新版 Profile)
    var isFullyConfigured: Bool {
        guard isEnabled, let profile = selectedProfile else {
            return false
        }
        
        // 检查必要字段
        guard !profile.baseURL.isEmpty, !profile.modelName.isEmpty else {
            return false
        }
        
        // 需要 API Key 的检查（从内存缓存读取，不访问 Keychain）
        if profile.providerType.requiresAPIKey {
            guard hasAPIKey(for: profile.id) else {
                return false
            }
        }
        
        return true
    }
    
    /// 当前 Provider 名称（用于显示）
    var currentProviderName: String {
        if let profile = selectedProfile {
            return profile.name.isEmpty ? profile.modelName : profile.name
        }
        return selectedProviderType?.rawValue ?? "Unknown"
    }
    
    // MARK: - Init
    
    private init() {
        let defaults = UserDefaults.standard
        
        self.isEnabled = defaults.bool(forKey: Keys.isEnabled)
        
        // 加载旧版配置（兼容）
        if let rawValue = defaults.string(forKey: Keys.selectedProvider) {
            self.selectedProviderType = LLMProviderType(rawValue: rawValue)
        } else {
            self.selectedProviderType = nil
        }
        
        if let data = defaults.data(forKey: Keys.providerConfigs),
           let configs = try? JSONDecoder().decode([String: ProviderConfig].self, from: data) {
            var typedConfigs: [LLMProviderType: ProviderConfig] = [:]
            for (key, value) in configs {
                if let type = LLMProviderType(rawValue: key) {
                    typedConfigs[type] = value
                }
            }
            self.providerConfigs = typedConfigs
        } else {
            self.providerConfigs = [:]
        }
        
        // 加载新版 Profile 系统
        if let data = defaults.data(forKey: Keys.profiles),
           let loadedProfiles = try? JSONDecoder().decode([ProviderProfile].self, from: data) {
            self.profiles = loadedProfiles
        } else {
            self.profiles = []
        }
        
        if let idString = defaults.string(forKey: Keys.selectedProfileId),
           let uuid = UUID(uuidString: idString) {
            self.selectedProfileId = uuid
        } else {
            self.selectedProfileId = nil
        }
        
        if let idString = defaults.string(forKey: Keys.transcriptionProfileId),
           let uuid = UUID(uuidString: idString) {
            self.transcriptionProfileId = uuid
        } else {
            self.transcriptionProfileId = nil
        }
        
        if let idString = defaults.string(forKey: Keys.chatProfileId),
           let uuid = UUID(uuidString: idString) {
            self.chatProfileId = uuid
        } else {
            self.chatProfileId = nil
        }
        
        self.systemPrompt = defaults.string(forKey: Keys.systemPrompt) ?? Self.defaultSystemPrompt
        self.includeClipboard = defaults.object(forKey: Keys.includeClipboard) as? Bool ?? false
        self.includeActiveApp = defaults.object(forKey: Keys.includeActiveApp) as? Bool ?? true
        self.temperature = defaults.object(forKey: Keys.temperature) as? Double ?? 0.3
        self.timeout = defaults.object(forKey: Keys.timeout) as? TimeInterval ?? 30
        self.aiGeneratedTitleEnabled = defaults.object(forKey: Keys.aiGeneratedTitleEnabled) as? Bool ?? false
        
        // 迁移旧数据到新 Profile 系统
        if !defaults.bool(forKey: Keys.hasMigrated) && !providerConfigs.isEmpty {
            migrateToProfiles()
            defaults.set(true, forKey: Keys.hasMigrated)
        }
        
        // Prompt 迁移检查
        if self.systemPrompt.starts(with: "处理语音转写的文本：") {
            logger.info("♻️ Migrating v1 system prompt to new version")
            self.systemPrompt = Self.defaultSystemPrompt
        } else if self.systemPrompt.contains("修正策略（优先级从高到低）：") {
            logger.info("♻️ Migrating v2 system prompt to v4")
            self.systemPrompt = Self.defaultSystemPrompt
        } else if self.systemPrompt.contains("你是 SpokenAnyWhere 的语音转写后处理专家") {
            logger.info("♻️ Migrating v3 system prompt to v4 (conservative)")
            self.systemPrompt = Self.defaultSystemPrompt
        }
        
        // 加载并合并 API Keys
        consolidateLegacyAPIKeys()
        
        logger.info("📦 LLMSettings loaded, enabled: \(self.isEnabled), profiles: \(self.profiles.count)")
    }
    
    /// 从旧版配置迁移到 Profile 系统
    private func migrateToProfiles() {
        logger.info("🔄 Migrating legacy configs to Profile system...")
        
        for (type, config) in providerConfigs {
            let profile = ProviderProfile.migrate(from: config, type: type)
            profiles.append(profile)
            
            // 如果是之前选中的 Provider，设为当前 Profile
            if type == selectedProviderType {
                selectedProfileId = profile.id
            }
        }
        
        logger.info("✅ Migrated \(self.profiles.count) profiles")
    }
    
    /// 合并遗留的 API Key 到统一存储
    private func consolidateLegacyAPIKeys() {
        let defaults = UserDefaults.standard
        
        // 1. 加载统一存储
        loadAllAPIKeys()
        
        // 2. 如果已经完成迁移，直接返回（不再尝试读取遗留 Key）
        if defaults.bool(forKey: Keys.hasConsolidatedAPIKeys) {
            logger.info("🔓 API keys already consolidated, skipping migration")
            return
        }
        
        var hasChanges = false
        
        // 3. 检查所有 Profile，尝试迁移遗留 Key
        for i in profiles.indices {
            let profile = profiles[i]
            
            // 如果缓存中没有 Key，但 Profile 有遗留引用 (且不是 "unified_storage")
            if apiKeysCache[profile.id.uuidString] == nil,
               let keyRef = profile.apiKeyRef,
               keyRef != "unified_storage" {
                
                logger.info("📥 Consolidating legacy key for profile: \(profile.name)")
                
                // 尝试从旧 Keychain Item 读取
                if let legacyKey = KeychainService.load(key: keyRef) {
                    // 存入缓存
                    apiKeysCache[profile.id.uuidString] = legacyKey
                    
                    // 更新 Profile 标记
                    profiles[i].apiKeyRef = "unified_storage"
                    profiles[i].updatedAt = Date()
                    
                    hasChanges = true
                }
            }
        }
        
        // 4. 保存迁移结果
        if hasChanges {
            saveAllAPIKeys()
            save() // 保存 Profile 的 apiKeyRef 更新
            logger.info("✅ Consolidated legacy API keys to unified storage")
        }
        
        // 5. 标记迁移完成（即使没有任何 Key 需要迁移，也标记为完成）
        defaults.set(true, forKey: Keys.hasConsolidatedAPIKeys)
    }
    
    // MARK: - Profile CRUD
    
    /// 创建新的 Profile
    @discardableResult
    func createProfile(for type: LLMProviderType, name: String? = nil) -> ProviderProfile {
        let profileName = name ?? "\(type.displayName)"
        let profile = ProviderProfile(name: profileName, providerType: type)
        profiles.append(profile)
        logger.info("➕ Created profile: \(profileName)")
        return profile
    }
    
    /// 更新 Profile
    func updateProfile(_ profile: ProviderProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
            logger.warning("⚠️ Profile not found: \(profile.id)")
            return
        }
        var updated = profile
        updated.updatedAt = Date()
        profiles[index] = updated
        logger.info("📝 Updated profile: \(profile.name)")
    }
    
    /// 删除 Profile
    func deleteProfile(_ profileId: UUID) {
        guard let index = profiles.firstIndex(where: { $0.id == profileId }) else {
            return
        }
        let profile = profiles[index]
        
        // 删除关联的 API Key
        if let keyRef = profile.apiKeyRef {
            try? KeychainService.delete(key: keyRef)
        }
        
        profiles.remove(at: index)
        
        // 如果删除的是当前选中的，清除选择
        if selectedProfileId == profileId {
            selectedProfileId = profiles.first?.id
        }
        
        logger.info("🗑️ Deleted profile: \(profile.name)")
    }
    
    /// 复制 Profile
    @discardableResult
    func duplicateProfile(_ profileId: UUID) -> ProviderProfile? {
        guard let source = profiles.first(where: { $0.id == profileId }) else {
            return nil
        }
        
        let newProfile = ProviderProfile(
            name: "\(source.name) (副本)",
            providerType: source.providerType,
            baseURL: source.baseURL,
            modelName: source.modelName,
            temperature: source.temperature,
            maxTokens: source.maxTokens,
            contextWindow: source.contextWindow,
            reasoningEffort: source.reasoningEffort,
            enableURLContext: source.enableURLContext,
            enableSearchGrounding: source.enableSearchGrounding
        )
        // 注意：不复制 apiKeyRef，需要用户重新设置
        profiles.append(newProfile)
        logger.info("📋 Duplicated profile: \(source.name) -> \(newProfile.name)")
        return newProfile
    }
    
    /// 设置 Profile 的 API Key
    func setAPIKey(_ apiKey: String, for profileId: UUID) throws {
        guard let index = profiles.firstIndex(where: { $0.id == profileId }) else {
            throw LLMError.notConfigured
        }
        
        // 使用 profile ID 作为 key
        apiKeysCache[profileId.uuidString] = apiKey
        saveAllAPIKeys()
        
        // 标记已设置（不需要实际的 keyRef 了，但为了兼容性保留字段逻辑）
        profiles[index].apiKeyRef = "unified_storage" 
        profiles[index].updatedAt = Date()
        
        logger.info("🔑 API Key saved for profile: \(self.profiles[index].name)")
    }
    
    /// 获取 Profile 的 API Key
    func getAPIKey(for profileId: UUID) -> String? {
        return apiKeysCache[profileId.uuidString]
    }
    
    /// 检查 Profile 是否有 API Key
    func hasAPIKey(for profileId: UUID) -> Bool {
        return apiKeysCache[profileId.uuidString] != nil
    }
    
    // MARK: - API Key Management (Unified Storage)
    
    private let allAPIKeysStorageKey = "spoke_all_api_keys_v1"
    private var apiKeysCache: [String: String] = [:]
    
    private func loadAllAPIKeys() {
        // 尝试加载统一存储的 Keys
        if let jsonString = KeychainService.load(key: allAPIKeysStorageKey),
           let data = jsonString.data(using: .utf8),
           let keys = try? JSONDecoder().decode([String: String].self, from: data) {
            self.apiKeysCache = keys
            logger.info("🔓 Loaded \(keys.count) API keys from unified storage")
        }
    }
    
    private func saveAllAPIKeys() {
        guard let data = try? JSONEncoder().encode(apiKeysCache),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }
        try? KeychainService.save(key: allAPIKeysStorageKey, value: jsonString)
        logger.info("🔒 Saved API keys to unified storage")
    }
    
    // MARK: - Provider Creation
    
    /// 创建当前配置的 Provider (基于新版 Profile)
    func createCurrentProvider() -> (any LLMProvider)? {
        guard let profile = selectedProfile else { return nil }
        // 直接注入 API Key，避免 Provider 再次访问 Keychain
        let apiKey = getAPIKey(for: profile.id)
        return OpenAICompatibleProvider(profile: profile, apiKey: apiKey)
    }
    
    /// 根据指定 Profile 创建 Provider
    func createProvider(for profile: ProviderProfile) -> (any LLMProvider)? {
        let apiKey = getAPIKey(for: profile.id)
        return OpenAICompatibleProvider(profile: profile, apiKey: apiKey)
    }
    
    /// 获取 Profile 对应的可用模型列表
    func fetchModels(for profile: ProviderProfile) async -> [String] {
        let apiKey = getAPIKey(for: profile.id)
        let provider = OpenAICompatibleProvider(profile: profile, apiKey: apiKey)
        return await provider.fetchModels()
    }
    
    // MARK: - Legacy API (保留兼容)
    
    /// 设置 Provider 的 API Key (旧版)
    func setAPIKey(_ apiKey: String, for type: LLMProviderType) throws {
        let keyRef = "apikey.\(type.rawValue)"
        try KeychainService.save(key: keyRef, value: apiKey)
        
        var config = providerConfigs[type] ?? ProviderConfig(
            baseURL: type.defaultBaseURL,
            modelName: type.defaultModel
        )
        config.apiKeyRef = keyRef
        providerConfigs[type] = config
        
        logger.info("🔑 API Key saved for \(type.displayName)")
    }
    
    /// 获取 Provider 的 API Key (旧版)
    func getAPIKey(for type: LLMProviderType) -> String? {
        guard let config = providerConfigs[type],
              let keyRef = config.apiKeyRef else {
            return nil
        }
        return KeychainService.load(key: keyRef)
    }
    
    /// 删除 Provider 的 API Key (旧版)
    func deleteAPIKey(for type: LLMProviderType) throws {
        guard let config = providerConfigs[type],
              let keyRef = config.apiKeyRef else {
            return
        }
        try KeychainService.delete(key: keyRef)
        
        var updatedConfig = config
        updatedConfig.apiKeyRef = nil
        providerConfigs[type] = updatedConfig
        
        logger.info("🗑️ API Key deleted for \(type.displayName)")
    }
    
    /// 使用默认配置初始化 Provider (旧版)
    func initializeProvider(_ type: LLMProviderType) {
        if providerConfigs[type] == nil {
            providerConfigs[type] = ProviderConfig(
                baseURL: type.defaultBaseURL,
                modelName: type.defaultModel
            )
        }
    }
    
    /// 重置为默认 Prompt
    func resetToDefaultPrompt() {
        systemPrompt = Self.defaultSystemPrompt
    }
    
    // MARK: - Private
    
    private func save() {
        let defaults = UserDefaults.standard
        
        defaults.set(isEnabled, forKey: Keys.isEnabled)
        defaults.set(selectedProviderType?.rawValue, forKey: Keys.selectedProvider)
        
        // 保存旧版 providerConfigs（兼容）
        var stringKeyedConfigs: [String: ProviderConfig] = [:]
        for (type, config) in providerConfigs {
            stringKeyedConfigs[type.rawValue] = config
        }
        if let data = try? JSONEncoder().encode(stringKeyedConfigs) {
            defaults.set(data, forKey: Keys.providerConfigs)
        }
        
        // 保存新版 Profile 系统
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: Keys.profiles)
        }
        defaults.set(selectedProfileId?.uuidString, forKey: Keys.selectedProfileId)
        defaults.set(transcriptionProfileId?.uuidString, forKey: Keys.transcriptionProfileId)
        defaults.set(chatProfileId?.uuidString, forKey: Keys.chatProfileId)
        
        defaults.set(systemPrompt, forKey: Keys.systemPrompt)
        defaults.set(includeClipboard, forKey: Keys.includeClipboard)
        defaults.set(includeActiveApp, forKey: Keys.includeActiveApp)
        defaults.set(temperature, forKey: Keys.temperature)
        defaults.set(timeout, forKey: Keys.timeout)
        defaults.set(aiGeneratedTitleEnabled, forKey: Keys.aiGeneratedTitleEnabled)
    }
    
    // MARK: - AI Title Generation
    
    /// AI 生成标题的 Prompt
    static let titleGenerationPrompt = """
    为以下对话内容生成一个简洁的标题（10字以内）。
    只输出标题本身，不要加任何标点或引号。
    """
    
    /// 使用 AI 生成标题
    func generateTitle(from content: String) async -> String? {
        guard aiGeneratedTitleEnabled,
              let profile = chatProfile ?? selectedProfile,
              let provider = createProvider(for: profile) else {
            return nil
        }
        
        let prompt = LLMPrompt(
            systemPrompt: Self.titleGenerationPrompt,
            userMessage: content
        )
        
        do {
            let response = try await provider.complete(prompt: prompt)
            let title = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            // 限制长度
            return String(title.prefix(20))
        } catch {
            logger.error("❌ AI title generation failed: \(error)")
            return nil
        }
    }
}
