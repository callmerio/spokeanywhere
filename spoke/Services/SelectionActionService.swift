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
    private let dictionaryAPI = DictionaryAPIService.shared
    
    /// 当前 TTS 播放任务
    private var currentTTSTask: Task<Void, Never>?
    
    // MARK: - Init
    
    private init() {
        setupNotifications()
    }
    
    // MARK: - Setup
    
    private func setupNotifications() {
        // 监听动作请求 (新版 ToolbarAction)
        NotificationCenter.default.addObserver(
            forName: .selectionToolbarActionRequested,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let context = notification.userInfo?["context"] as? SelectionContext else {
                return
            }
            
            // 优先处理新版 ToolbarAction
            if let toolbarAction = notification.userInfo?["toolbarAction"] as? ToolbarAction {
                Task { @MainActor in
                    await self?.executeToolbarAction(toolbarAction, context: context)
                }
                return
            }
            
            // 兼容旧版 SelectionToolbarActionType
            if let action = notification.userInfo?["action"] as? SelectionToolbarActionType {
                Task { @MainActor in
                    await self?.executeAction(action, context: context)
                }
            }
        }
    }
    
    // MARK: - Public API
    
    /// 执行动作 (旧版，兼容 SelectionToolbarActionType)
    func executeAction(_ action: SelectionToolbarActionType, context: SelectionContext) async {
        // 转换为 ToolbarAction 并使用新的执行逻辑
        let toolbarAction = ToolbarAction.builtin(action)
        await executeToolbarAction(toolbarAction, context: context)
    }
    
    /// 取消当前动作
    func cancelCurrentAction() {
        currentTTSTask?.cancel()
        currentTTSTask = nil
        state.updateActionPhase(.idle)
        state.executingActionId = nil
    }
    
    /// 执行工具栏动作 (新版，支持自定义动作)
    func executeToolbarAction(_ action: ToolbarAction, context: SelectionContext) async {
        logger.info("📋 [ActionService] executeToolbarAction 开始 | action.id: \(action.id) | action.kind: \(String(describing: action.kind))")
        state.updateActionPhase(.executing(progress: nil))
        
        do {
            switch action.kind {
            case .builtin(let builtinType):
                // 内置动作（使用可配置的提示词和模型）
                await executeBuiltinAction(builtinType, action: action, context: context)
                
            case .custom(let prompt):
                // 自定义动作：使用提示词模板
                try await executeCustomAction(action: action, prompt: action.effectivePrompt ?? prompt, context: context)
            }
            
            state.updateActionPhase(.completed)
            state.executingActionId = nil
            
            NotificationCenter.default.post(
                name: .selectionToolbarActionCompleted,
                object: nil,
                userInfo: ["actionId": action.id, "success": true]
            )
            
        } catch {
            state.updateActionPhase(.failed(message: error.localizedDescription))
            state.executingActionId = nil
            logger.error("📋 [ActionService] 工具栏动作执行失败: \(error.localizedDescription)")
        }
    }
    
    /// 执行内置动作
    private func executeBuiltinAction(_ type: SelectionToolbarActionType, action: ToolbarAction, context: SelectionContext) async {
        logger.info("📋 [ActionService] executeBuiltinAction | type: \(type.rawValue)")
        do {
            switch type {
            case .speak:
                logger.info("📋 [ActionService] 进入 .speak case")
                try await executeSpeakAction(text: context.selectedText)
            case .dictionary:
                logger.info("📋 [ActionService] 进入 .dictionary case")
                try await executeDictionaryAction(text: context.selectedText)
            case .lookup:
                try await executeLookupAction(action: action, context: context)
            case .translate:
                try await executeTranslateAction(action: action, text: context.selectedText)
            case .summarize:
                try await executeSummarizeAction(action: action, context: context)
            case .copy:
                executeCopyAction(text: context.selectedText)
            }
        } catch {
            state.updateActionPhase(.failed(message: error.localizedDescription))
        }
    }
    
    /// 执行自定义动作 (使用 {{selection}} 占位符)
    private func executeCustomAction(action: ToolbarAction, prompt: String, context: SelectionContext) async throws {
        logger.info("📋 [ActionService] 执行自定义动作 | 文本长度: \(context.selectedText.count)")
        
        // 替换占位符
        var finalPrompt = prompt.replacingOccurrences(
            of: ToolbarActionPlaceholder.selection,
            with: context.selectedText
        )
        // 替换 context 占位符
        finalPrompt = finalPrompt.replacingOccurrences(
            of: ToolbarActionPlaceholder.context,
            with: ""  // 自定义动作暂不支持 context
        )
        
        // 获取工具栏位置并隐藏
        let anchorPoint = SelectionToolbarManager.shared.toolbarBottomCenter
        SelectionToolbarManager.shared.hide()
        
        // 显示 AnswerPanel
        let panelId: UUID
        if let anchor = anchorPoint {
            panelId = AnswerPanelManager.shared.showBelowAnchor(
                question: String(context.selectedText.prefix(50)) + "...",
                anchorPoint: anchor
            )
        } else {
            panelId = AnswerPanelManager.shared.show(
                question: String(context.selectedText.prefix(50)) + "...",
                attachments: []
            )
        }
        
        // 根据配置调用 LLM
        let chatResult = await callLLM(prompt: finalPrompt, action: action)
        switch chatResult {
        case .success(let result):
            AnswerPanelManager.shared.updateAnswer(result, for: panelId)
        case .failure(let error):
            AnswerPanelManager.shared.showError(error.localizedDescription, for: panelId)
            throw error
        }
        
        logger.info("📋 [ActionService] 自定义动作完成")
    }
    
    /// 根据 Action 配置调用 LLM
    private func callLLM(prompt: String, action: ToolbarAction) async -> Result<LLMResponse, LLMError> {
        // 如果指定了 profileId，使用指定的 Profile
        if let profileId = action.profileId,
           let profile = LLMSettings.shared.profiles.first(where: { $0.id == profileId }) {
            // 使用指定的 Profile
            if action.enableSearch {
                let textResult = await llmPipeline.processWithSearch(query: prompt, systemPrompt: prompt)
                return textResult.map { LLMResponse(text: $0) }
            } else {
                return await llmPipeline.chat(prompt, profile: profile)
            }
        }
        
        // 否则使用默认模型
        if action.enableSearch {
            let textResult = await llmPipeline.processWithSearch(query: prompt, systemPrompt: prompt)
            return textResult.map { LLMResponse(text: $0) }
        } else {
            return await llmPipeline.chat(prompt)
        }
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
    
    /// 词典查询动作
    private func executeDictionaryAction(text: String) async throws {
        let word = text.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.info("📋 [ActionService] 执行查词 | 单词: \(word)")
        
        // 🔥 开始执行动作，阻止工具栏被隐藏
        SelectionToolbarManager.shared.beginAction()
        defer { SelectionToolbarManager.shared.endAction() }
        
        // 调用词典 API
        let result = await dictionaryAPI.lookup(word)
        
        // 工具栏原地变换显示词典结果
        switch result {
        case .success(let data):
            logger.info("📋 [ActionService] 查词成功: \(data.word), senses: \(data.senses.count)")
            state.showDictionaryResult(data, forText: word)
            
        case .failure(let error):
            logger.error("📋 [ActionService] 查词失败: \(error.localizedDescription)")
            state.showDictionaryError(error, word: word)
        }
    }
    
    /// 查询动作 (联网搜索 + AI 解释)
    private func executeLookupAction(action: ToolbarAction, context: SelectionContext) async throws {
        logger.info("📋 [ActionService] 执行查询 | 文本: \(context.selectedText.prefix(50))... | 联网: \(action.enableSearch)")
        
        let selectedText = context.selectedText
        
        // 1. 获取工具栏位置并隐藏工具栏
        let anchorPoint = SelectionToolbarManager.shared.toolbarBottomCenter
        SelectionToolbarManager.shared.hide()
        
        // 2. 显示 AnswerPanel（复用 Quick Answer 界面）
        let panelId: UUID
        if let anchor = anchorPoint {
            panelId = AnswerPanelManager.shared.showBelowAnchor(
                question: selectedText,
                anchorPoint: anchor
            )
        } else {
            panelId = AnswerPanelManager.shared.show(question: selectedText, attachments: [])
        }
        
        // 3. 获取 OCR 上下文 (如果启用)
        var ocrContext: String? = nil
        if state.config.enableOCRContext {
            ocrContext = await screenOCR.getActiveWindowText(maxLength: state.config.ocrContextMaxLength)
        }
        
        // 4. 构建查询 Prompt（使用可配置的提示词）
        let prompt = buildPromptFromTemplate(
            template: action.effectivePrompt ?? ToolbarActionDefaults.lookupPrompt,
            selection: selectedText,
            context: ocrContext
        )
        
        // 5. 根据配置调用 LLM
        let chatResult = await callLLM(prompt: prompt, action: action)
        
        // 6. 更新 AnswerPanel
        switch chatResult {
        case .success(let result):
            AnswerPanelManager.shared.updateAnswer(result, for: panelId)
        case .failure(let error):
            AnswerPanelManager.shared.showError(error.localizedDescription, for: panelId)
            throw error
        }
        
        logger.info("📋 [ActionService] 查询完成")
    }
    
    /// 翻译动作
    private func executeTranslateAction(action: ToolbarAction, text: String) async throws {
        logger.info("📋 [ActionService] 执行翻译 | 文本长度: \(text.count)")
        
        // 1. 获取工具栏位置并隐藏工具栏
        let anchorPoint = SelectionToolbarManager.shared.toolbarBottomCenter
        SelectionToolbarManager.shared.hide()
        
        // 2. 显示 AnswerPanel
        let panelId: UUID
        if let anchor = anchorPoint {
            panelId = AnswerPanelManager.shared.showBelowAnchor(
                question: "翻译: \(text.prefix(50))...",
                anchorPoint: anchor
            )
        } else {
            panelId = AnswerPanelManager.shared.show(question: "翻译: \(text.prefix(50))...", attachments: [])
        }
        
        // 3. 构建提示词（使用可配置的提示词）
        let prompt = buildPromptFromTemplate(
            template: action.effectivePrompt ?? ToolbarActionDefaults.translatePrompt,
            selection: text,
            context: nil
        )
        
        // 4. 根据配置调用 LLM
        let chatResult = await callLLM(prompt: prompt, action: action)
        switch chatResult {
        case .success(let result):
            AnswerPanelManager.shared.updateAnswer(result, for: panelId)
            logger.info("📋 [ActionService] 翻译完成")
        case .failure(let error):
            AnswerPanelManager.shared.showError(error.localizedDescription, for: panelId)
            throw error
        }
    }
    
    /// 总结动作
    private func executeSummarizeAction(action: ToolbarAction, context: SelectionContext) async throws {
        logger.info("📋 [ActionService] 执行总结 | 文本长度: \(context.selectedText.count)")
        
        // 1. 获取工具栏位置并隐藏工具栏
        let anchorPoint = SelectionToolbarManager.shared.toolbarBottomCenter
        SelectionToolbarManager.shared.hide()
        
        // 2. 显示 AnswerPanel
        let panelId: UUID
        if let anchor = anchorPoint {
            panelId = AnswerPanelManager.shared.showBelowAnchor(
                question: "总结: \(context.selectedText.prefix(50))...",
                anchorPoint: anchor
            )
        } else {
            panelId = AnswerPanelManager.shared.show(question: "总结: \(context.selectedText.prefix(50))...", attachments: [])
        }
        
        // 3. 构建提示词（使用可配置的提示词）
        let prompt = buildPromptFromTemplate(
            template: action.effectivePrompt ?? ToolbarActionDefaults.summarizePrompt,
            selection: context.selectedText,
            context: nil
        )
        
        // 4. 根据配置调用 LLM
        let chatResult = await callLLM(prompt: prompt, action: action)
        switch chatResult {
        case .success(let result):
            AnswerPanelManager.shared.updateAnswer(result, for: panelId)
        case .failure(let error):
            AnswerPanelManager.shared.showError(error.localizedDescription, for: panelId)
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
    
    /// 从模板构建提示词（替换占位符）
    private func buildPromptFromTemplate(template: String, selection: String, context: String?) -> String {
        var prompt = template
        
        // 替换 {{selection}} 占位符
        prompt = prompt.replacingOccurrences(
            of: ToolbarActionPlaceholder.selection,
            with: selection
        )
        
        // 替换 {{context}} 占位符
        prompt = prompt.replacingOccurrences(
            of: ToolbarActionPlaceholder.context,
            with: context ?? ""
        )
        
        return prompt
    }
    
    /// 构建查询 Prompt (旧版，保留兼容)
    @available(*, deprecated, message: "使用 buildPromptFromTemplate 代替")
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
        let response = await chat(systemPrompt)
        return response.map { $0.text }
    }
}
