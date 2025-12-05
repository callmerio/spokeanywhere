import Foundation
import AppKit
import Combine
import os

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
    
    static let shared = RecordingController()
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "Recording")
    
    // MARK: - Dependencies
    
    private let hudManager = FloatingHUDManager.shared
    private let contextService = ContextService.shared
    private let hotKeyService = HotKeyService.shared
    private let audioService = AudioRecorderService.shared
    private let inputService = InputService.shared
    private let settings = AppSettings.shared
    private let llmPipeline = LLMPipeline.shared
    private let historyManager = HistoryManager.shared
    private let quickAskService = QuickAskService.shared
    private let screenOCR = ScreenOCRService.shared
    
    // MARK: - Properties
    
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var lastTranscription: String = ""
    
    // MARK: - Init
    
    private init() {
        setupAudioCallbacks()
        setupHUDCallbacks()
        setupQuickAskCallbacks()
        setupMessagePanelCallbacks()
    }
    
    private func setupHUDCallbacks() {
        // 用户点击"完成录音"按钮
        hudManager.onComplete = { [weak self] in
            Task { @MainActor in
                self?.completeRecordingSession()
            }
        }
        
        // 用户点击"取消录音"按钮
        hudManager.onCancel = { [weak self] in
            Task { @MainActor in
                self?.cancelRecordingSession()
            }
        }
    }
    
    private func setupQuickAskCallbacks() {
        // Quick Ask 开始
        hotKeyService.onQuickAskStart = { [weak self] in
            Task { @MainActor in
                self?.quickAskService.startSession()
            }
        }
        
        // Quick Ask 发送（再次按快捷键）
        hotKeyService.onQuickAskSend = { [weak self] in
            Task { @MainActor in
                self?.quickAskService.sendViaShortcut()
            }
        }
        
        // Cmd+逗号 打开设置
        hotKeyService.onOpenSettings = {
            guard let appDelegate = AppDelegate.shared else {
                assertionFailure("AppDelegate.shared should be set in applicationDidFinishLaunching")
                return
            }
            appDelegate.openSettings()
        }
    }
    
    private func setupMessagePanelCallbacks() {
        // Message Panel 切换显示
        hotKeyService.onMessagePanelToggle = {
            Task { @MainActor in
                MessagePanelManager.shared.toggle()
            }
        }
        
        // Live Caption 切换显示
        hotKeyService.onLiveCaptionToggle = {
            Task { @MainActor in
                LiveCaptionWindowManager.shared.toggle()
            }
        }
    }
    
    private func setupAudioCallbacks() {
        audioService.onAudioLevelUpdate = { [weak self] level in
            Task { @MainActor in
                self?.hudManager.updateAudioLevel(level)
            }
        }
        
        audioService.onPartialResult = { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                
                // 保存完整文本
                self.lastTranscription = result.text
                
                // HUD 始终显示完整文本（finalized + volatile）
                self.hudManager.updatePartialText(result.text)
                
                // 边说边打字模式：使用稳定性检测输入
                if self.settings.realtimeTypingEnabled {
                    // 基于前缀稳定性检测，更快地输入稳定内容
                    self.inputService.typeWithStabilityDetection(
                        finalizedText: result.finalizedText,
                        volatileText: result.volatileText
                    )
                }
            }
        }
        
        audioService.onFinalResult = { [weak self] text in
            Task { @MainActor in
                self?.lastTranscription = text
            }
        }
        
        audioService.onError = { [weak self] error in
            self?.logger.error("❌ Audio error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public API
    
    /// 启动录音控制器
    func start() {
        setupHotKeyCallbacks()
        hotKeyService.register()
        
        logger.info("🎙️ RecordingController started")
    }
    
    /// 停止录音控制器
    func stop() {
        hotKeyService.unregister()
        stopRecordingSession()
    }
    
    // MARK: - Private
    
    private func setupHotKeyCallbacks() {
        hotKeyService.onRecordingStart = { [weak self] in
            Task { @MainActor in
                self?.startRecordingSession()
            }
        }
        
        hotKeyService.onRecordingStop = { [weak self] in
            Task { @MainActor in
                self?.stopRecordingSession()
            }
        }
    }
    
    private func startRecordingSession() {
        let targetApp = contextService.getCurrentTargetApp()
        
        // 显示 HUD（先显示"准备中"状态）
        hudManager.show(targetApp: targetApp)
        
        // 记录开始时间
        recordingStartTime = Date()
        lastTranscription = ""
        
        // 重置输入服务（边说边打字）
        inputService.reset()
        
        // ⚠️ 重新设置音频回调（Quick Ask 可能覆盖了）
        setupAudioCallbacks()
        
        // 🔍 预取 OCR（与录音并行，不阻塞）
        if LLMSettings.shared.includeActiveApp {
            screenOCR.prefetch()
        }
        
        // 启动计时器更新时长
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateRecordingDuration()
            }
        }
        
        // 启动音频录制（立即开始，引擎后台准备）
        do {
            try audioService.startRecording()
            logger.info("🔴 Recording started for: \(targetApp?.name ?? "Unknown")")
        } catch {
            logger.error("❌ Failed to start recording: \(error)")
            hudManager.fail(with: "录音启动失败")
        }
    }
    
    /// 结束录音会话的公共逻辑
    private func finishRecordingSession(source: String) {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
        
        // 捕获当前录音数据（新录音可能会覆盖）
        let capturedTranscription = lastTranscription
        let capturedAudioURL = audioService.tempAudioFileURL
        let capturedAppBundleId = contextService.getCurrentTargetApp()?.bundleIdentifier
        
        // 停止音频录制（正常结束，等待最终结果）
        _ = audioService.stopRecording()
        
        // 边说边打字：刷新待输入的文本
        if settings.realtimeTypingEnabled {
            inputService.flushPendingText()
        }
        
        // 立即重置热键状态，允许新录音
        hotKeyService.resetState()
        
        // 根据是否启用 LLM 选择状态
        if llmPipeline.shouldProcess {
            hudManager.startThinking()
        } else {
            hudManager.startProcessing()
        }
        
        logger.info("⏹️ Recording \(source)")
        
        // 后台处理转写结果（不阻塞新录音）
        processTranscription(
            transcription: capturedTranscription,
            audioURL: capturedAudioURL,
            appBundleId: capturedAppBundleId
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
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
        lastTranscription = ""
        
        // 取消音频录制（丢弃结果）
        audioService.cancelRecording()
        
        // 重置热键状态（完整重置，包括 isToggleSession 和 recordingStartTime）
        hotKeyService.resetState()
        
        // 隐藏 HUD
        hudManager.hide()
        
        logger.info("🚫 Recording cancelled by user")
    }
    
    private func updateRecordingDuration() {
        guard let startTime = recordingStartTime else { return }
        let duration = Date().timeIntervalSince(startTime)
        hudManager.updateDuration(duration)
    }
    
    // MARK: - Processing
    
    /// 后台处理转写结果（不阻塞新录音）
    /// - Parameters:
    ///   - transcription: 捕获的转录文本
    ///   - audioURL: 捕获的音频文件 URL
    ///   - appBundleId: 捕获的应用 Bundle ID
    private func processTranscription(
        transcription: String,
        audioURL: URL?,
        appBundleId: String?
    ) {
        Task {
            let processStartTime = CFAbsoluteTimeGetCurrent()
            
            // 🚀 立即复制当前转录到剪贴板（用户可能急需）
            let immediateText = transcription
            if !immediateText.isEmpty {
                copyToClipboard(immediateText)
                logger.info("📋 剪贴板(即时): \(immediateText.prefix(50))...")
            }
            
            // 等待最终结果（最多等待 2 秒，新录音开始则立即中断）
            var waitTime = 0
            while waitTime < Self.maxWaitForFinalResult && !hotKeyService.isRecording {
                try? await Task.sleep(for: .milliseconds(Self.checkInterval))
                waitTime += Self.checkInterval
                if !audioService.isProcessing { break }
            }
            
            let waitElapsed = (CFAbsoluteTimeGetCurrent() - processStartTime) * 1000
            logger.info("⏱️ 等待完成: \(String(format: "%.0f", waitElapsed))ms")
            
            // 使用捕获的文本，避免访问可能被新录音覆盖的 lastTranscription
            let transcribedText = transcription
            
            if transcribedText.isEmpty {
                // 仅在没有新录音时显示失败
                if !hotKeyService.isRecording {
                    hudManager.fail(with: "未检测到语音")
                }
                return
            }
            
            // 仅当文本有更新时再次复制（避免重复写入剪贴板）
            if transcribedText != immediateText {
                copyToClipboard(transcribedText)
                logger.info("📋 剪贴板(最终): 文本已更新")
            }
            
            // 发送 ASR 结果到 Message Panel
            MessagePanelManager.shared.addASRResult(
                model: "Apple Speech",
                content: transcribedText
            )
            
            // 检查是否需要 LLM 处理
            guard llmPipeline.shouldProcess else {
                // 不需要 LLM，仅在没有新录音时更新 HUD
                if !hotKeyService.isRecording {
                    hudManager.complete(with: transcribedText)
                }
                
                // 保存到历史记录
                await historyManager.saveRecording(
                    rawText: transcribedText,
                    processedText: nil,
                    tempAudioURL: audioURL,
                    appBundleId: appBundleId
                )
                
                logger.info("✅ Transcription complete (no LLM): \(transcribedText)")
                return
            }
            
            // 调用 LLM 精炼
            let result = await llmPipeline.refine(transcribedText)
            
            var processedText: String?
            
            switch result {
            case .success(let refinedText):
                // 写入剪贴板（精炼后文本）
                copyToClipboard(refinedText)
                logger.info("📋 Clipboard: refined text")
                
                // 发送 LLM 结果到 Message Panel
                MessagePanelManager.shared.addLLMResult(
                    model: llmPipeline.currentProviderName,
                    content: refinedText
                )
                
                // 仅在没有新录音时更新 HUD
                if !hotKeyService.isRecording {
                    hudManager.complete(with: refinedText)
                }
                processedText = refinedText
                logger.info("✅ LLM refinement complete: \(refinedText)")
                
            case .failure(let error):
                // LLM 失败，保留原始文本
                logger.error("❌ LLM failed: \(error.localizedDescription)")
                if !hotKeyService.isRecording {
                    hudManager.complete(with: transcribedText)
                }
                logger.info("⚠️ Fallback to transcribed text")
            }
            
            // 保存到历史记录
            await historyManager.saveRecording(
                rawText: transcribedText,
                processedText: processedText,
                tempAudioURL: audioURL,
                appBundleId: appBundleId
            )
        }
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
