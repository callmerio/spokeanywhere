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
    
    /// 精炼文本
    /// - Parameter text: 原始转写文本
    /// - Returns: 精炼后的文本，失败时返回 nil
    func refine(_ text: String) async -> Result<String, LLMError> {
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
        
        // 构建 Prompt
        let prompt = buildPrompt(for: text)
        
        // 调试：打印完整 Prompt
        logger.info("🤖 Starting LLM refinement...")
        // clipboardHistory.debugPrintHistory() // 减少噪音，Prompt 里已经有了
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
