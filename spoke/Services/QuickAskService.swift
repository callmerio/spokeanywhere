import Foundation
import AppKit
import SwiftUI
import os

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
        
        // 组装 prompt
        let prompt = buildPrompt()
        
        guard !prompt.isEmpty else {
            hudManager.fail(with: "请输入问题")
            return
        }
        
        logger.info("📤 Sending question: \(prompt.prefix(100))...")
        
        // 隐藏输入 HUD
        hudManager.hide()
        
        // 显示回答窗口
        AnswerPanelManager.shared.show(
            question: state.userInput.isEmpty ? state.voiceTranscription : state.userInput,
            attachments: state.attachments
        )
        
        // 调用 LLM
        let result = await llmPipeline.chat(prompt)
        
        switch result {
        case .success(let answer):
            AnswerPanelManager.shared.updateAnswer(answer)
            logger.info("✅ Quick Ask completed")
            
        case .failure(let error):
            AnswerPanelManager.shared.showError(error.localizedDescription)
            logger.error("❌ Quick Ask failed: \(error)")
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
    
    /// 构建发送给 LLM 的 prompt
    private func buildPrompt() -> String {
        var parts: [String] = []
        
        // 用户输入
        let userInput = state.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !userInput.isEmpty {
            parts.append("## 用户输入\n\(userInput)")
        }
        
        // 语音转写
        let voiceText = state.voiceTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !voiceText.isEmpty {
            parts.append("## 语音转写\n\(voiceText)")
            
            // 如果同时有用户输入和语音，添加提示
            if !userInput.isEmpty {
                parts.append("> 注意：语音转写可能存在偏差（如专业术语、人名等），请结合用户输入理解真实意图。")
            }
        }
        
        // 附件说明
        if !state.attachments.isEmpty {
            var attachmentParts: [String] = []
            var textBundleContents: [String] = []
            
            for attachment in state.attachments {
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
            
            parts.append("## 附件\n\(attachmentParts.joined(separator: ", "))")
            
            // 添加文本包内容
            if !textBundleContents.isEmpty {
                parts.append("## 代码/文档内容\n\(textBundleContents.joined(separator: "\n\n---\n\n"))")
            }
        }
        
        return parts.joined(separator: "\n\n")
    }
}

// MARK: - Quick Ask HUD Manager

/// Quick Ask HUD 管理器
@MainActor
final class QuickAskHUDManager {
    
    // MARK: - Constants
    
    private static let fixedWindowHeight: CGFloat = 300
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
    
    func hide() {
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
                NSApp.setActivationPolicy(.accessory)
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
