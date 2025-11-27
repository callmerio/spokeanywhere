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
    private let session: URLSession
    
    /// 请求超时时间（秒）
    private let timeout: TimeInterval = 30
    
    // MARK: - Init
    
    init(providerType: LLMProviderType, config: ProviderConfig) {
        self.providerType = providerType
        self.config = config
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - LLMProvider
    
    nonisolated var isConfigured: Bool {
        // 检查必要配置
        guard !config.baseURL.isEmpty, !config.modelName.isEmpty else {
            return false
        }
        
        // 需要 API Key 的 Provider 检查 Keychain
        if providerType.requiresAPIKey {
            guard let keyRef = config.apiKeyRef,
                  KeychainService.exists(key: keyRef) else {
                return false
            }
        }
        
        return true
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
    
    func testConnection() async -> Bool {
        // 发送一个简单的测试请求
        let testPrompt = LLMPrompt(
            systemPrompt: "You are a helpful assistant.",
            userMessage: "Say 'OK' if you can hear me."
        )
        
        do {
            let response = try await complete(prompt: testPrompt)
            return !response.text.isEmpty
        } catch {
            logger.error("❌ Connection test failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Private
    
    private func buildRequest(prompt: LLMPrompt) throws -> URLRequest {
        // 构建 URL
        let baseURL = config.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw LLMError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加 API Key
        if let keyRef = config.apiKeyRef,
           let apiKey = KeychainService.load(key: keyRef) {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
            "model": config.modelName,
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 2048
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return request
    }
    
    private func parseResponse(data: Data) throws -> LLMResponse {
        // 解析 OpenAI 格式响应
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            logger.error("❌ Failed to parse response: \(String(data: data, encoding: .utf8) ?? "nil")")
            throw LLMError.invalidResponse
        }
        
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedContent.isEmpty {
            throw LLMError.emptyResponse
        }
        
        // 解析 usage（可选）
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
}
