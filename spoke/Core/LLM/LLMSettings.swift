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
    
    /// 当前选择的 Provider 类型
    var selectedProviderType: LLMProviderType? {
        didSet { save() }
    }
    
    /// 各 Provider 的配置
    var providerConfigs: [LLMProviderType: ProviderConfig] {
        didSet { save() }
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
    
    // MARK: - Computed
    
    /// 当前 Provider 配置
    var currentConfig: ProviderConfig? {
        guard let type = selectedProviderType else { return nil }
        return providerConfigs[type]
    }
    
    /// 是否已完整配置
    var isFullyConfigured: Bool {
        guard isEnabled,
              let type = selectedProviderType,
              let config = providerConfigs[type] else {
            return false
        }
        
        // 检查必要字段
        guard !config.baseURL.isEmpty, !config.modelName.isEmpty else {
            return false
        }
        
        // 需要 API Key 的检查 Keychain
        if type.requiresAPIKey {
            guard let keyRef = config.apiKeyRef,
                  KeychainService.exists(key: keyRef) else {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Init
    
    private init() {
        let defaults = UserDefaults.standard
        
        self.isEnabled = defaults.bool(forKey: Keys.isEnabled)
        
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
        
        self.systemPrompt = defaults.string(forKey: Keys.systemPrompt) ?? Self.defaultSystemPrompt
        self.includeClipboard = defaults.object(forKey: Keys.includeClipboard) as? Bool ?? false
        self.includeActiveApp = defaults.object(forKey: Keys.includeActiveApp) as? Bool ?? true
        self.temperature = defaults.object(forKey: Keys.temperature) as? Double ?? 0.3
        self.timeout = defaults.object(forKey: Keys.timeout) as? TimeInterval ?? 30
        
        // 迁移检查：如果当前 Prompt 是旧版默认值，自动更新到新版
        // v1: 最早的版本
        if self.systemPrompt.starts(with: "处理语音转写的文本：") {
            logger.info("♻️ Migrating v1 system prompt to new version")
            self.systemPrompt = Self.defaultSystemPrompt
        }
        // v2: "强制规则"版本
        else if self.systemPrompt.contains("修正策略（优先级从高到低）：") {
            logger.info("♻️ Migrating v2 system prompt to v4")
            self.systemPrompt = Self.defaultSystemPrompt
        }
        // v3: "上下文优先"版本（过于激进）
        else if self.systemPrompt.contains("你是 SpokenAnyWhere 的语音转写后处理专家") {
            logger.info("♻️ Migrating v3 system prompt to v4 (conservative)")
            self.systemPrompt = Self.defaultSystemPrompt
        }
        
        logger.info("📦 LLMSettings loaded, enabled: \(self.isEnabled)")
    }
    
    // MARK: - Public API
    
    /// 创建当前配置的 Provider
    func createCurrentProvider() -> (any LLMProvider)? {
        guard let type = selectedProviderType,
              let config = providerConfigs[type] else {
            return nil
        }
        
        return OpenAICompatibleProvider(providerType: type, config: config)
    }
    
    /// 设置 Provider 的 API Key
    func setAPIKey(_ apiKey: String, for type: LLMProviderType) throws {
        let keyRef = "apikey.\(type.rawValue)"
        try KeychainService.save(key: keyRef, value: apiKey)
        
        // 更新配置中的引用
        var config = providerConfigs[type] ?? ProviderConfig(
            baseURL: type.defaultBaseURL,
            modelName: type.defaultModel
        )
        config.apiKeyRef = keyRef
        providerConfigs[type] = config
        
        logger.info("🔑 API Key saved for \(type.displayName)")
    }
    
    /// 获取 Provider 的 API Key
    func getAPIKey(for type: LLMProviderType) -> String? {
        guard let config = providerConfigs[type],
              let keyRef = config.apiKeyRef else {
            return nil
        }
        return KeychainService.load(key: keyRef)
    }
    
    /// 删除 Provider 的 API Key
    func deleteAPIKey(for type: LLMProviderType) throws {
        guard let config = providerConfigs[type],
              let keyRef = config.apiKeyRef else {
            return
        }
        try KeychainService.delete(key: keyRef)
        
        // 清除配置中的引用
        var updatedConfig = config
        updatedConfig.apiKeyRef = nil
        providerConfigs[type] = updatedConfig
        
        logger.info("🗑️ API Key deleted for \(type.displayName)")
    }
    
    /// 使用默认配置初始化 Provider
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
        
        // 将 providerConfigs 转换为可编码格式
        var stringKeyedConfigs: [String: ProviderConfig] = [:]
        for (type, config) in providerConfigs {
            stringKeyedConfigs[type.rawValue] = config
        }
        if let data = try? JSONEncoder().encode(stringKeyedConfigs) {
            defaults.set(data, forKey: Keys.providerConfigs)
        }
        
        defaults.set(systemPrompt, forKey: Keys.systemPrompt)
        defaults.set(includeClipboard, forKey: Keys.includeClipboard)
        defaults.set(includeActiveApp, forKey: Keys.includeActiveApp)
        defaults.set(temperature, forKey: Keys.temperature)
        defaults.set(timeout, forKey: Keys.timeout)
    }
}
