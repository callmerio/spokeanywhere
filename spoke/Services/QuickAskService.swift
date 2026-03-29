import AppKit
import Foundation
import os
import SwiftUI

/// Quick Ask 上下文来源
enum ContextSource: String, CaseIterable {
    case ocr = "OCR"
    case screenshot = "截图"
    case clipboard = "剪贴板"
    case liveCaption = "实时字幕"
    
    var icon: String {
        switch self {
        case .ocr: return "text.viewfinder"
        case .screenshot: return "photo"
        case .clipboard: return "doc.on.clipboard"
        case .liveCaption: return "captions.bubble"
        }
    }
}

@MainActor
struct QuickAskCapsuleViewDependencies {
    let clipboardText: () -> String?
    let hideHUD: (_ restorePolicy: Bool) -> Void
    let showAnswerPanel: (_ question: String, _ attachments: [Attachment]) -> UUID
    let updateAnswer: (_ answer: String, _ panelId: UUID) -> Void
    let showAnswerError: (_ message: String, _ panelId: UUID) -> Void
    let executeWorkflow: (_ workflow: WorkflowAction, _ context: WorkflowContext) async -> Result<String, WorkflowError>
}

@MainActor
struct QuickAskHUDManagerDependencies {
    let hotKeyService: HotKeyService
    let workflowState: WorkflowState
    let attachmentManager: AttachmentManager
    let notificationCenter: NotificationCenter
    let windowRuntime: QuickAskHUDWindowRuntime
    let clipboardText: () -> String?
    let showAnswerPanel: (_ question: String, _ attachments: [Attachment]) -> UUID
    let updateAnswer: (_ answer: String, _ panelId: UUID) -> Void
    let showAnswerError: (_ message: String, _ panelId: UUID) -> Void
    let executeWorkflow: (_ workflow: WorkflowAction, _ context: WorkflowContext) async -> Result<String, WorkflowError>
    let openSettings: () -> Void
}

@MainActor
struct QuickAskServiceDependencies {
    let hudManager: QuickAskHUDManager
    let contextService: ContextService
    let audioService: AudioRecorderService
    let llmPipeline: LLMPipeline
    let llmSettings: LLMSettings
    let screenOCRService: ScreenOCRService
    let answerPanelManager: AnswerPanelManager
    let hotKeyService: HotKeyService
    let clipboardHistoryService: ClipboardHistoryService
    let liveCaptionManager: LiveCaptionManager
    let notificationCenter: NotificationCenter
}

/// Quick Ask 服务
/// 管理 Quick Ask 功能的整体流程
@MainActor
final class QuickAskService {
    
    // MARK: - Singleton
    
