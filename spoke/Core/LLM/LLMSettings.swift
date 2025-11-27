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
    你是语音转写后处理专家。请修正以下语音转写文本：

    修正规则：
    1. 参考剪贴板历史中的专业术语、人名、项目名，修正听错的词（如 "mirroday" → "mirrored"）
    2. 使用逆文本标准化 (ITN)：数字、日期、单位等转为规范格式
    3. 中西文混排时添加空格（如 "使用Docker" → "使用 Docker"）
    4. 移除口语填充词：嗯、啊、那个、就是说
    5. 修正重复和磕巴
    6. 保持原意，不要过度改写

    重要：如果剪贴板历史中有相关术语，优先使用历史中的正确拼写。

    只输出修正后的文本，不要解释。
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
