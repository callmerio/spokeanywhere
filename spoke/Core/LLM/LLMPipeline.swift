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
    private let screenOCR = ScreenOCRService.shared
    
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
    
    /// 当前 Provider 名称（用于显示）
    var currentProviderName: String {
        settings.currentProviderName
    }
    
    /// 对话（Quick Ask 专用）
    /// - Parameter message: 用户消息
    /// - Returns: AI 回答（包含文本和可能的图片）
    func chat(_ message: String) async -> Result<LLMResponse, LLMError> {
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
            return .success(response)
        } catch let error as LLMError {
            logger.error("❌ Quick Ask error: \(error.localizedDescription)")
            return .failure(error)
        } catch {
            logger.error("❌ Unexpected error: \(error.localizedDescription)")
            return .failure(.networkError(error))
        }
    }
    
    /// 使用指定 Profile 对话
    /// - Parameters:
    ///   - message: 用户消息
    ///   - profile: 指定的 LLM Profile
    /// - Returns: AI 回答（包含文本和可能的图片）
    func chat(_ message: String, profile: ProviderProfile) async -> Result<LLMResponse, LLMError> {
        guard let provider = settings.createProvider(for: profile) else {
            logger.error("❌ Failed to create LLM provider for profile: \(profile.name)")
            return .failure(.notConfigured)
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let prompt = LLMPrompt(
            systemPrompt: "",
            userMessage: message,
            contextAppName: nil
        )
        
        logger.info("🤖 Chat with profile \(profile.name): \(message.prefix(100))...")
        
        do {
            let response = try await provider.complete(prompt: prompt)
            logger.info("✅ Chat complete")
            return .success(response)
        } catch let error as LLMError {
            logger.error("❌ Chat error: \(error.localizedDescription)")
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
            prompt = await buildPrompt(for: text)
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
    
    private func buildPrompt(for text: String) async -> LLMPrompt {
        var systemPrompt = settings.systemPrompt
        
        // 添加应用上下文（OCR 内容）
        if settings.includeActiveApp {
            let appContext = await buildAppContext()
            if !appContext.isEmpty {
                // 放在独立区块，明确告知这是参考上下文，不要影响转录核心任务
                systemPrompt += "\n\n" + appContext
            }
        }
        
        if settings.includeClipboard {
            // 限制为最近 10 条，减少噪音并聚焦最近上下文
            let historyContext = clipboardHistory.formatForPrompt(limit: 10)
            if !historyContext.isEmpty {
                systemPrompt += "\n\n" + historyContext
            }
        }
        
        // 智能纠错：检测词典匹配，让 AI 根据上下文判断
        if UserDefaults.standard.useLLMForCorrection {
            let correctionHints = buildCorrectionHints(for: text)
            if !correctionHints.isEmpty {
                systemPrompt += "\n\n" + correctionHints
            }
        }
        
        return LLMPrompt(
            systemPrompt: systemPrompt,
            userMessage: text,
            contextAppName: contextService.getCurrentTargetApp()?.name
        )
    }
    
    /// 构建应用上下文（应用名 + 窗口 OCR）
    private func buildAppContext() async -> String {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard let app = contextService.getCurrentTargetApp() else {
            logger.info("📱 [AppContext] 无聚焦应用")
            return ""
        }
        
        logger.info("📱 [AppContext] 开始构建 | 应用: \(app.name, privacy: .public)")
        
        var context = "【应用上下文 - 仅用于理解用户意图，不要将无关内容混入转录】"
        context += "\n当前应用: \(app.name)"
        
        // 优先等待预取结果（已在录音开始时触发），否则实时获取
        var ocrText = await screenOCR.awaitPrefetch()
        if ocrText == nil {
            ocrText = await screenOCR.getActiveWindowText(maxLength: 1500)
        }
        
        if let ocrText = ocrText {
            // 清理 OCR 文本：移除过多空白行
            let cleanedText = ocrText
                .components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .joined(separator: "\n")
            
            if !cleanedText.isEmpty {
                context += "\n窗口内容摘要:\n\(cleanedText)"
            }
        }
        
        let totalTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logger.info("📱 [AppContext] 构建完成 | 总长度: \(context.count, privacy: .public) 字符 | 耗时: \(String(format: "%.1f", totalTime), privacy: .public)ms")
        
        return context
    }
    
    /// 构建词典纠错提示
    /// 检测文本中可能匹配词典 corrections 的部分，让 AI 根据上下文决定是否替换
    private func buildCorrectionHints(for text: String) -> String {
        let dictionaryService = DictionaryService.shared
        var hints: [(errorForm: String, correctWord: String)] = []
        
        // 遍历所有词条，检查是否有 corrections 匹配
        for entry in dictionaryService.entries where entry.confirmedByUser {
            for correction in entry.corrections {
                // 不区分大小写检查是否包含
                if text.range(of: correction, options: .caseInsensitive) != nil {
                    hints.append((errorForm: correction, correctWord: entry.word))
                }
            }
        }
        
        guard !hints.isEmpty else { return "" }
        
        // 构建提示文本
        var prompt = """
        【词典纠错提示】
        检测到以下可能的识别错误，请根据上下文判断是否需要替换：
        """
        
        for hint in hints {
            prompt += "\n- 「\(hint.errorForm)」可能是「\(hint.correctWord)」的误识别"
        }
        
        prompt += """
        
        注意：这只是提示，请结合上下文语义判断是否合理。如果上下文表明原词是正确的，则保持不变。
        """
        
        return prompt
    }
}