    static let shared = QuickAskService(dependencies: .makeLive())
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "QuickAsk")
    
    // MARK: - Constants
    
    private enum Constants {
        static let recordingStartDelay: TimeInterval = 0.2
    }
    
    // MARK: - Dependencies
    
    private let dependencies: QuickAskServiceDependencies
    
    // MARK: - Properties
    
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var quickAskCallbackSessionID: UUID?
    
    /// 当前状态
    var state: QuickAskState {
        dependencies.hudManager.state
    }
    
    /// 是否处于 Quick Ask 模式
    var isActive: Bool {
        state.phase != .idle
    }
    
    // MARK: - Init
    
    private init(
        dependencies: QuickAskServiceDependencies
    ) {
        self.dependencies = dependencies
        setupHUDCallbacks()
    }
    
    // MARK: - Setup
    
    private func setupHUDCallbacks() {
        dependencies.hudManager.onSend = makeAsyncAction { service in
            await service.sendQuestion()
        }
        
        dependencies.hudManager.onCancel = makeAction { service in
            service.cancelSession()
        }
        
        // 监听追问通知
        dependencies.notificationCenter.addObserver(
            forName: .quickAskFollowUpRequested,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handleFollowUpNotification(notification)
            }
        }
    }
    
    private func registerAudioCallbacks() {
        if quickAskCallbackSessionID == nil {
            quickAskCallbackSessionID = dependencies.audioService.createCallbackSession()
        }

        guard let sessionID = quickAskCallbackSessionID else { return }
        dependencies.audioService.updateCallbackSession(sessionID) { [weak self] callbacks in
            callbacks.onAudioLevelUpdate = self?.makeAction { service, level in
                service.state.updateAudioLevel(level)
            }

            callbacks.onPartialResult = self?.makeAction { service, result in
                service.state.updateVoiceTranscription(result.text)
            }

            callbacks.onFinalResult = nil
            callbacks.onError = { [weak self] error in
                self?.logger.error("❌ Quick Ask audio error: \(error.localizedDescription, privacy: .public)")
            }
        }

        dependencies.audioService.activateCallbackSession(sessionID)
    }

    private func unregisterAudioCallbacks() {
        guard let sessionID = quickAskCallbackSessionID else { return }
        dependencies.audioService.removeCallbackSession(sessionID)
        quickAskCallbackSessionID = nil
    }
    
    // MARK: - Public API
    
    /// 启动 Quick Ask 会话
    func startSession() {
        let targetApp = dependencies.contextService.getCurrentTargetApp()
        
        // 显示 HUD（这会激活窗口和输入法上下文）
        dependencies.hudManager.show(targetApp: targetApp)
        
        // 记录开始时间
        recordingStartTime = Date()
        
        // 启动计时器
        startRecordingTimer()
        
        // 🔥 延迟启动录音，避免阻塞主线程导致输入法通信失败
        runQuickAskServiceAfterDelay(self, seconds: Constants.recordingStartDelay) { service in
            do {
                try service.startQuickAskRecording()
                service.logger.info("🎙️ Quick Ask session started")
            } catch {
                service.logger.error("❌ Failed to start Quick Ask recording: \(error)")
                service.dependencies.hudManager.fail(with: "录音启动失败")
            }
        }
    }
    
    /// 发送问题
    func sendQuestion() async {
        // 停止录音
        stopRecording()
        
        // 切换到发送状态
        state.startSending()
        
        let settings = dependencies.llmSettings
        var contextSources: [ContextSource] = []
        
        // 异步获取 OCR 上下文
        var ocrContext: String?
        if settings.quickAskIncludeOCR {
            ocrContext = await dependencies.screenOCRService.getActiveWindowText(maxLength: 2000)
            if ocrContext != nil && !ocrContext!.isEmpty {
                contextSources.append(.ocr)
            }
        }
        
        // 获取截图（如果开启）
        var screenshotImage: CGImage?
        if settings.quickAskIncludeScreenshot {
            screenshotImage = await dependencies.screenOCRService.captureActiveWindow()
            if screenshotImage != nil {
                contextSources.append(.screenshot)
            }
        }
        
        // 组装 prompt（包含上下文来源追踪）
        let promptResult = buildPromptResult(ocrContext: ocrContext)
        if promptResult.usedClipboard { contextSources.append(.clipboard) }
        if promptResult.usedCaption { contextSources.append(.liveCaption) }
        
        guard !promptResult.prompt.isEmpty else {
            dependencies.hudManager.fail(with: "请输入问题")
            return
        }
        
        let questionPreview = String(promptResult.prompt.prefix(100))
        let sourceList = contextSources.map { $0.rawValue }
        logger.info(
            "📤 Sending question: \(questionPreview, privacy: .public)... sources: \(sourceList, privacy: .public)"
        )
        
        // 隐藏输入 HUD (不恢复 Policy，因为 AnswerPanel 需要 Key Window)
        dependencies.hudManager.hide(restorePolicy: false)
        
        // 分离手动输入和语音转录（用于 UI 区分显示）
        let userInputText = state.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let voiceText = state.voiceTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 显示回答窗口（传递上下文来源 + 语音转录）
        let panelId = dependencies.answerPanelManager.show(
            question: userInputText,
            voiceTranscription: voiceText.isEmpty ? nil : voiceText,
            attachments: state.attachments,
            contextSources: contextSources,
            screenshotImage: screenshotImage
        )
        
        // 调用 LLM
        let result = await dependencies.llmPipeline.chat(promptResult.prompt)
        
        switch result {
        case .success(let response):
            dependencies.answerPanelManager.updateAnswer(response, for: panelId)
            logger.info("✅ Quick Ask completed (\(response.images.count, privacy: .public) images)")
            
        case .failure(let error):
            dependencies.answerPanelManager.showError(error.localizedDescription, for: panelId)
            logger.error("❌ Quick Ask failed: \(error, privacy: .public)")
        }
        
        // 重置状态
        resetSessionState()
    }
    
    /// 取消会话
    func cancelSession() {
        stopRecording()
        dependencies.hudManager.hide()
        resetSessionState()
        
        logger.info("🚫 Quick Ask cancelled")
    }
    
    /// 重新开始录音
    func restartRecording() {
        // 停止当前录音
        dependencies.audioService.cancelRecording()
        unregisterAudioCallbacks()
        
        // 重置录音相关状态
        state.restartRecording()
        recordingStartTime = Date()
        
        // 重新启动录音
        do {
            try startQuickAskRecording()
            logger.info("🔄 Quick Ask recording restarted")
        } catch {
            logger.error("❌ Failed to restart recording: \(error)")
        }
    }
    
    /// 通过快捷键发送（再次按下快捷键）
    func sendViaShortcut() {
        if state.canSend {
            runQuickAskServiceOnMain(self) { service in
                await service.sendQuestion()
            }
        }
    }

    private func handleFollowUpNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let panelId = userInfo["panelId"] as? UUID,
              let prompt = userInfo["prompt"] as? String,
              let attachments = userInfo["attachments"] as? [Attachment] else {
            return
        }

        runQuickAskServiceOnMain(self) { service in
            await service.handleFollowUp(panelId: panelId, prompt: prompt, attachments: attachments)
        }
    }
    
    /// 处理追问
    private func handleFollowUp(panelId: UUID, prompt: String, attachments: [Attachment]) async {
        logger.info("🔄 Handling follow-up [\(panelId)]: \(prompt)")
        
        // 1. 获取指定面板的历史记录
        guard let panelState = dependencies.answerPanelManager.state(for: panelId) else {
            logger.error("❌ Panel not found: \(panelId)")
            return
        }
        
        let history = panelState.messages
        // 注意：此时 history 已经包含了当前最新的 user message (由 AnswerPanelView 添加)

        let finalPrompt = buildFollowUpPrompt(history: history, prompt: prompt)
        
        // 3. 调用 LLM
        let result = await dependencies.llmPipeline.chat(finalPrompt)
        
        switch result {
        case .success(let response):
            dependencies.answerPanelManager.updateAnswer(response, for: panelId)
            logger.info("✅ Follow-up completed [\(panelId)] (\(response.images.count) images)")
            
        case .failure(let error):
            dependencies.answerPanelManager.showError(error.localizedDescription, for: panelId)
            logger.error("❌ Follow-up failed [\(panelId)]: \(error)")
        }
    }
    
    // MARK: - Private
    
    private func startQuickAskRecording() throws {
        // Quick Ask 使用独立会话回调，避免覆盖普通录音
        registerAudioCallbacks()

        do {
            try dependencies.audioService.startRecording()
        } catch {
            unregisterAudioCallbacks()
            throw error
        }
    }
    
    private func stopRecording() {
        stopRecordingTimer()
        
        _ = dependencies.audioService.stopRecording()
        unregisterAudioCallbacks()
    }
    
    private func updateRecordingDuration() {
        guard let startTime = recordingStartTime else { return }
        let duration = Date().timeIntervalSince(startTime)
        state.updateDuration(duration)
    }

    private func startRecordingTimer() {
        recordingTimer = makeQuickAskTimer(interval: 0.1, repeats: true, owner: self) { service in
            service.updateRecordingDuration()
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
    }

    private func resetSessionState() {
        state.reset()
        dependencies.hotKeyService.resetQuickAskState()
    }

    private func makeAction(
        _ action: @escaping @MainActor (QuickAskService) -> Void
    ) -> () -> Void {
        { [weak self] in
            runQuickAskServiceOnMain(self) { service in
                action(service)
            }
        }
    }

    private func makeAction<Value>(
        _ action: @escaping @MainActor (QuickAskService, Value) -> Void
    ) -> (Value) -> Void {
        { [weak self] value in
            runQuickAskServiceOnMain(self) { service in
                action(service, value)
            }
        }
    }

    private func makeAsyncAction(
        _ action: @escaping @MainActor (QuickAskService) async -> Void
    ) -> () -> Void {
        { [weak self] in
            runQuickAskServiceOnMain(self, action)
        }
    }
    
    /// 构建发送给 LLM 的 prompt（带上下文来源追踪）
    private func buildPromptResult(ocrContext: String? = nil) -> QuickAskPromptBuildResult {
        let settings = dependencies.llmSettings
        return QuickAskPromptAssembler.build(
            QuickAskPromptRequest(
                userInput: state.userInput,
                voiceText: state.voiceTranscription,
                ocrContext: ocrContext,
                clipboardHistory: dependencies.clipboardHistoryService.getHistoryForContext(limit: 5),
                liveCaptionText: dependencies.liveCaptionManager.getOriginalTextHistory(
                    limit: settings.quickAskLiveCaptionLimit
                ),
                liveCaptionLimit: settings.quickAskLiveCaptionLimit,
                attachments: state.attachments,
                includeOCR: settings.quickAskIncludeOCR,
                includeClipboard: settings.quickAskIncludeClipboard,
                includeLiveCaption: settings.quickAskIncludeLiveCaption
            )
        )
    }
    
    private func trimmedText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func buildFollowUpPrompt(history: [ChatMessage], prompt: String) -> String {
        var sections: [PromptSection] = []

        if history.count > 1 {
            let historyLines = history.dropLast().map { message in
                let role = message.role == .user ? "用户" : "AI"
                return "\(role): \(PromptRenderer.singleLine(message.content))"
            }
            if let historySection = PromptRenderer.section(
                title: "以下是之前的对话历史：",
                body: historyLines.joined(separator: "\n")
            ) {
                sections.append(historySection)
            }
        }

        if let questionSection = PromptRenderer.section(title: "用户当前问题:", body: prompt) {
            sections.append(questionSection)
        }

        return PromptRenderer.renderSections(sections)
    }
}

