import Foundation

// MARK: - LLM Prompt

/// LLM 请求消息
struct LLMPrompt {
    let systemPrompt: String
    let userMessage: String
    let contextAppName: String?
    
    init(systemPrompt: String, userMessage: String, contextAppName: String? = nil) {
        self.systemPrompt = systemPrompt
        self.userMessage = userMessage
        self.contextAppName = contextAppName
    }
}

// MARK: - LLM Response

/// Token 使用统计
struct TokenUsage: Codable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

/// LLM 响应
struct LLMResponse {
    let text: String
    let usage: TokenUsage?
    
    init(text: String, usage: TokenUsage? = nil) {
        self.text = text
        self.usage = usage
    }
}

// MARK: - LLM Error

/// LLM 错误类型
enum LLMError: LocalizedError {
    case notConfigured
    case invalidAPIKey
    case networkError(Error)
    case invalidResponse
    case emptyResponse
    case timeout
    case rateLimited
    case serverError(Int, String?)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "LLM Provider 未配置"
        case .invalidAPIKey:
            return "API Key 无效"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .invalidResponse:
            return "响应格式无效"
        case .emptyResponse:
            return "响应内容为空"
        case .timeout:
            return "请求超时"
        case .rateLimited:
            return "请求频率受限"
        case .serverError(let code, let message):
            return "服务器错误 (\(code)): \(message ?? "未知")"
        }
    }
}

// MARK: - Provider Type

/// LLM Provider 类型
enum LLMProviderType: String, CaseIterable, Codable, Identifiable {
    case ollama
    case openai
    case anthropic
    case googleGemini
    case groq
    case openRouter
    case openAICompatible
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .ollama: return "Ollama (本地)"
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic (Claude)"
        case .googleGemini: return "Google Gemini"
        case .groq: return "Groq"
        case .openRouter: return "OpenRouter"
        case .openAICompatible: return "OpenAI Compatible"
        }
    }
    
    var defaultBaseURL: String {
        switch self {
        case .ollama: return "http://localhost:11434/v1"
        case .openai: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com/v1"
        case .googleGemini: return "https://generativelanguage.googleapis.com/v1beta"
        case .groq: return "https://api.groq.com/openai/v1"
        case .openRouter: return "https://openrouter.ai/api/v1"
        case .openAICompatible: return ""
        }
    }
    
    var defaultModel: String {
        switch self {
        case .ollama: return "llama3.2"
        case .openai: return "gpt-4o-mini"
        case .anthropic: return "claude-3-haiku-20240307"
        case .googleGemini: return "gemini-1.5-flash"
        case .groq: return "llama-3.1-8b-instant"
        case .openRouter: return "openai/gpt-4o-mini"
        case .openAICompatible: return ""
        }
    }
    
    /// 是否需要 API Key
    var requiresAPIKey: Bool {
        switch self {
        case .ollama: return false
        default: return true
        }
    }
}

// MARK: - Provider Config (Legacy - 保留兼容)

/// Provider 配置 (旧版，用于迁移)
struct ProviderConfig: Codable, Equatable {
    var baseURL: String
    var modelName: String
    var apiKeyRef: String?  // Keychain 中的 key 引用
    
    init(baseURL: String = "", modelName: String = "", apiKeyRef: String? = nil) {
        self.baseURL = baseURL
        self.modelName = modelName
        self.apiKeyRef = apiKeyRef
    }
}

// MARK: - Provider Profile (新版)

/// AI 配置文件
/// 支持同一 Provider 创建多个配置
struct ProviderProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String                    // 配置名称，如 "Gemini Pro"
    var providerType: LLMProviderType   // Provider 类型
    var baseURL: String                 // API 地址
    var modelName: String               // 模型名称
    var apiKeyRef: String?              // Keychain 中的 key 引用
    
    // 高级参数
    var temperature: Double             // 温度 0.0-2.0
    var maxTokens: Int?                 // 最大输出 token
    var contextWindow: Int              // 上下文窗口大小
    var reasoningEffort: ReasoningEffort // 推理深度
    
    // 增强功能
    var enableURLContext: Bool          // 启用 URL 上下文
    var enableSearchGrounding: Bool     // 启用搜索增强
    
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        providerType: LLMProviderType,
        baseURL: String? = nil,
        modelName: String? = nil,
        apiKeyRef: String? = nil,
        temperature: Double = 0.3,
        maxTokens: Int? = nil,
        contextWindow: Int = 128_000,
        reasoningEffort: ReasoningEffort = .medium,
        enableURLContext: Bool = false,
        enableSearchGrounding: Bool = false
    ) {
        self.id = id
        self.name = name
        self.providerType = providerType
        self.baseURL = baseURL ?? providerType.defaultBaseURL
        self.modelName = modelName ?? providerType.defaultModel
        self.apiKeyRef = apiKeyRef
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.contextWindow = contextWindow
        self.reasoningEffort = reasoningEffort
        self.enableURLContext = enableURLContext
        self.enableSearchGrounding = enableSearchGrounding
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// 从旧版 ProviderConfig 迁移
    static func migrate(from config: ProviderConfig, type: LLMProviderType) -> ProviderProfile {
        ProviderProfile(
            name: type.displayName,
            providerType: type,
            baseURL: config.baseURL,
            modelName: config.modelName,
            apiKeyRef: config.apiKeyRef
        )
    }
}

// MARK: - Reasoning Effort

/// 推理深度
enum ReasoningEffort: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }
    
    var description: String {
        switch self {
        case .low: return "快速响应，适合简单任务"
        case .medium: return "平衡速度与质量"
        case .high: return "深度思考，适合复杂任务"
        }
    }
}

// MARK: - LLM Provider Protocol

/// LLM Provider 协议
/// 所有 LLM 后端必须实现此协议
protocol LLMProvider {
    /// Provider 类型
    var providerType: LLMProviderType { get }
    
    /// 显示名称
    var displayName: String { get }
    
    /// 是否已配置
    var isConfigured: Bool { get }
    
    /// 执行补全请求
    func complete(prompt: LLMPrompt) async throws -> LLMResponse
    
    /// 测试连接
    func testConnection() async throws -> Bool
}

extension LLMProvider {
    var displayName: String {
        providerType.displayName
    }
}
