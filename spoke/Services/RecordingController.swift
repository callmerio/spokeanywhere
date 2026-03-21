import AppKit
import Combine
import Foundation
import os

@MainActor
struct RecordingControllerDependencies {
    let hudManager: FloatingHUDManager
    let contextService: ContextService
    let hotKeyService: HotKeyService
    let audioService: AudioRecorderService
    let inputService: InputService
    let settings: AppSettings
    let llmSettings: LLMSettings
    let llmPipeline: LLMPipeline
    let historyManager: HistoryManager
    let quickAskService: QuickAskService
    let screenOCR: ScreenOCRService
    let messagePanelManager: MessagePanelManager
    let liveCaptionWindowManager: LiveCaptionWindowManager
    let clipboardPipelineService: ClipboardPipelineService
    let copyToClipboard: (String) -> Void
    let openSettings: () -> Void
}

/// 录音控制器
/// 协调快捷键、HUD、上下文感知等服务
@MainActor
final class RecordingController {
    
    // MARK: - Constants
    
    /// 等待最终结果的最大时间（毫秒）
    private static let maxWaitForFinalResult = 2000
    /// 检查间隔（毫秒）
    private static let checkInterval = 100
    
    // MARK: - Singleton
    
    static let shared = RecordingController(
        dependencies: RecordingControllerDependencies(
            hudManager: .shared,
            contextService: .shared,
            hotKeyService: .shared,
            audioService: .shared,
            inputService: .shared,
            settings: .shared,
            llmSettings: .shared,
            llmPipeline: .shared,
            historyManager: .shared,
            quickAskService: .shared,
            screenOCR: .shared,
            messagePanelManager: .shared,
            liveCaptionWindowManager: .shared,
            clipboardPipelineService: .shared,
            copyToClipboard: { text in
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
            },
            openSettings: {
                if !NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil) {
                    assertionFailure("AppDelegate should handle openSettings via responder chain")
                }
            }
        )
    )
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "Recording")
    
    // MARK: - Dependencies
    
    private let dependencies: RecordingControllerDependencies
    
    // MARK: - Properties
    
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var lastTranscription: String = ""
    private let recordingCallbackSessionID: UUID

    private struct CapturedRecordingSession {
        let transcription: String
        let audioURL: URL?
        let appBundleId: String?
        let sourceApp: SourceAppInfo?
    }
    
    // MARK: - Init
    
    private init(dependencies: RecordingControllerDependencies) {
        self.dependencies = dependencies
        recordingCallbackSessionID = dependencies.audioService.createCallbackSession()
        setupAudioCallbacks()
        setupHUDCallbacks()
        setupQuickAskCallbacks()
        setupMessagePanelCallbacks()
    }
    
    private func setupHUDCallbacks() {
        // 用户点击"完成录音"按钮
        dependencies.hudManager.onComplete = makeControllerAction { controller in
            controller.completeRecordingSession()
        }
        
        // 用户点击"取消录音"按钮
        dependencies.hudManager.onCancel = makeControllerAction { controller in
            controller.cancelRecordingSession()
        }
    }
    
    private func setupQuickAskCallbacks() {
        // Quick Ask 开始
        dependencies.hotKeyService.onQuickAskStart = makeControllerAction { controller in
            controller.dependencies.quickAskService.startSession()
        }
        
        // Quick Ask 发送（再次按快捷键）
        dependencies.hotKeyService.onQuickAskSend = makeControllerAction { controller in
            controller.dependencies.quickAskService.sendViaShortcut()
        }
        
        // Cmd+逗号 打开设置
        dependencies.hotKeyService.onOpenSettings = makeDependenciesAction { dependencies in
            dependencies.openSettings()
        }
    }
    
    private func setupMessagePanelCallbacks() {
        // Message Panel 切换显示
        dependencies.hotKeyService.onMessagePanelToggle = makeDependenciesAction { dependencies in
            dependencies.messagePanelManager.toggle()
        }
        
        // Live Caption 切换显示
        dependencies.hotKeyService.onLiveCaptionToggle = makeDependenciesAction { dependencies in
            dependencies.liveCaptionWindowManager.toggle()
        }
        
        // Clipboard Pipeline 触发
        dependencies.hotKeyService.onClipboardPipelineTrigger = makeDependenciesAction { dependencies in
            dependencies.clipboardPipelineService.trigger()
        }
    }
    
    private func setupAudioCallbacks() {
        dependencies.audioService.updateCallbackSession(recordingCallbackSessionID) { [weak self] callbacks in
            callbacks.onAudioLevelUpdate = self?.makeControllerAction { controller, level in
                controller.dependencies.hudManager.updateAudioLevel(level)
            }

            callbacks.onPartialResult = self?.makeControllerAction { controller, result in
                // 保存完整文本
                controller.lastTranscription = result.text

                // HUD 始终显示完整文本（finalized + volatile）
                controller.dependencies.hudManager.updatePartialText(result.text)

                // 边说边打字模式：使用稳定性检测输入
                if controller.dependencies.settings.realtimeTypingEnabled {
                    // 基于前缀稳定性检测，更快地输入稳定内容
                    controller.dependencies.inputService.typeWithStabilityDetection(
                        finalizedText: result.finalizedText,
                        volatileText: result.volatileText
                    )
                }
            }

            callbacks.onFinalResult = self?.makeControllerAction { controller, text in
                controller.lastTranscription = text
            }

            callbacks.onError = { [weak self] error in
                self?.logger.error("❌ Audio error: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    // MARK: - Public API
    
    /// 启动录音控制器
    func start() {
        setupHotKeyCallbacks()
        dependencies.hotKeyService.register()
        
        logger.info("🎙️ RecordingController started")
    }
    
    /// 停止录音控制器
    func stop() {
        dependencies.hotKeyService.unregister()
        stopRecordingSession()
    }

#if DEBUG
    /// Debug-only：用于自动化脚本触发录音开关（绕过全局热键）
    func debugToggleRecording() {
        if dependencies.hotKeyService.isRecording {
            stopRecordingSession()
            logger.info("🧪 [DebugAutomation] recording toggled -> stop")
            return
        }

        dependencies.hotKeyService.isRecording = true
        startRecordingSession()
        if dependencies.hotKeyService.isRecording {
            logger.info("🧪 [DebugAutomation] recording toggled -> start")
        } else {
            logger.info("🧪 [DebugAutomation] recording start aborted")
        }
    }
#endif
    
    // MARK: - Private
    
    private func setupHotKeyCallbacks() {
        dependencies.hotKeyService.onRecordingStart = makeControllerAction { controller in
            controller.startRecordingSession()
        }
        
        dependencies.hotKeyService.onRecordingStop = makeControllerAction { controller in
            controller.stopRecordingSession()
        }
    }
    
    private func startRecordingSession() {
        let targetApp = dependencies.contextService.getCurrentTargetApp()
        
        // 显示 HUD（先显示"准备中"状态）
        dependencies.hudManager.show(targetApp: targetApp)
        
        // 记录开始时间
        recordingStartTime = Date()
        lastTranscription = ""
        
        // 重置输入服务（边说边打字）
        dependencies.inputService.reset()
        
        // 录音入口使用独立回调会话，避免与 Quick Ask 串线
        setupAudioCallbacks()
        dependencies.audioService.activateCallbackSession(recordingCallbackSessionID)
        
        // 🔍 预取 OCR（与录音并行，不阻塞）
        if dependencies.llmSettings.includeActiveApp {
            dependencies.screenOCR.prefetch()
        }
        
        // 启动计时器更新时长
        let updateDuration = makeControllerAction { controller in
            controller.updateRecordingDuration()
        }
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard self != nil else { return }
            updateDuration()
        }
        
        // 启动音频录制（立即开始，引擎后台准备）
        do {
            try dependencies.audioService.startRecording()
            logger.info("🔴 Recording started for: \(targetApp?.name ?? "Unknown", privacy: .public)")
        } catch {
            logger.error("❌ Failed to start recording: \(error, privacy: .public)")
            dependencies.hotKeyService.resetState()
            dependencies.hudManager.fail(with: "录音启动失败")
        }
    }
    
    /// 结束录音会话的公共逻辑
    private func finishRecordingSession(source: String) {
        // 捕获当前录音数据（新录音可能会覆盖）
        let capturedSession = captureCurrentSession()
        resetRecordingSessionState(clearTranscription: false)
        
        // 停止音频录制（正常结束，等待最终结果）
        _ = dependencies.audioService.stopRecording()
        
        // 边说边打字：刷新待输入的文本
        if dependencies.settings.realtimeTypingEnabled {
            dependencies.inputService.flushPendingText()
        }
        
        // 立即重置热键状态，允许新录音
        dependencies.hotKeyService.resetState()
        
        // 根据是否启用 LLM 选择状态
        if dependencies.llmPipeline.shouldProcess {
            dependencies.hudManager.startThinking()
        } else {
            dependencies.hudManager.startProcessing()
        }
        
        logger.info("⏹️ Recording \(source, privacy: .public)")
        
        // 后台处理转写结果（不阻塞新录音）
        processTranscription(
            transcription: capturedSession.transcription,
            audioURL: capturedSession.audioURL,
            appBundleId: capturedSession.appBundleId,
            sourceApp: capturedSession.sourceApp
        )
    }
    
    private func stopRecordingSession() {
        finishRecordingSession(source: "stopped")
    }
    
    /// 完成录音（用户点击"完成录音"按钮时调用）
    func completeRecordingSession() {
        finishRecordingSession(source: "completed by user")
    }
    
    /// 取消录音（用户点击"取消录音"按钮时调用）
    func cancelRecordingSession() {
        resetRecordingSessionState(clearTranscription: true)
        
        // 取消音频录制（丢弃结果）
        dependencies.audioService.cancelRecording()
        
        // 重置热键状态（完整重置，包括 isToggleSession 和 recordingStartTime）
        dependencies.hotKeyService.resetState()
        
        // 隐藏 HUD
        dependencies.hudManager.hide()
        
        logger.info("🚫 Recording cancelled by user")
    }
    
    private func updateRecordingDuration() {
        guard let startTime = recordingStartTime else { return }
        let duration = Date().timeIntervalSince(startTime)
        dependencies.hudManager.updateDuration(duration)
    }

    private func makeControllerAction(
        _ action: @escaping @MainActor (RecordingController) -> Void
    ) -> () -> Void {
        { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                action(self)
            }
        }
    }

    private func makeControllerAction<Value>(
        _ action: @escaping @MainActor (RecordingController, Value) -> Void
    ) -> (Value) -> Void {
        { [weak self] value in
            Task { @MainActor [weak self] in
                guard let self else { return }
                action(self, value)
            }
        }
    }

    private func makeDependenciesAction(
        _ action: @escaping @MainActor (RecordingControllerDependencies) -> Void
    ) -> () -> Void {
        let dependencies = self.dependencies
        return {
            Task { @MainActor in
                action(dependencies)
            }
        }
    }

    private func captureCurrentSession() -> CapturedRecordingSession {
        let targetApp = dependencies.contextService.getCurrentTargetApp()
        return CapturedRecordingSession(
            transcription: lastTranscription,
            audioURL: dependencies.audioService.tempAudioFileURL,
            appBundleId: targetApp?.bundleIdentifier,
            sourceApp: targetApp.map(SourceAppInfo.from)
        )
    }

    private func resetRecordingSessionState(clearTranscription: Bool) {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
        if clearTranscription {
            lastTranscription = ""
        }
    }

    private func withIdleRecordingState(_ action: (FloatingHUDManager) -> Void) {
        guard !dependencies.hotKeyService.isRecording else { return }
        action(dependencies.hudManager)
    }

    private func persistRecording(
        rawText: String,
        processedText: String?,
        audioURL: URL?,
        appBundleId: String?
    ) async {
        await dependencies.historyManager.saveRecording(
            rawText: rawText,
            processedText: processedText,
            tempAudioURL: audioURL,
            appBundleId: appBundleId
        )
    }
    
    // MARK: - Processing
    
    /// 后台处理转写结果（不阻塞新录音）
    /// - Parameters:
    ///   - transcription: 捕获的转录文本
    ///   - audioURL: 捕获的音频文件 URL
    ///   - appBundleId: 捕获的应用 Bundle ID
    ///   - sourceApp: 来源应用信息（用于 Pipeline 卡片显示）
    private func processTranscription(
        transcription: String,
        audioURL: URL?,
        appBundleId: String?,
        sourceApp: SourceAppInfo?
    ) {
        Task {
            let processStartTime = CFAbsoluteTimeGetCurrent()
            
            // 🚀 立即复制当前转录到剪贴板（用户可能急需）
            let immediateText = transcription
            if !immediateText.isEmpty {
                dependencies.copyToClipboard(immediateText)
                logger.info("📋 剪贴板(即时): \(immediateText.prefix(50), privacy: .public)...")
            }
            
            // 等待最终结果（最多等待 2 秒，新录音开始则立即中断）
            var waitTime = 0
            while waitTime < Self.maxWaitForFinalResult && !dependencies.hotKeyService.isRecording {
                try? await Task.sleep(for: .milliseconds(Self.checkInterval))
                waitTime += Self.checkInterval
                if !dependencies.audioService.isProcessing { break }
            }
            
            let waitElapsed = (CFAbsoluteTimeGetCurrent() - processStartTime) * 1000
            logger.info("⏱️ 等待完成: \(String(format: "%.0f", waitElapsed), privacy: .public)ms")
            
            // 使用捕获的文本，避免访问可能被新录音覆盖的 lastTranscription
            let transcribedText = transcription
            
            if transcribedText.isEmpty {
                // 仅在没有新录音时显示失败
                withIdleRecordingState { hudManager in
                    hudManager.fail(with: TranscriptionError.emptySpeech)
                }
                return
            }
            
            // 仅当文本有更新时再次复制（避免重复写入剪贴板）
            if transcribedText != immediateText {
                dependencies.copyToClipboard(transcribedText)
                logger.info("📋 剪贴板(最终): 文本已更新")
            }
            
            // 发送 ASR 结果到 Message Panel（带来源应用）
            dependencies.messagePanelManager.addASRResult(
                model: "Apple Speech",
                content: transcribedText,
                sourceApp: sourceApp
            )
            
            // 检查是否需要 LLM 处理
            guard dependencies.llmPipeline.shouldProcess else {
                let decision = RecordingTranscriptionDecision.passthrough(
                    rawText: transcribedText,
                    isStillRecording: dependencies.hotKeyService.isRecording
                )
                applyDecision(decision)
                
                // 保存到历史记录
                await persistRecording(
                    rawText: transcribedText,
                    processedText: decision.processedText,
                    audioURL: audioURL,
                    appBundleId: appBundleId
                )
                
                logger.info("✅ Transcription complete (no LLM): \(transcribedText, privacy: .public)")
                return
            }
            
            // 调用 LLM 精炼
            let result = await dependencies.llmPipeline.refine(transcribedText)
            let decision = RecordingTranscriptionDecision.make(
                rawText: transcribedText,
                refineResult: result,
                isStillRecording: dependencies.hotKeyService.isRecording
            )

            switch result {
            case .success(let refinedText):
                applyDecision(decision)
                dependencies.messagePanelManager.addLLMResult(
                    model: dependencies.llmPipeline.currentProviderName,
                    content: refinedText,
                    sourceApp: sourceApp
                )
                logger.info("✅ LLM refinement complete: \(refinedText, privacy: .public)")
                
            case .failure(let error):
                applyDecision(decision)
                // LLM 失败，保留原始文本
                logger.error("❌ LLM failed: \(error.localizedDescription, privacy: .public)")
                logger.info("⚠️ Fallback to transcribed text")
            }
            
            // 保存到历史记录
            await persistRecording(
                rawText: transcribedText,
                processedText: decision.processedText,
                audioURL: audioURL,
                appBundleId: appBundleId
            )
        }
    }

    private func applyDecision(_ decision: RecordingTranscriptionDecision) {
        dependencies.copyToClipboard(decision.clipboardText)

        if let hudCompletionText = decision.hudCompletionText {
            withIdleRecordingState { hudManager in
                hudManager.complete(with: hudCompletionText)
            }
        }

        if let hudFailure = decision.hudFailure {
            withIdleRecordingState { hudManager in
                hudManager.fail(with: hudFailure)
            }
        }
    }
}
