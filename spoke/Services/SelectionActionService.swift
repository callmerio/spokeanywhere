import Foundation
import AppKit
import OSLog

private let logger = Logger(subsystem: "com.spokeanywhere", category: "SelectionActionService")

/// 选择工具栏动作执行服务
@MainActor
final class SelectionActionService {
    
    // MARK: - Singleton
    
    static let shared = SelectionActionService()
    
    // MARK: - Dependencies
    
    private let state = SelectionToolbarState.shared
    private let ttsService = TTSService.shared
    private let screenOCR = ScreenOCRService.shared
    private let llmPipeline = LLMPipeline.shared
    
    /// 当前 TTS 播放任务
    private var currentTTSTask: Task<Void, Never>?
    
    // MARK: - Init
    
    private init() {
        setupNotifications()
    }
    
    // MARK: - Setup
    
    private func setupNotifications() {
        // 监听动作请求
        NotificationCenter.default.addObserver(
            forName: .selectionToolbarActionRequested,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let action = notification.userInfo?["action"] as? SelectionToolbarActionType,
                  let context = notification.userInfo?["context"] as? SelectionContext else {
                return
            }
            
            Task { @MainActor in
                await self?.executeAction(action, context: context)
            }
        }
    }
    
    // MARK: - Public API
    
    /// 执行动作
    func executeAction(_ action: SelectionToolbarActionType, context: SelectionContext) async {
        state.updateActionPhase(.executing(progress: nil))
        
        do {
            switch action {
            case .speak:
                try await executeSpeakAction(text: context.selectedText)
                
            case .lookup:
                try await executeLookupAction(context: context)
                
            case .translate:
                try await executeTranslateAction(text: context.selectedText)
                
            case .summarize:
                try await executeSummarizeAction(context: context)
                
            case .copy:
                executeCopyAction(text: context.selectedText)
            }
            
            state.updateActionPhase(.completed)
            
            // 发送完成通知
            NotificationCenter.default.post(
                name: .selectionToolbarActionCompleted,
                object: nil,
                userInfo: ["action": action, "success": true]
            )
            
        } catch {
            state.updateActionPhase(.failed(message: error.localizedDescription))
            logger.error("📋 [ActionService] 动作执行失败: \(error.localizedDescription)")
        }
    }
    
    /// 取消当前动作
    func cancelCurrentAction() {
        currentTTSTask?.cancel()
        currentTTSTask = nil
        state.updateActionPhase(.idle)
    }
    
    // MARK: - Action Implementations
    
    /// 朗读动作
    private func executeSpeakAction(text: String) async throws {
        logger.info("📋 [ActionService] 执行朗读 | 文本长度: \(text.count)")
        
        // 使用 TTSService 朗读（支持分块、会自动停止之前的播放）
        ttsService.speak(text)
        
        logger.info("📋 [ActionService] 朗读已启动")
        
        // 朗读是异步的，直接返回让用户继续操作
    }
    
    /// 查询动作 (联网搜索 + AI 解释)
    private func executeLookupAction(context: SelectionContext) async throws {
        logger.info("📋 [ActionService] 执行查询 | 文本: \(context.selectedText.prefix(50))...")
        
        let selectedText = context.selectedText
        
        // 1. 获取 OCR 上下文 (如果启用)
        var ocrContext: String? = nil
        if state.config.enableOCRContext {
            state.updateActionPhase(.executing(progress: 0.2))
            ocrContext = await screenOCR.getActiveWindowText(maxLength: state.config.ocrContextMaxLength)
        }
        
        // 2. 构建查询 Prompt
        state.updateActionPhase(.executing(progress: 0.4))
        let prompt = buildLookupPrompt(selectedText: selectedText, ocrContext: ocrContext)
        
        // 3. 调用 LLM
        state.updateActionPhase(.executing(progress: 0.6))
        
        // 使用 LLMPipeline 处理
        let chatResult = await llmPipeline.processWithSearch(
            query: selectedText,
            systemPrompt: prompt
        )
        
        // 4. 显示结果
        state.updateActionPhase(.executing(progress: 1.0))
        
        switch chatResult {
        case .success(let result):
            state.showResult(result)
        case .failure(let error):
            throw error
        }
        
        logger.info("📋 [ActionService] 查询完成")
    }
    
    /// 翻译动作
    private func executeTranslateAction(text: String) async throws {
        logger.info("📋 [ActionService] 执行翻译 | 文本长度: \(text.count)")
        
        // 使用 LLM 翻译
        let prompt = """
        请将以下文本翻译成中文，保持原文的格式和语气：
        
        \(text)
        
        只输出翻译结果，不要添加任何解释。
        """
        
        let chatResult = await llmPipeline.chat(prompt)
        switch chatResult {
        case .success(let result):
            state.showResult(result)
            logger.info("📋 [ActionService] 翻译完成")
        case .failure(let error):
            throw error
        }
    }
    
    /// 总结动作
    private func executeSummarizeAction(context: SelectionContext) async throws {
        logger.info("📋 [ActionService] 执行总结 | 文本长度: \(context.selectedText.count)")
        
        let prompt = """
        请对以下内容进行简洁的总结，提取关键要点：
        
        ---
        \(context.selectedText)
        ---
        
        要求：
        1. 使用中文回答
        2. 分点列出主要内容
        3. 控制在 200 字以内
        """
        
        let chatResult = await llmPipeline.chat(prompt)
        switch chatResult {
        case .success(let result):
            state.showResult(result)
        case .failure(let error):
            throw error
        }
        
        logger.info("📋 [ActionService] 总结完成")
    }
    
    /// 复制动作
    private func executeCopyAction(text: String) {
        logger.info("📋 [ActionService] 执行复制 | 文本长度: \(text.count)")
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // 显示简短的成功提示
        state.showResult("已复制到剪贴板")
        
        // 自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            SelectionToolbarManager.shared.hide()
        }
    }
    
    // MARK: - Helpers
    
    /// 构建查询 Prompt
    private func buildLookupPrompt(selectedText: String, ocrContext: String?) -> String {
        var prompt = """
        你是一个知识助手。用户选中了一段文本，请帮助解释它的含义。
        
        ## 选中的文本
        \(selectedText)
        """
        
        if let context = ocrContext, !context.isEmpty {
            prompt += """
            
            ## 上下文 (来自用户当前查看的内容)
            \(context.prefix(1500))
            """
        }
        
        prompt += """
        
        ## 要求
        1. 使用中文回答
        2. 如果是术语/概念，给出定义和解释
        3. 如果是人名/地名，给出相关信息
        4. 如果需要，结合上下文理解含义
        5. 回答简洁明了，控制在 300 字以内
        """
        
        return prompt
    }
}

// MARK: - LLMPipeline Extension

extension LLMPipeline {
    /// 带搜索的处理
    func processWithSearch(query: String, systemPrompt: String) async -> Result<String, LLMError> {
        // TODO: 集成搜索 API (Firecrawl/Perplexity)
        // 目前先直接调用 LLM
        return await chat(systemPrompt)
    }
}