// MARK: - Quick Ask HUD Manager

/// Quick Ask HUD 管理器
@MainActor
final class QuickAskHUDManager {
    
    // MARK: - Constants
    
    private static let fixedWindowHeight: CGFloat = 500
    private static let fixedWindowWidth: CGFloat = 340
    
    // MARK: - Singleton
    
    static let shared = QuickAskHUDManager(
        dependencies: .makeLive(answerPanelManager: currentQuickAskLiveServices().answerPanelManager)
    )
    
    // MARK: - Properties
    
    private let dependencies: QuickAskHUDManagerDependencies
    private var panel: QuickAskPanel?
    let state: QuickAskState
    
    /// 发送回调
    var onSend: (() -> Void)?
    /// 取消回调（ESC 键）
    var onCancel: (() -> Void)?
    
    /// ESC 键取消观察者
    private var cancelObserver: NSObjectProtocol?
    
    // MARK: - Init
    
    private init(
        dependencies: QuickAskHUDManagerDependencies
    ) {
        self.dependencies = dependencies
        self.state = QuickAskState(attachmentManager: dependencies.attachmentManager)
        setupCancelObserver()
    }
    
    private func setupCancelObserver() {
        cancelObserver = dependencies.notificationCenter.addObserver(
            forName: .quickAskCancelRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            runQuickAskHUDManagerOnMain(self) { manager in
                manager.onCancel?()
            }
        }
    }
    
