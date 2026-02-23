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
    private let timeout: TimeInterval

    /// Temperature 参数
    private let temperature: Double

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
    
    private var maxTokens: Int {
        // 默认 16384 tokens，覆盖主流模型最大输出
        // GPT-4o: 16384, Claude: 4096, Gemini 2.0: 8192
        profile?.maxTokens ?? 16384
    }
    
    private var enableThinking: Bool {
        profile?.enableThinking ?? true
    }
    
    private var enableSearchGrounding: Bool {
        profile?.enableSearchGrounding ?? false
    }
    
    // MARK: - Init
    
    /// 旧版初始化 (从 ProviderConfig)
    init(providerType: LLMProviderType, config: ProviderConfig, timeout: TimeInterval = 30, temperature: Double = 0.3) {
        self.providerType = providerType
        self.config = config
        self.profile = nil
        self.providedAPIKey = nil
        self.timeout = timeout
        self.temperature = temperature

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        self.session = URLSession(configuration: configuration)
    }

    /// 新版初始化 (从 ProviderProfile)
    /// - apiKey: 可选，直接传入 API Key，避免 Provider 内部访问 Keychain
    init(profile: ProviderProfile, apiKey: String? = nil, timeout: TimeInterval = 30) {
        self.providerType = profile.providerType
        self.profile = profile
        self.providedAPIKey = apiKey
        self.timeout = timeout
        // 直接使用 profile 的 temperature（profile.temperature 是非可选的）
        self.temperature = profile.temperature
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
        
        logger.info("🤖 LLM request to \(self.providerType.displayName, privacy: .public)")
        
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
            logger.error("❌ Connection test failed (LLMError): \(error.localizedDescription, privacy: .public)")
            throw error // 抛出具体错误供 UI 显示
        } catch {
            logger.error("❌ Connection test failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
    
    /// 获取可用模型列表
    /// 支持不同 Provider 的 API 格式差异
    func fetchModels() async -> [String] {
        let urlString = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        // 使用 providedAPIKey（由 LLMSettings 注入）
        let apiKey = providedAPIKey
        
        logger.info("🔍 fetchModels: baseURL=\(urlString, privacy: .public), providerType=\(self.providerType.rawValue, privacy: .public), hasAPIKey=\(apiKey != nil)")
        
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
        
        logger.info("🌐 fetchModels: requesting \(url.absoluteString, privacy: .public)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        
        // 添加认证头
        if let (headerName, headerValue) = authHeader {
            request.setValue(headerValue, forHTTPHeaderField: headerName)
            logger.info("🔑 fetchModels: auth header \(headerName, privacy: .public)=\(headerValue.prefix(20), privacy: .public)...")
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
                logger.warning("⚠️ Models endpoint returned status \(statusCode, privacy: .public)")
                return []
            }
            
            return parseModelsResponse(data: data)
        } catch {
            logger.warning("⚠️ Failed to fetch models: \(error.localizedDescription, privacy: .public)")
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
            logger.info("✅ Fetched \(models.count, privacy: .public) models from \(self.providerType.displayName, privacy: .public)")
        }
        
        return models.sorted()
    }
    
    // MARK: - Private
    
    private func buildRequest(prompt: LLMPrompt) throws -> URLRequest {
        let urlString = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        // 使用 providedAPIKey（由 LLMSettings 注入）
        let apiKey = providedAPIKey
        
        // 检测是否使用 Gemini 原生格式（baseURL 包含 v1beta 或 providerType 是 googleGemini）
        let useGeminiNativeFormat = providerType == .googleGemini || urlString.contains("v1beta")
        if useGeminiNativeFormat {
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
        var messages: [[String: Any]] = []
        
        // System prompt
        if !prompt.systemPrompt.isEmpty {
            messages.append([
                "role": "system",
                "content": prompt.systemPrompt
            ])
        }
        
        // User message（支持多模态）
        if prompt.images.isEmpty {
            // 纯文本
            messages.append([
                "role": "user",
                "content": prompt.userMessage
            ])
        } else {
            // 多模态：文本 + 图片
            var content: [[String: Any]] = [
                ["type": "text", "text": prompt.userMessage]
            ]
            for imageData in prompt.images {
                let base64 = imageData.base64EncodedString()
                content.append([
                    "type": "image_url",
                    "image_url": ["url": "data:image/png;base64,\(base64)"]
                ])
            }
            messages.append([
                "role": "user",
                "content": content
            ])
        }
        
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
        // Gemini: POST /models/{model}:generateContent
        // 支持两种认证方式：?key= 或 Authorization header
        
        let model = modelName.isEmpty ? "gemini-pro" : modelName
        let cleanModelName = model.replacingOccurrences(of: "models/", with: "")
        
        // 检测 URL 是否已包含 v1beta（CLI2API 代理格式）
        let isProxy = urlString.contains("v1beta")
        
        let url: URL?
        if isProxy {
            // CLI2API 代理：使用 Authorization header
            url = URL(string: "\(urlString)/models/\(cleanModelName):generateContent")
        } else {
            // 原生 Gemini API：使用 ?key= 参数
            guard let key = apiKey else { throw LLMError.invalidAPIKey }
            url = URL(string: "\(urlString)/models/\(cleanModelName):generateContent?key=\(key)")
        }
        
        guard let finalURL = url else {
            throw LLMError.invalidResponse
        }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // CLI2API 代理使用 Bearer token
        if isProxy, let key = apiKey {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        
        // 构建 generationConfig
        var generationConfig: [String: Any] = [
            "temperature": temperature,
            "maxOutputTokens": maxTokens
        ]
        
        // 检测是否为生图模型（模型名包含 "image"）
        let isImageModel = cleanModelName.lowercased().contains("image")
        if isImageModel {
            generationConfig["responseModalities"] = ["IMAGE", "TEXT"]
            logger.info("🎨 Image generation enabled for model: \(cleanModelName)")
        }
        
        // 添加 thinkingConfig（关闭思考以省 token）
        // 🔍 调试：打印 enableThinking 值
        let thinkingEnabled = self.enableThinking
        let profileThinking = self.profile?.enableThinking ?? true
        logger.info("🧠 enableThinking = \(thinkingEnabled), profile?.enableThinking = \(profileThinking)")
        if !thinkingEnabled {
            generationConfig["thinkingConfig"] = [
                "thinkingBudget": 0
            ]
            logger.info("🧠 Thinking DISABLED - added thinkingBudget: 0")
        } else {
            logger.info("🧠 Thinking ENABLED - no thinkingConfig added")
        }
        
        // 构建 parts（支持多模态）
        var parts: [[String: Any]] = [["text": prompt.userMessage]]
        for imageData in prompt.images {
            let base64 = imageData.base64EncodedString()
            parts.append([
                "inline_data": [
                    "mime_type": "image/png",
                    "data": base64
                ]
            ])
        }
        
        var body: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": parts
                ]
            ],
            "generationConfig": generationConfig
        ]
        
        if !prompt.systemPrompt.isEmpty {
            body["systemInstruction"] = [
                "parts": [
                    ["text": prompt.systemPrompt]
                ]
            ]
        }
        
        // 添加 Google Search 工具（联网搜索）
        if enableSearchGrounding {
            body["tools"] = [
                ["google_search": [:]]
            ]
            logger.info("🔍 Google Search grounding enabled for this request")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
    
    private func parseResponse(data: Data) throws -> LLMResponse {
        // 检测是否使用 Gemini 原生格式
        let useGeminiFormat = providerType == .googleGemini || baseURL.contains("v1beta")
        if useGeminiFormat {
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
        // Gemini: { "candidates": [{ "content": { "parts": [{ "text": "..." }, { "inline_data": {...} }] } }] }
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
              let parts = content["parts"] as? [[String: Any]] else {
            logger.error("❌ Failed to parse Gemini response: \(String(data: data, encoding: .utf8) ?? "nil")")
            throw LLMError.invalidResponse
        }
        
        // 遍历 parts 提取文本和图片
        var textParts: [String] = []
        var images: [Data] = []
        
        for part in parts {
            // 文本部分
            if let text = part["text"] as? String {
                textParts.append(text)
            }
            // 图片部分 - 支持 snake_case 和 camelCase
            let inlineData = part["inline_data"] as? [String: Any] ?? part["inlineData"] as? [String: Any]
            if let inlineData = inlineData,
               let base64String = inlineData["data"] as? String,
               let imageData = Data(base64Encoded: base64String) {
                images.append(imageData)
            }
        }
        
        let combinedText = textParts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        logger.info("✅ Gemini response: \(combinedText.count) chars, \(images.count) images")
        
        return LLMResponse(text: combinedText, usage: nil, images: images)
    }
}
