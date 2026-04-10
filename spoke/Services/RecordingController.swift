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
    
    static let shared = RecordingController(dependencies: .makeLive())
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "Recording")
    
    // MARK: - Dependencies
    
    private let dependencies: RecordingControllerDependencies
    
    // MARK: - Properties
    
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var lastTranscription: String = ""
    private var recordingCallbackSessionID: UUID
    
    // MARK: - Init
    
    private init(dependencies: RecordingControllerDependencies) {
        self.dependencies = dependencies
        recordingCallbackSessionID = dependencies.audioService.createCallbackSession()
        wireRecordingHUDCallbacks(
            hudManager: dependencies.hudManager,
            onComplete: makeControllerAction { controller in
                controller.completeRecordingSession()
            },
            onCancel: makeControllerAction { controller in
                controller.cancelRecordingSession()
            }
        )
        wireRecordingFeatureHotKeyCallbacks(
            hotKeyService: dependencies.hotKeyService,
            onQuickAskStart: makeControllerAction { controller in
                controller.dependencies.quickAskService.startSession()
            },
            onQuickAskSend: makeControllerAction { controller in
                controller.dependencies.quickAskService.sendViaShortcut()
            },
            onOpenSettings: makeDependenciesAction { dependencies in
                dependencies.openSettings()
            },
            onMessagePanelToggle: makeDependenciesAction { dependencies in
                dependencies.messagePanelManager.toggle()
            },
            onLiveCaptionToggle: makeDependenciesAction { dependencies in
                dependencies.liveCaptionWindowManager.toggle()
            },
            onClipboardPipelineTrigger: makeDependenciesAction { dependencies in
                dependencies.clipboardPipelineService.trigger()
            }
        )
        configureAudioCallbacks()
    }
    
    // MARK: - Public API
    
    /// 启动录音控制器
    func start() {
        wireRecordingCaptureHotKeyCallbacks(
            hotKeyService: dependencies.hotKeyService,
            onRecordingStart: makeControllerAction { controller in
                controller.startRecordingSession()
            },
            onRecordingStop: makeControllerAction { controller in
                controller.stopRecordingSession()
            }
        )
        dependencies.hotKeyService.register()
        
        logger.info("🎙️ RecordingController started")
    }
    
    /// 停止录音控制器
    func stop() {
        dependencies.hotKeyService.unregister()
        clearRecordingCaptureHotKeyCallbacks(hotKeyService: dependencies.hotKeyService)
        clearRecordingFeatureHotKeyCallbacks(hotKeyService: dependencies.hotKeyService)
        clearRecordingHUDCallbacks(hudManager: dependencies.hudManager)
        stopRecordingSession()
        teardownRecordingCallbackSession()
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
        configureAudioCallbacks()
        dependencies.audioService.activateCallbackSession(recordingCallbackSessionID)
        
        // 🔍 预取 OCR（与录音并行，不阻塞）
        if dependencies.llmSettings.includeActiveApp {
            dependencies.screenOCR.prefetch()
        }
        
        // 启动计时器更新时长
        recordingTimer = makeRecordingDurationTimer(owner: self) { controller in
            controller.updateRecordingDuration()
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
            runRecordingControllerOnMain(self, action)
        }
    }

    private func makeControllerAction<Value>(
        _ action: @escaping @MainActor (RecordingController, Value) -> Void
    ) -> (Value) -> Void {
        { [weak self] value in
            runRecordingControllerOnMain(self) { controller in
                action(controller, value)
            }
        }
    }

    private func makeDependenciesAction(
        _ action: @escaping @MainActor (RecordingControllerDependencies) -> Void
    ) -> () -> Void {
        let dependencies = self.dependencies
        return {
            runRecordingControllerDependenciesOnMain(dependencies, action)
        }
    }

    private func configureAudioCallbacks() {
        wireRecordingAudioCallbacks(
            audioService: dependencies.audioService,
            sessionID: recordingCallbackSessionID,
            onAudioLevelUpdate: makeControllerAction { controller, level in
                controller.dependencies.hudManager.updateAudioLevel(level)
            },
            onPartialResult: makeControllerAction { controller, result in
                controller.lastTranscription = result.text
                controller.dependencies.hudManager.updatePartialText(result.text)
                if controller.dependencies.settings.realtimeTypingEnabled {
                    controller.dependencies.inputService.typeWithStabilityDetection(
                        finalizedText: result.finalizedText,
                        volatileText: result.volatileText
                    )
                }
            },
            onFinalResult: makeControllerAction { controller, text in
                controller.lastTranscription = text
            },
            onError: { [weak self] error in
                self?.logger.error("❌ Audio error: \(error.localizedDescription, privacy: .public)")
            }
        )
    }

    private func teardownRecordingCallbackSession() {
        dependencies.audioService.removeCallbackSession(recordingCallbackSessionID)
        recordingCallbackSessionID = dependencies.audioService.createCallbackSession()
        configureAudioCallbacks()
    }

    private func captureCurrentSession() -> RecordingCapturedSession {
        let targetApp = dependencies.contextService.getCurrentTargetApp()
        return RecordingSessionContextAssembler.capture(
            transcription: lastTranscription,
            audioURL: dependencies.audioService.tempAudioFileURL,
            targetApp: targetApp
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
        runRecordingControllerAsync(self) { controller in
            let processStartTime = CFAbsoluteTimeGetCurrent()
            
            // 🚀 立即复制当前转录到剪贴板（用户可能急需）
            let immediateText = transcription
            controller.copyImmediateTranscriptionIfNeeded(immediateText)
            
            // 等待最终结果（最多等待 2 秒，新录音开始则立即中断）
            await controller.waitForTranscriptionPipeline(processStartTime: processStartTime)
            
            // 使用捕获的文本，避免访问可能被新录音覆盖的 lastTranscription
            let transcribedText = transcription
            
            if transcribedText.isEmpty {
                controller.handleEmptyTranscription()
                return
            }
            
            // 仅当文本有更新时再次复制（避免重复写入剪贴板）
            controller.refreshClipboardIfNeeded(finalText: transcribedText, immediateText: immediateText)
            
            // 发送 ASR 结果到 Message Panel（带来源应用）
            controller.publishASRResult(transcribedText, sourceApp: sourceApp)
            
            // 检查是否需要 LLM 处理
            guard controller.dependencies.llmPipeline.shouldProcess else {
                await controller.handlePassthroughTranscription(
                    transcribedText,
                    audioURL: audioURL,
                    appBundleId: appBundleId
                )
                controller.logger.info("✅ Transcription complete (no LLM): \(transcribedText, privacy: .public)")
                return
            }
            
            // 调用 LLM 精炼
            await controller.handleLLMRefinement(
                transcribedText,
                audioURL: audioURL,
                appBundleId: appBundleId,
                sourceApp: sourceApp
            )
        }
    }

    private func copyImmediateTranscriptionIfNeeded(_ text: String) {
        guard !text.isEmpty else { return }
        dependencies.copyToClipboard(text)
        logger.info("📋 剪贴板(即时): \(text.prefix(50), privacy: .public)...")
    }

    private func waitForTranscriptionPipeline(processStartTime: CFAbsoluteTime) async {
        var waitTime = 0
        while waitTime < Self.maxWaitForFinalResult && !dependencies.hotKeyService.isRecording {
            try? await Task.sleep(for: .milliseconds(Self.checkInterval))
            waitTime += Self.checkInterval
            if !dependencies.audioService.isProcessing { break }
        }

        let waitElapsed = (CFAbsoluteTimeGetCurrent() - processStartTime) * 1000
        logger.info("⏱️ 等待完成: \(String(format: "%.0f", waitElapsed), privacy: .public)ms")
    }

    private func handleEmptyTranscription() {
        withIdleRecordingState { hudManager in
            hudManager.fail(with: TranscriptionError.emptySpeech)
        }
    }

    private func refreshClipboardIfNeeded(finalText: String, immediateText: String) {
        guard finalText != immediateText else { return }
        dependencies.copyToClipboard(finalText)
        logger.info("📋 剪贴板(最终): 文本已更新")
    }

    private func publishASRResult(_ text: String, sourceApp: SourceAppInfo?) {
        dependencies.messagePanelManager.addASRResult(
            model: "Apple Speech",
            content: text,
            sourceApp: sourceApp
        )
    }

    private func publishLLMResult(_ text: String, sourceApp: SourceAppInfo?) {
        dependencies.messagePanelManager.addLLMResult(
            model: dependencies.llmPipeline.currentProviderName,
            content: text,
            sourceApp: sourceApp
        )
    }

    private func makePassthroughDecision(for text: String) -> RecordingTranscriptionDecision {
        RecordingTranscriptionDecision.passthrough(
            rawText: text,
            isStillRecording: dependencies.hotKeyService.isRecording
        )
    }

    private func makeRefinementDecision(
        rawText: String,
        refineResult: Result<String, LLMError>
    ) -> RecordingTranscriptionDecision {
        RecordingTranscriptionDecision.make(
            rawText: rawText,
            refineResult: refineResult,
            isStillRecording: dependencies.hotKeyService.isRecording
        )
    }

    private func persistDecision(
        rawText: String,
        decision: RecordingTranscriptionDecision,
        audioURL: URL?,
        appBundleId: String?
    ) async {
        await persistRecording(
            rawText: rawText,
            processedText: decision.processedText,
            audioURL: audioURL,
            appBundleId: appBundleId
        )
    }

    private func handlePassthroughTranscription(
        _ transcribedText: String,
        audioURL: URL?,
        appBundleId: String?
    ) async {
        let decision = makePassthroughDecision(for: transcribedText)
        applyDecision(decision)
        await persistDecision(
            rawText: transcribedText,
            decision: decision,
            audioURL: audioURL,
            appBundleId: appBundleId
        )
    }

    private func handleLLMRefinement(
        _ transcribedText: String,
        audioURL: URL?,
        appBundleId: String?,
        sourceApp: SourceAppInfo?
    ) async {
        let result = await dependencies.llmPipeline.refine(transcribedText)
        let decision = makeRefinementDecision(rawText: transcribedText, refineResult: result)

        switch result {
        case .success(let refinedText):
            applyDecision(decision)
            publishLLMResult(refinedText, sourceApp: sourceApp)
            logger.info("✅ LLM refinement complete: \(refinedText, privacy: .public)")

        case .failure(let error):
            applyDecision(decision)
            logger.error("❌ LLM failed: \(error.localizedDescription, privacy: .public)")
            logger.info("⚠️ Fallback to transcribed text")
        }

        await persistDecision(
            rawText: transcribedText,
            decision: decision,
            audioURL: audioURL,
            appBundleId: appBundleId
        )
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
