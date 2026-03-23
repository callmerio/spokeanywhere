import AppKit
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.spokeanywhere", category: "SelectionActionService")
private enum SelectionActionServiceDefaults {
    static let autoHideDelay: TimeInterval = 0.5
    static let questionPreviewLength = 50
}

private enum SelectionActionFinishOutcome {
    case success(actionID: String)
    case failure(Error)
}

@MainActor
struct SelectionActionServiceDependencies {
    let state: SelectionToolbarState
    let ttsService: TTSService
    let screenOCR: ScreenOCRService
    let llmPipeline: LLMPipeline
    let dictionaryAPI: DictionaryAPIService
    let selectionToolbarManager: SelectionToolbarManager
    let answerPanelManager: AnswerPanelManager
    let llmSettings: LLMSettings
    let notificationCenter: NotificationCenter
    let copyText: (String) -> Void
    let scheduleToolbarHide: () -> Void
}

/// 选择工具栏动作执行服务
@MainActor
final class SelectionActionService {
    
    // MARK: - Singleton
    
    static let shared = SelectionActionService(dependencies: .makeLive())
    
    // MARK: - Dependencies
    
    private let dependencies: SelectionActionServiceDependencies
    
    /// 当前 TTS 播放任务
    private var currentTTSTask: Task<Void, Never>?
    
    // MARK: - Init
    
    private init(
        dependencies: SelectionActionServiceDependencies
    ) {
        self.dependencies = dependencies
        setupNotifications()
    }
    
    // MARK: - Setup
    
