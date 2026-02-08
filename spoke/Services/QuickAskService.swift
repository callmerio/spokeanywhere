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

/// Quick Ask 服务
/// 管理 Quick Ask 功能的整体流程
@MainActor
final class QuickAskService {
    
    // MARK: - Singleton
    
    static let shared = QuickAskService()
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "QuickAsk")
    
    // MARK: - Constants
    
    private enum Constants {
        static let recordingStartDelay: TimeInterval = 0.2
    }
    
    // MARK: - Dependencies
    
    private let hudManager = QuickAskHUDManager.shared
    private let contextService = ContextService.shared
    private let audioService = AudioRecorderService.shared
    private let llmPipeline = LLMPipeline.shared
    
    // MARK: - Properties
    
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    
    /// 当前状态
    var state: QuickAskState {
        hudManager.state
    }
    
    /// 是否处于 Quick Ask 模式
    var isActive: Bool {
        state.phase != .idle
    }
    
    // MARK: - Init
    
    private init() {
        setupHUDCallbacks()
        setupAudioCallbacks()
    }
    
    // MARK: - Setup
    
    private func setupHUDCallbacks() {
        hudManager.onSend = { [weak self] in
            Task { @MainActor in
                await self?.sendQuestion()
            }
        }
        
        hudManager.onCancel = { [weak self] in
            Task { @MainActor in
                self?.cancelSession()
            }
        }
        
        // 监听追问通知
        NotificationCenter.default.addObserver(
            forName: .quickAskFollowUpRequested,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let panelId = userInfo["panelId"] as? UUID,
                  let prompt = userInfo["prompt"] as? String,
                  let attachments = userInfo["attachments"] as? [Attachment] else {
                return
            }
            
            Task {
                await self.handleFollowUp(panelId: panelId, prompt: prompt, attachments: attachments)
            }
        }
    }
    
    private func setupAudioCallbacks() {
        // 注意：这里需要区分是 Quick Ask 还是普通录音
        // 暂时先复用 audioService 的回调
    }
    
    // MARK: - Public API
    
    /// 启动 Quick Ask 会话
    func startSession() {
        let targetApp = contextService.getCurrentTargetApp()
        
        // 显示 HUD（这会激活窗口和输入法上下文）
        hudManager.show(targetApp: targetApp)
        
        // 记录开始时间
        recordingStartTime = Date()
        
        // 启动计时器
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateRecordingDuration()
            }
        }
        
        // 🔥 延迟启动录音，避免阻塞主线程导致输入法通信失败
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.recordingStartDelay) { [weak self] in
            guard let self = self else { return }
            do {
                try self.startQuickAskRecording()
                self.logger.info("🎙️ Quick Ask session started")
            } catch {
                self.logger.error("❌ Failed to start Quick Ask recording: \(error)")
                self.hudManager.fail(with: "录音启动失败")
            }
        }
    }
    
    /// 发送问题
    func sendQuestion() async {
        // 停止录音
        stopRecording()
        
        // 切换到发送状态
        state.startSending()
        
        let settings = LLMSettings.shared
        var contextSources: [ContextSource] = []
        
        // 异步获取 OCR 上下文
        var ocrContext: String?
        if settings.quickAskIncludeOCR {
            ocrContext = await ScreenOCRService.shared.getActiveWindowText(maxLength: 2000)
            if ocrContext != nil && !ocrContext!.isEmpty {
                contextSources.append(.ocr)
            }
        }
        
        // 获取截图（如果开启）
        var screenshotImage: CGImage?
        if settings.quickAskIncludeScreenshot {
            screenshotImage = await ScreenOCRService.shared.captureActiveWindow()
            if screenshotImage != nil {
                contextSources.append(.screenshot)
            }
        }
        
        // 组装 prompt（包含上下文来源追踪）
        let promptResult = buildPromptResult(ocrContext: ocrContext)
        if promptResult.usedClipboard { contextSources.append(.clipboard) }
        if promptResult.usedCaption { contextSources.append(.liveCaption) }
        
        guard !promptResult.prompt.isEmpty else {
            hudManager.fail(with: "请输入问题")
            return
        }
        
        let questionPreview = String(promptResult.prompt.prefix(100))
        let sourceList = contextSources.map { $0.rawValue }
        logger.info(
            "📤 Sending question: \(questionPreview, privacy: .public)... sources: \(sourceList, privacy: .public)"
        )
        
        // 隐藏输入 HUD (不恢复 Policy，因为 AnswerPanel 需要 Key Window)
        hudManager.hide(restorePolicy: false)
        
        // 分离手动输入和语音转录（用于 UI 区分显示）
        let userInputText = state.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let voiceText = state.voiceTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 显示回答窗口（传递上下文来源 + 语音转录）
        let panelId = AnswerPanelManager.shared.show(
            question: userInputText,
            voiceTranscription: voiceText.isEmpty ? nil : voiceText,
            attachments: state.attachments,
            contextSources: contextSources,
            screenshotImage: screenshotImage
        )
        
        // 调用 LLM
        let result = await llmPipeline.chat(promptResult.prompt)
        
        switch result {
        case .success(let response):
            AnswerPanelManager.shared.updateAnswer(response, for: panelId)
            logger.info("✅ Quick Ask completed (\(response.images.count, privacy: .public) images)")
            
        case .failure(let error):
            AnswerPanelManager.shared.showError(error.localizedDescription, for: panelId)
            logger.error("❌ Quick Ask failed: \(error, privacy: .public)")
        }
        
        // 重置状态
        state.reset()
        
        // 重置 HotKeyService 状态
        HotKeyService.shared.resetQuickAskState()
    }
    
    /// 取消会话
    func cancelSession() {
        stopRecording()
        hudManager.hide()
        state.reset()
        
        // 重置 HotKeyService 状态
        HotKeyService.shared.resetQuickAskState()
        
        logger.info("🚫 Quick Ask cancelled")
    }
    
    /// 重新开始录音
    func restartRecording() {
        // 停止当前录音
        audioService.cancelRecording()
        
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
            Task {
                await sendQuestion()
            }
        }
    }
    
    /// 处理追问
    private func handleFollowUp(panelId: UUID, prompt: String, attachments: [Attachment]) async {
        logger.info("🔄 Handling follow-up [\(panelId)]: \(prompt)")
        
        // 1. 获取指定面板的历史记录
        guard let panelState = AnswerPanelManager.shared.state(for: panelId) else {
            logger.error("❌ Panel not found: \(panelId)")
            return
        }
        
        let history = panelState.messages
        // 注意：此时 history 已经包含了当前最新的 user message (由 AnswerPanelView 添加)
        
        var finalPrompt = ""
        
        // 简单的 history 拼接 (排除最后一条，因为它是当前问题)
        if history.count > 1 {
            finalPrompt += "以下是之前的对话历史：\n\n"
            for message in history.dropLast() {
                let role = message.role == .user ? "用户" : "AI"
                // 简单的防注入处理
                let content = message.content.replacingOccurrences(of: "\n", with: " ")
                finalPrompt += "\(role): \(content)\n"
            }
            finalPrompt += "\n---\n\n"
        }
        
        // 2. 添加当前问题
        finalPrompt += "用户当前问题: \(prompt)"
        
        // 3. 调用 LLM
        let result = await llmPipeline.chat(finalPrompt)
        
        switch result {
        case .success(let response):
            AnswerPanelManager.shared.updateAnswer(response, for: panelId)
            logger.info("✅ Follow-up completed [\(panelId)] (\(response.images.count) images)")
            
        case .failure(let error):
            AnswerPanelManager.shared.showError(error.localizedDescription, for: panelId)
            logger.error("❌ Follow-up failed [\(panelId)]: \(error)")
        }
    }
    
    // MARK: - Private
    
    private func startQuickAskRecording() throws {
        // 设置音频回调（Quick Ask 专用）
        audioService.onAudioLevelUpdate = { [weak self] level in
            Task { @MainActor in
                self?.state.updateAudioLevel(level)
            }
        }
        
        audioService.onPartialResult = { [weak self] result in
            Task { @MainActor in
                self?.state.updateVoiceTranscription(result.text)
            }
        }
        
        // 启动录音
        try audioService.startRecording()
    }
    
    private func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
        
        _ = audioService.stopRecording()
    }
    
    private func updateRecordingDuration() {
        guard let startTime = recordingStartTime else { return }
        let duration = Date().timeIntervalSince(startTime)
        state.updateDuration(duration)
    }
    
    private struct PromptBuildResult {
        let prompt: String
        let usedClipboard: Bool
        let usedCaption: Bool
    }
    
    private struct AttachmentSummary {
        let summaryLine: String
        let textBundleContents: [String]
    }
    
    /// 构建发送给 LLM 的 prompt（带上下文来源追踪）
    private func buildPromptResult(ocrContext: String? = nil) -> PromptBuildResult {
        let settings = LLMSettings.shared
        var parts: [String] = []
        
        let userInput = trimmedText(state.userInput)
        let voiceText = trimmedText(state.voiceTranscription)
        
        appendUserInput(userInput, to: &parts)
        appendVoiceText(voiceText, userInput: userInput, to: &parts)
        appendOCRContext(ocrContext, to: &parts)
        
        let usedClipboard = appendClipboardIfNeeded(settings: settings, to: &parts)
        let usedCaption = appendLiveCaptionIfNeeded(settings: settings, to: &parts)
        appendAttachments(to: &parts)
        
        return PromptBuildResult(
            prompt: parts.joined(separator: "\n\n"),
            usedClipboard: usedClipboard,
            usedCaption: usedCaption
        )
    }
    
    private func trimmedText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func appendUserInput(_ userInput: String, to parts: inout [String]) {
        if !userInput.isEmpty {
            parts.append("## 用户输入\n\(userInput)")
        }
    }
    
    private func appendVoiceText(_ voiceText: String, userInput: String, to parts: inout [String]) {
        guard !voiceText.isEmpty else { return }
        parts.append("## 语音转写\n\(voiceText)")
        if !userInput.isEmpty {
            parts.append("> 注意：语音转写可能存在偏差（如专业术语、人名等），请结合用户输入理解真实意图。")
        }
    }
    
    private func appendOCRContext(_ ocrContext: String?, to parts: inout [String]) {
        guard let ocrText = ocrContext, !ocrText.isEmpty else { return }
        parts.append("## 当前屏幕内容（OCR）\n\(ocrText)")
    }
    
    private func appendClipboardIfNeeded(settings: LLMSettings, to parts: inout [String]) -> Bool {
        guard settings.quickAskIncludeClipboard else { return false }
        let history = ClipboardHistoryService.shared.getHistoryForContext(limit: 5)
        guard !history.isEmpty else { return false }
        let historyText = history.map { "- \(String($0.prefix(200)))" }.joined(separator: "\n")
        parts.append("## 剪贴板历史\n\(historyText)")
        return true
    }
    
    private func appendLiveCaptionIfNeeded(settings: LLMSettings, to parts: inout [String]) -> Bool {
        guard settings.quickAskIncludeLiveCaption else { return false }
        let limit = settings.quickAskLiveCaptionLimit
        let captionText = LiveCaptionManager.shared.getOriginalTextHistory(limit: limit)
        guard !captionText.isEmpty else { return false }
        let limitDesc = limit == 0 ? "全量" : "最近\(limit)条"
        parts.append("## 实时字幕历史（\(limitDesc)）\n\(captionText)")
        return true
    }
    
    private func appendAttachments(to parts: inout [String]) {
        guard !state.attachments.isEmpty else { return }
        let summary = buildAttachmentSummary(from: state.attachments)
        parts.append("## 附件\n\(summary.summaryLine)")
        
        guard !summary.textBundleContents.isEmpty else { return }
        let bundleText = summary.textBundleContents.joined(separator: "\n\n---\n\n")
        parts.append("## 代码/文档内容\n\(bundleText)")
    }
    
    private func buildAttachmentSummary(from attachments: [Attachment]) -> AttachmentSummary {
        var attachmentParts: [String] = []
        var textBundleContents: [String] = []
        
        for attachment in attachments {
            switch attachment {
            case .image:
                attachmentParts.append("[图片]")
            case .screenshot:
                attachmentParts.append("[截图]")
            case .file(let url, _):
                attachmentParts.append("[文件: \(url.lastPathComponent)]")
            case .textBundle(let content, let source, let count, _):
                attachmentParts.append("[代码包: \(source) (\(count) 文件)]")
                textBundleContents.append("### \(source)\n\(content)")
            }
        }
        
        return AttachmentSummary(
            summaryLine: attachmentParts.joined(separator: ", "),
            textBundleContents: textBundleContents
        )
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
    
    static let shared = QuickAskHUDManager()
    
    // MARK: - Properties
    
    private var panel: QuickAskPanel?
    let state: QuickAskState
    
    /// 发送回调
    var onSend: (() -> Void)?
    /// 取消回调（ESC 键）
    var onCancel: (() -> Void)?
    
    /// ESC 键取消观察者
    private var cancelObserver: NSObjectProtocol?
    
    // MARK: - Init
    
    private init() {
        self.state = QuickAskState()
        setupCancelObserver()
    }
    
    private func setupCancelObserver() {
        cancelObserver = NotificationCenter.default.addObserver(
            forName: .quickAskCancelRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.onCancel?()
            }
        }
    }
    
    // MARK: - Public API
    
    func show(targetApp: TargetAppInfo?) {
        print("📱 QuickAskService.show() called")
        createPanelIfNeeded()
        
        // 🔥 第一步：禁用 event tap，避免干扰输入法（必须在窗口激活前执行）
        HotKeyService.shared.setQuickAskActive(true)
        
        // 启用按键调试日志
        HotKeyService.shared.debugKeyEvents = true
        
        // 🔥 第二步：切换到普通应用模式以支持输入法
        NSApp.setActivationPolicy(.regular)
        print("📱 Activation policy set to .regular")
        
        state.startSession(targetApp: targetApp)
        
        panel?.positionAtBottomCenter()
        
        // 🔥 第三步：先显示窗口
        panel?.orderFront(nil)
        
        // 🔥 第四步：延迟一帧再激活（等待窗口完全显示）
        DispatchQueue.main.async { [weak self] in
            guard let panel = self?.panel else { return }
            
            // 激活应用（强制激活，忽略其他应用）
            NSApp.activate(ignoringOtherApps: true)
            
            // 让窗口成为 key window 和 main window
            panel.makeKeyAndOrderFront(nil)
            panel.makeMain()
            
            print("📱 QuickAskService.show() activated, isKeyWindow: \(panel.isKeyWindow), isMainWindow: \(panel.isMainWindow)")
        }
    }
    
    func hide(restorePolicy: Bool = true) {
        // 关闭按键调试日志
        HotKeyService.shared.debugKeyEvents = false
        
        // 🔥 重新启用 event tap
        HotKeyService.shared.setQuickAskActive(false)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            panel?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor in
                self?.panel?.orderOut(nil)
                self?.panel?.alphaValue = 1
                // 恢复为辅助应用模式
                if restorePolicy {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
    }
    
    func fail(with message: String) {
        state.fail(with: message)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.hide()
            self?.state.reset()
        }
    }
    
    // MARK: - Private
    
    private func createPanelIfNeeded() {
        guard panel == nil else { return }
        
        var contentView = QuickAskCapsuleView(state: state)
        contentView.onSend = { [weak self] in
            self?.onSend?()
        }
        contentView.onCancel = { [weak self] in
            self?.onCancel?()
        }
        
        let framedView = contentView
            .frame(width: Self.fixedWindowWidth, height: Self.fixedWindowHeight, alignment: .bottom)
        
        let hostingView = NSHostingView(rootView: framedView)
        
        let frame = NSRect(
            origin: .zero,
            size: NSSize(width: Self.fixedWindowWidth, height: Self.fixedWindowHeight)
        )
        
        let newPanel = QuickAskPanel(contentRect: frame)
        newPanel.contentView = hostingView
        
        self.panel = newPanel
    }
}