    // MARK: - Public API
    
    func show(targetApp: TargetAppInfo?) {
        createPanelIfNeeded()
        
        dependencies.windowRuntime.prepareForPresentation()
        
        state.startSession(targetApp: targetApp)
        
        panel?.positionAtBottomCenter()
        
        // 🔥 第三步：先显示窗口
        panel?.orderFront(nil)
        
        // 🔥 第四步：延迟一帧再激活（等待窗口完全显示）
        runQuickAskHUDManagerOnMain(self) { manager in
            manager.activatePanelWindow()
        }
    }
    
    func hide(restorePolicy: Bool = true) {
        dependencies.windowRuntime.restoreAfterDismissal(restorePolicy: restorePolicy)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            panel?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            runQuickAskHUDManagerOnMain(self) { manager in
                manager.finishHide(restorePolicy: restorePolicy)
            }
        }
    }
    
    func fail(with message: String) {
        state.fail(with: message)
        scheduleFailureReset()
    }
    
    // MARK: - Private
    
    private func createPanelIfNeeded() {
        guard panel == nil else { return }
        
        let capsuleDependencies = QuickAskCapsuleViewDependencies(
            clipboardText: dependencies.clipboardText,
            hideHUD: { [weak self] restorePolicy in
                self?.hide(restorePolicy: restorePolicy)
            },
            showAnswerPanel: dependencies.showAnswerPanel,
            updateAnswer: dependencies.updateAnswer,
            showAnswerError: dependencies.showAnswerError,
            executeWorkflow: dependencies.executeWorkflow
        )
        
        var contentView = QuickAskCapsuleView(
            state: state,
            workflowState: dependencies.workflowState,
            attachmentManager: dependencies.attachmentManager,
            openSettingsAction: dependencies.openSettings,
            dependencies: capsuleDependencies
        )
        contentView.onSend = { [weak self] in
            self?.onSend?()
        }
        contentView.onCancel = { [weak self] in
            self?.onCancel?()
        }
        
        let framedView = contentView
            .frame(width: Self.fixedWindowWidth, height: Self.fixedWindowHeight, alignment: .bottom)
        
        let hostingView = NSHostingView(rootView: framedView)
        hostingView.identifier = NSUserInterfaceItemIdentifier(UITestIdentifiers.Element.quickAskCapsuleRoot)
        hostingView.setAccessibilityIdentifier(UITestIdentifiers.Element.quickAskCapsuleRoot)
        
        let frame = NSRect(
            origin: .zero,
            size: NSSize(width: Self.fixedWindowWidth, height: Self.fixedWindowHeight)
        )
        
        let newPanel = QuickAskPanel(contentRect: frame)
        newPanel.identifier = NSUserInterfaceItemIdentifier(UITestIdentifiers.Window.quickAskCapsule)
        newPanel.setAccessibilityIdentifier(UITestIdentifiers.Window.quickAskCapsule)
        newPanel.contentView = hostingView
        
        self.panel = newPanel
    }

    private func activatePanelWindow() {
        dependencies.windowRuntime.activatePanelIfNeeded(panel)
    }

    private func finishHide(restorePolicy: Bool) {
        panel?.orderOut(nil)
        panel?.alphaValue = 1
        if restorePolicy {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func scheduleFailureReset() {
        runQuickAskHUDManagerAfterDelay(self, seconds: 2) { manager in
            manager.hide()
            manager.state.reset()
        }
    }
}