    private func setupNotifications() {
        // 监听动作请求 (新版 ToolbarAction)
        dependencies.notificationCenter.addObserver(
            forName: .selectionToolbarActionRequested,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            runSelectionActionServiceOnMain(self) { service in
                await service.handleActionRequest(notification)
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
        dependencies.state.updateActionPhase(.idle)
        dependencies.state.executingActionId = nil
    }
    
    /// 执行工具栏动作 (新版，支持自定义动作)
    func executeToolbarAction(_ action: ToolbarAction, context: SelectionContext) async {
        logger.info("📋 [ActionService] executeToolbarAction 开始 | action.id: \(action.id) | action.kind: \(String(describing: action.kind))")
        dependencies.state.updateActionPhase(.executing(progress: nil))
        
        do {
            switch action.kind {
            case .builtin(let builtinType):
                // 内置动作（使用可配置的提示词和模型）
                try await executeBuiltinAction(builtinType, action: action, context: context)
                
            case .custom(let prompt):
                // 自定义动作：使用提示词模板
                try await executeCustomAction(action: action, prompt: action.effectivePrompt ?? prompt, context: context)
            }
            
            finishAction(.success(actionID: action.id))
        } catch {
            finishAction(.failure(error))
        }
    }
    
    /// 执行内置动作
    private func executeBuiltinAction(_ type: SelectionToolbarActionType, action: ToolbarAction, context: SelectionContext) async throws {
        logger.info("📋 [ActionService] executeBuiltinAction | type: \(type.rawValue)")
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
        
        try await executePanelAction(
            question: previewQuestion(context.selectedText),
            prompt: finalPrompt,
            action: action
        )
        
        logger.info("📋 [ActionService] 自定义动作完成")
    }
    
    /// 根据 Action 配置调用 LLM
    private func callLLM(prompt: String, action: ToolbarAction) async -> Result<LLMResponse, LLMError> {
        // 如果指定了 profileId，使用指定的 Profile
        if let profileId = action.profileId,
           let profile = dependencies.llmSettings.profiles.first(where: { $0.id == profileId }) {
            // 使用指定的 Profile
            if action.enableSearch {
                let textResult = await dependencies.llmPipeline.processWithSearch(query: prompt, systemPrompt: prompt)
                return textResult.map { LLMResponse(text: $0) }
            } else {
                return await dependencies.llmPipeline.chat(prompt, profile: profile)
            }
        }
        
        // 否则使用默认模型
        if action.enableSearch {
            let textResult = await dependencies.llmPipeline.processWithSearch(query: prompt, systemPrompt: prompt)
            return textResult.map { LLMResponse(text: $0) }
        } else {
            return await dependencies.llmPipeline.chat(prompt)
        }
    }
    
    // MARK: - Action Implementations
    
    /// 朗读动作
    private func executeSpeakAction(text: String) async throws {
        logger.info("📋 [ActionService] 执行朗读 | 文本长度: \(text.count)")
        
        // 使用 TTSService 朗读（支持分块、会自动停止之前的播放）
        dependencies.ttsService.speak(text)
        
        logger.info("📋 [ActionService] 朗读已启动")
        
        // 朗读是异步的，直接返回让用户继续操作
    }
    
    /// 词典查询动作
    private func executeDictionaryAction(text: String) async throws {
        let word = text.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.info("📋 [ActionService] 执行查词 | 单词: \(word)")
        
        // 🔥 开始执行动作，阻止工具栏被隐藏
        dependencies.selectionToolbarManager.beginAction()
        defer { dependencies.selectionToolbarManager.endAction() }
        
        // 调用词典 API
        let result = await dependencies.dictionaryAPI.lookup(word)
        
        // 工具栏原地变换显示词典结果
        switch result {
        case .success(let data):
            logger.info("📋 [ActionService] 查词成功: \(data.word), senses: \(data.senses.count)")
            dependencies.state.showDictionaryResult(data, forText: word)
            
        case .failure(let error):
            logger.error("📋 [ActionService] 查词失败: \(error.localizedDescription)")
            dependencies.state.showDictionaryError(error, word: word)
        }
    }
    
    /// 查询动作 (联网搜索 + AI 解释)
    private func executeLookupAction(action: ToolbarAction, context: SelectionContext) async throws {
        logger.info("📋 [ActionService] 执行查询 | 文本: \(context.selectedText.prefix(50))... | 联网: \(action.enableSearch)")
        
        let selectedText = context.selectedText
        
        // 1. 获取工具栏位置并隐藏工具栏
        let anchorPoint = hideToolbarAndCaptureAnchor()
        
        // 2. 获取 OCR 上下文 (如果启用)
        var ocrContext: String?
        if dependencies.state.config.enableOCRContext {
            ocrContext = await dependencies.screenOCR.getActiveWindowText(maxLength: dependencies.state.config.ocrContextMaxLength)
        }
        
        // 3. 构建查询 Prompt（使用可配置的提示词）并显示 AnswerPanel
        try await executeTemplatedPanelAction(
            question: selectedText,
            template: action.effectivePrompt ?? ToolbarActionDefaults.lookupPrompt,
            selection: selectedText,
            context: ocrContext,
            action: action,
            anchorPoint: anchorPoint
        )
        
        logger.info("📋 [ActionService] 查询完成")
    }
    
    /// 翻译动作
    private func executeTranslateAction(action: ToolbarAction, text: String) async throws {
        logger.info("📋 [ActionService] 执行翻译 | 文本长度: \(text.count)")
        
        // 1. 获取工具栏位置并隐藏工具栏
        let anchorPoint = hideToolbarAndCaptureAnchor()
        
        // 2. 构建提示词（使用可配置的提示词）并显示 AnswerPanel
        try await executeTemplatedPanelAction(
            question: previewQuestion(text, prefix: "翻译: "),
            template: action.effectivePrompt ?? ToolbarActionDefaults.translatePrompt,
            selection: text,
            context: nil,
            action: action,
            anchorPoint: anchorPoint
        )

        logger.info("📋 [ActionService] 翻译完成")
    }
    
    /// 总结动作
    private func executeSummarizeAction(action: ToolbarAction, context: SelectionContext) async throws {
        logger.info("📋 [ActionService] 执行总结 | 文本长度: \(context.selectedText.count)")
        
        // 1. 获取工具栏位置并隐藏工具栏
        let anchorPoint = hideToolbarAndCaptureAnchor()
        
        // 2. 构建提示词（使用可配置的提示词）并显示 AnswerPanel
        try await executeTemplatedPanelAction(
            question: previewQuestion(context.selectedText, prefix: "总结: "),
            template: action.effectivePrompt ?? ToolbarActionDefaults.summarizePrompt,
            selection: context.selectedText,
            context: nil,
            action: action,
            anchorPoint: anchorPoint
        )
        
        logger.info("📋 [ActionService] 总结完成")
    }
    
    /// 复制动作
    private func executeCopyAction(text: String) {
        logger.info("📋 [ActionService] 执行复制 | 文本长度: \(text.count)")
        
        dependencies.copyText(text)
        
        // 显示简短的成功提示
        dependencies.state.showResult("已复制到剪贴板")
        
        // 自动隐藏
        dependencies.scheduleToolbarHide()
    }
    
    // MARK: - Helpers

    private func handleActionRequest(_ notification: Notification) async {
        guard let context = notification.userInfo?["context"] as? SelectionContext else {
            return
        }

        if let toolbarAction = notification.userInfo?["toolbarAction"] as? ToolbarAction {
            await executeToolbarAction(toolbarAction, context: context)
            return
        }

        guard let action = notification.userInfo?["action"] as? SelectionToolbarActionType else {
            return
        }

        await executeAction(action, context: context)
    }

    private func finishAction(_ outcome: SelectionActionFinishOutcome) {
        switch outcome {
        case .success(let actionID):
            dependencies.state.updateActionPhase(.completed)
            dependencies.state.executingActionId = nil
            dependencies.notificationCenter.post(
                name: .selectionToolbarActionCompleted,
                object: nil,
                userInfo: ["actionId": actionID, "success": true]
            )

        case .failure(let error):
            dependencies.state.updateActionPhase(.failed(message: error.localizedDescription))
            dependencies.state.executingActionId = nil
            logger.error("📋 [ActionService] 工具栏动作执行失败: \(error.localizedDescription)")
        }
    }

    private func executeTemplatedPanelAction(
        question: String,
        template: String,
        selection: String,
        context: String?,
        action: ToolbarAction,
        anchorPoint: CGPoint?
    ) async throws {
        let prompt = buildPromptFromTemplate(
            template: template,
            selection: selection,
            context: context
        )
        try await executePanelLLMAction(
            question: question,
            prompt: prompt,
            action: action,
            anchorPoint: anchorPoint
        )
    }

    private func executePanelAction(
        question: String,
        prompt: String,
        action: ToolbarAction
    ) async throws {
        try await executePanelLLMAction(
            question: question,
            prompt: prompt,
            action: action,
            anchorPoint: hideToolbarAndCaptureAnchor()
        )
    }

    private func executePanelLLMAction(
        question: String,
        prompt: String,
        action: ToolbarAction,
        anchorPoint: CGPoint?
    ) async throws {
        let panelId = showAnswerPanel(question: question, anchorPoint: anchorPoint)
        let chatResult = await callLLM(prompt: prompt, action: action)
        switch chatResult {
        case .success(let result):
            dependencies.answerPanelManager.updateAnswer(result, for: panelId)
        case .failure(let error):
            dependencies.answerPanelManager.showError(error.localizedDescription, for: panelId)
            throw error
        }
    }

    private func showAnswerPanel(question: String, anchorPoint: CGPoint?) -> UUID {
        if let anchorPoint {
            return dependencies.answerPanelManager.showBelowAnchor(
                question: question,
                anchorPoint: anchorPoint
            )
        }

        return dependencies.answerPanelManager.show(question: question, attachments: [])
    }

    private func previewQuestion(_ text: String, prefix: String = "") -> String {
        "\(prefix)\(text.prefix(SelectionActionServiceDefaults.questionPreviewLength))..."
    }
    
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

    private func hideToolbarAndCaptureAnchor() -> CGPoint? {
        let anchorPoint = dependencies.selectionToolbarManager.toolbarBottomCenter
        dependencies.selectionToolbarManager.hide()
        return anchorPoint
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
