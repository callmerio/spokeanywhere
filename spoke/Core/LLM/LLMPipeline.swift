import Foundation
import os

/// LLM 处理管线
/// 负责协调转写文本的 LLM 精炼处理
@MainActor
final class LLMPipeline {
    
    // MARK: - Singleton
    
    static let shared = LLMPipeline()
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "LLMPipeline")
    
    // MARK: - Dependencies
    
    private let settings = LLMSettings.shared
    private let contextService = ContextService.shared
    private let clipboardHistory = ClipboardHistoryService.shared
    
    // MARK: - Properties
    
    /// 当前是否正在处理
    private(set) var isProcessing = false
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Public API
    
    /// 检查是否需要 LLM 处理
    var shouldProcess: Bool {
        settings.isFullyConfigured
    }
    
    /// 对话（Quick Ask 专用）
    /// - Parameter message: 用户消息
    /// - Returns: AI 回答
    func chat(_ message: String) async -> Result<String, LLMError> {
        guard shouldProcess else {
            logger.info("⏭️ LLM not configured")
            return .failure(.notConfigured)
        }
        
        guard let provider = settings.createCurrentProvider() else {
            logger.error("❌ Failed to create LLM provider")
            return .failure(.notConfigured)
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Quick Ask 专用系统提示词
        let systemPrompt = """
        你是一个友好、专业的 AI 助手。请根据用户的问题提供清晰、准确的回答。
        
        如果用户提供了语音转写内容，请注意：
        - 语音转写可能存在错误（尤其是专业术语、人名、产品名）
        - 请根据上下文推断用户的真实意图
        - 如果不确定用户的意思，可以礼貌地询问
        
        回答要求：
        - 使用简洁明了的语言
        - 适当使用列表或分段来组织内容
        - 如果是代码相关问题，请提供代码示例
        """
        
        let prompt = LLMPrompt(
            systemPrompt: systemPrompt,
            userMessage: message,
            contextAppName: contextService.getCurrentTargetApp()?.name
        )
        
        logger.info("🤖 Quick Ask: \(message.prefix(100))...")
        
        do {
            let response = try await provider.complete(prompt: prompt)
            logger.info("✅ Quick Ask complete")
            return .success(response.text)
        } catch let error as LLMError {
            logger.error("❌ Quick Ask error: \(error.localizedDescription)")
            return .failure(error)
        } catch {
            logger.error("❌ Unexpected error: \(error.localizedDescription)")
            return .failure(.networkError(error))
        }
    }
    
    /// 精炼文本
    /// - Parameters:
    ///   - text: 原始转写文本
    ///   - customSystemPrompt: 自定义系统提示词（用于历史记录重处理）
    /// - Returns: 精炼后的文本，失败时返回错误
    func refine(_ text: String, customSystemPrompt: String? = nil) async -> Result<String, LLMError> {
        guard shouldProcess else {
            logger.info("⏭️ LLM not configured, skipping")
            return .success(text)
        }
        
        guard let provider = settings.createCurrentProvider() else {
            logger.error("❌ Failed to create LLM provider")
            return .failure(.notConfigured)
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // 构建 Prompt（支持自定义系统提示词）
        let prompt: LLMPrompt
        if let customPrompt = customSystemPrompt {
            // 使用自定义提示词（历史记录重处理场景）
            prompt = LLMPrompt(
                systemPrompt: customPrompt,
                userMessage: text,
                contextAppName: nil
            )
        } else {
            // 使用默认设置构建提示词
            prompt = buildPrompt(for: text)
        }
        
        // 调试：打印完整 Prompt
        logger.info("🤖 Starting LLM refinement...")
        print("📝 === LLM PROMPT DEBUG ===")
        print("📝 System Prompt:")
        print(prompt.systemPrompt)
        print("📝 User Message: \(prompt.userMessage)")
        print("📝 === END PROMPT ===")
        
        do {
            let response = try await provider.complete(prompt: prompt)
            logger.info("✅ LLM refinement complete")
            return .success(response.text)
        } catch let error as LLMError {
            logger.error("❌ LLM error: \(error.localizedDescription)")
            return .failure(error)
        } catch {
            logger.error("❌ Unexpected error: \(error.localizedDescription)")
            return .failure(.networkError(error))
        }
    }
    
    // MARK: - Private
    
    private func buildPrompt(for text: String) -> LLMPrompt {
        var systemPrompt = settings.systemPrompt
        
        // 添加上下文信息
        if settings.includeActiveApp {
            if let appName = contextService.getCurrentTargetApp()?.name {
                systemPrompt += "\n\n当前应用: \(appName)"
            }
        }
        
        if settings.includeClipboard {
            // 限制为最近 10 条，减少噪音并聚焦最近上下文
            let historyContext = clipboardHistory.formatForPrompt(limit: 10)
            if !historyContext.isEmpty {
                systemPrompt += "\n\n" + historyContext
            }
        }
        
        return LLMPrompt(
            systemPrompt: systemPrompt,
            userMessage: text,
            contextAppName: contextService.getCurrentTargetApp()?.name
        )
    }
}
