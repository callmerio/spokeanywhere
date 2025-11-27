import Foundation
import os

/// OpenAI Compatible Provider
/// 兼容 OpenAI API 格式的通用实现
/// 支持: OpenAI, Groq, OpenRouter, Ollama, 等
actor OpenAICompatibleProvider: LLMProvider {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "LLM")
    
    let providerType: LLMProviderType
    private let config: ProviderConfig
    private let profile: ProviderProfile?
    private let providedAPIKey: String? // 直接传入的 API Key
    private let session: URLSession
    
    /// 请求超时时间（秒）
    private let timeout: TimeInterval = 30
    
    // MARK: - Computed (从 Profile 或 Config 获取)
    
    private var baseURL: String {
        profile?.baseURL ?? config.baseURL
    }
    
    private var modelName: String {
        profile?.modelName ?? config.modelName
    }
    
    // 这里的 apiKeyRef 仅用于旧版兼容
    private var apiKeyRef: String? {
        profile?.apiKeyRef ?? config.apiKeyRef
    }
    
    private var temperature: Double {
        profile?.temperature ?? 0.3
    }
    
    private var maxTokens: Int {
        profile?.maxTokens ?? 2048
    }
    
    // MARK: - Init
    
    /// 旧版初始化 (从 ProviderConfig)
    init(providerType: LLMProviderType, config: ProviderConfig) {
        self.providerType = providerType
        self.config = config
        self.profile = nil
        self.providedAPIKey = nil
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        self.session = URLSession(configuration: configuration)
    }
    
    /// 新版初始化 (从 ProviderProfile)
    /// - apiKey: 可选，直接传入 API Key，避免 Provider 内部访问 Keychain
    init(profile: ProviderProfile, apiKey: String? = nil) {
        self.providerType = profile.providerType
        self.profile = profile
        self.providedAPIKey = apiKey
        // 创建一个空的 config 作为 fallback
        self.config = ProviderConfig(baseURL: profile.baseURL, modelName: profile.modelName, apiKeyRef: profile.apiKeyRef)
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - LLMProvider
    
    nonisolated var isConfigured: Bool {
        // 优先检查 Profile
        let url = profile?.baseURL ?? config.baseURL
        let model = profile?.modelName ?? config.modelName
        
        // 检查必要配置
        guard !url.isEmpty, !model.isEmpty else {
            return false
        }
        
        // 如果直接提供了 API Key，则认为已配置
        if let apiKey = providedAPIKey, !apiKey.isEmpty {
            return true
        }
        
        // 不需要 API Key 的 Provider (如 Ollama)
        if !providerType.requiresAPIKey {
            return true
        }
        
        // 需要 API Key 但没有提供
        return false
    }
    
    func complete(prompt: LLMPrompt) async throws -> LLMResponse {
        guard isConfigured else {
            throw LLMError.notConfigured
        }
        
        let request = try buildRequest(prompt: prompt)
        
        logger.info("🤖 LLM request to \(self.providerType.displayName)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMError.invalidResponse
            }
            
            // 处理错误状态码
            switch httpResponse.statusCode {
            case 200...299:
                break
            case 401:
                throw LLMError.invalidAPIKey
            case 429:
                throw LLMError.rateLimited
            default:
                let message = String(data: data, encoding: .utf8)
                throw LLMError.serverError(httpResponse.statusCode, message)
            }
            
            return try parseResponse(data: data)
            
        } catch let error as LLMError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw LLMError.timeout
        } catch {
            throw LLMError.networkError(error)
        }
    }
    
    func testConnection() async throws -> Bool {
        // 发送一个简单的测试请求
        let testPrompt = LLMPrompt(
            systemPrompt: "You are a helpful assistant.",
            userMessage: "Say 'OK' if you can hear me."
        )
        
        do {
            let response = try await complete(prompt: testPrompt)
            return !response.text.isEmpty
        } catch let error as LLMError {
            logger.error("❌ Connection test failed (LLMError): \(error.localizedDescription)")
            throw error // 抛出具体错误供 UI 显示
        } catch {
            logger.error("❌ Connection test failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 获取可用模型列表
    /// 支持不同 Provider 的 API 格式差异
    func fetchModels() async -> [String] {
        let urlString = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        // 使用 providedAPIKey（由 LLMSettings 注入）
        let apiKey = providedAPIKey
        
        // 根据 provider 类型构建 URL 和请求
        let modelsURL: URL?
        var authHeader: (String, String)?
        
        switch providerType {
        case .googleGemini:
            // Gemini: GET /models?key={apiKey}
            // 响应: { models: [{ name: "models/gemini-1.5-flash" }] }
            if let key = apiKey {
                modelsURL = URL(string: "\(urlString)/models?key=\(key)")
            } else {
                modelsURL = URL(string: "\(urlString)/models")
            }
            
        case .anthropic:
            // Anthropic: GET /v1/models, Header: x-api-key
            // 响应: { data: [{ id: "claude-3-opus-20240229" }] }
            modelsURL = URL(string: "\(urlString)/models")
            if let key = apiKey {
                authHeader = ("x-api-key", key)
            }
            
        case .ollama:
            // Ollama: GET /api/tags (不是 /models)
            // 响应: { models: [{ name: "llama3:latest" }] }
            modelsURL = URL(string: "\(urlString.replacingOccurrences(of: "/v1", with: ""))/api/tags")
            
        case .openRouter:
            // OpenRouter: GET /api/v1/models, Header: Authorization Bearer
            // 响应: { data: [{ id: "openai/gpt-4" }] }
            modelsURL = URL(string: "\(urlString)/models")
            if let key = apiKey {
                authHeader = ("Authorization", "Bearer \(key)")
            }
            
        case .groq:
            // Groq: GET /openai/v1/models, Header: Authorization Bearer
            // 响应: { data: [{ id: "llama-3.1-70b-versatile" }] }
            modelsURL = URL(string: "\(urlString)/models")
            if let key = apiKey {
                authHeader = ("Authorization", "Bearer \(key)")
            }
            
        case .openai, .openAICompatible:
            // OpenAI 标准: GET /models, Header: Authorization Bearer
            // 响应: { data: [{ id: "gpt-4" }] }
            modelsURL = URL(string: "\(urlString)/models")
            if let key = apiKey {
                authHeader = ("Authorization", "Bearer \(key)")
            }
        }
        
        guard let url = modelsURL else {
            logger.warning("⚠️ Invalid URL for models endpoint")
            return []
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        
        // 添加认证头
        if let (headerName, headerValue) = authHeader {
            request.setValue(headerValue, forHTTPHeaderField: headerName)
        }
        
        // Anthropic 需要额外的版本头
        if providerType == .anthropic {
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                logger.warning("⚠️ Models endpoint returned status \(statusCode)")
                return []
            }
            
            return parseModelsResponse(data: data)
            
        } catch {
            logger.warning("⚠️ Failed to fetch models: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 解析不同格式的 models 响应
    private func parseModelsResponse(data: Data) -> [String] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.warning("⚠️ Failed to parse models response as JSON")
            return []
        }
        
        var models: [String] = []
        
        switch providerType {
        case .googleGemini:
            // Gemini: { models: [{ name: "models/gemini-1.5-flash", ... }] }
            if let modelsArray = json["models"] as? [[String: Any]] {
                models = modelsArray.compactMap { model -> String? in
                    guard let name = model["name"] as? String else { return nil }
                    // 过滤掉 embedding 模型，只保留生成模型
                    if name.contains("embedding") { return nil }
                    return name.replacingOccurrences(of: "models/", with: "")
                }
            }
            
        case .ollama:
            // Ollama: { models: [{ name: "llama3:latest", ... }] }
            if let modelsArray = json["models"] as? [[String: Any]] {
                models = modelsArray.compactMap { $0["name"] as? String }
            }
            
        case .openai, .anthropic, .groq, .openRouter, .openAICompatible:
            // OpenAI 标准格式: { data: [{ id: "gpt-4", ... }] }
            if let dataArray = json["data"] as? [[String: Any]] {
                models = dataArray.compactMap { $0["id"] as? String }
            }
        }
        
        if models.isEmpty {
            logger.warning("⚠️ No models found in response")
        } else {
            logger.info("✅ Fetched \(models.count) models from \(self.providerType.displayName)")
        }
        
        return models.sorted()
    }
    
    // MARK: - Private
    
    private func buildRequest(prompt: LLMPrompt) throws -> URLRequest {
        let urlString = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        // 使用 providedAPIKey（由 LLMSettings 注入）
        let apiKey = providedAPIKey
        
        if providerType == .googleGemini {
            return try buildGeminiRequest(urlString: urlString, apiKey: apiKey, prompt: prompt)
        }
        
        // OpenAI Compatible Request
        guard let url = URL(string: "\(urlString)/chat/completions") else {
            throw LLMError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加 API Key
        if let key = apiKey {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        
        // Anthropic 需要额外的版本头
        if providerType == .anthropic {
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            // Anthropic 不使用 Bearer Token
            request.setValue(nil, forHTTPHeaderField: "Authorization")
        }
        
        // 构建请求体
        var messages: [[String: String]] = []
        
        // System prompt
        if !prompt.systemPrompt.isEmpty {
            messages.append([
                "role": "system",
                "content": prompt.systemPrompt
            ])
        }
        
        // User message
        messages.append([
            "role": "user",
            "content": prompt.userMessage
        ])
        
        let body: [String: Any] = [
            "model": modelName,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": maxTokens
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return request
    }
    
    private func buildGeminiRequest(urlString: String, apiKey: String?, prompt: LLMPrompt) throws -> URLRequest {
        // Gemini: POST /models/{model}:generateContent?key={apiKey}
        guard let key = apiKey else { throw LLMError.invalidAPIKey }
        
        let model = modelName.isEmpty ? "gemini-pro" : modelName
        // 处理可能包含 "models/" 前缀的情况
        let cleanModelName = model.replacingOccurrences(of: "models/", with: "")
        
        guard let url = URL(string: "\(urlString)/models/\(cleanModelName):generateContent?key=\(key)") else {
            throw LLMError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 构建 Gemini 请求体
        // {
        //   "contents": [{ "role": "user", "parts": [{ "text": "..." }] }],
        //   "systemInstruction": { "parts": [{ "text": "..." }] },
        //   "generationConfig": { ... }
        // }
        
        var body: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": prompt.userMessage]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": temperature,
                "maxOutputTokens": maxTokens
            ]
        ]
        
        if !prompt.systemPrompt.isEmpty {
            body["systemInstruction"] = [
                "parts": [
                    ["text": prompt.systemPrompt]
                ]
            ]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
    
    private func parseResponse(data: Data) throws -> LLMResponse {
        if providerType == .googleGemini {
            return try parseGeminiResponse(data: data)
        }
        
        // 解析 OpenAI 格式响应
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.invalidResponse
        }
        
        // 检查 Anthropic 错误格式
        if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
            throw LLMError.serverError(400, message)
        }
        
        // 兼容 Anthropic 响应格式 (content 是数组)
        if let contentArray = json["content"] as? [[String: Any]],
           let firstContent = contentArray.first,
           let text = firstContent["text"] as? String {
            return LLMResponse(text: text.trimmingCharacters(in: .whitespacesAndNewlines), usage: nil)
        }
        
        // 标准 OpenAI 格式
        if let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedContent.isEmpty { throw LLMError.emptyResponse }
            
            // 解析 usage
            var usage: TokenUsage?
            if let usageJson = json["usage"] as? [String: Any] {
                usage = TokenUsage(
                    promptTokens: usageJson["prompt_tokens"] as? Int,
                    completionTokens: usageJson["completion_tokens"] as? Int,
                    totalTokens: usageJson["total_tokens"] as? Int
                )
            }
            
            logger.info("✅ LLM response received (\(trimmedContent.count) chars)")
            return LLMResponse(text: trimmedContent, usage: usage)
        }
        
        logger.error("❌ Failed to parse response: \(String(data: data, encoding: .utf8) ?? "nil")")
        throw LLMError.invalidResponse
    }
    
    private func parseGeminiResponse(data: Data) throws -> LLMResponse {
        // Gemini: { "candidates": [{ "content": { "parts": [{ "text": "..." }] } }] }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.invalidResponse
        }
        
        // 检查错误
        if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
            throw LLMError.serverError(400, message)
        }
        
        guard let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            logger.error("❌ Failed to parse Gemini response: \(String(data: data, encoding: .utf8) ?? "nil")")
            throw LLMError.invalidResponse
        }
        
        let trimmedContent = text.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.info("✅ Gemini response received (\(trimmedContent.count) chars)")
        
        return LLMResponse(text: trimmedContent, usage: nil)
    }
}
