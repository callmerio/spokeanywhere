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
    
    // MARK: - Properties
    
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var lastTranscription: String = ""
    
    // MARK: - Init
    
    private init() {
        setupAudioCallbacks()
        setupHUDCallbacks()
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
    
    private func setupAudioCallbacks() {
        audioService.onAudioLevelUpdate = { [weak self] level in
            Task { @MainActor in
                self?.hudManager.updateAudioLevel(level)
            }
        }
        
        audioService.onPartialResult = { [weak self] text in
            Task { @MainActor in
                self?.lastTranscription = text
                self?.hudManager.updatePartialText(text)
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
        
        // 显示 HUD
        hudManager.show(targetApp: targetApp)
        
        // 记录开始时间
        recordingStartTime = Date()
        lastTranscription = ""
        
        // 启动计时器更新时长
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateRecordingDuration()
            }
        }
        
        // 启动真实的音频录制
        do {
            try audioService.startRecording()
            logger.info("🔴 Recording started for: \(targetApp?.name ?? "Unknown")")
        } catch {
            logger.error("❌ Failed to start recording: \(error)")
            hudManager.fail(with: "录音启动失败")
        }
    }
    
    private func stopRecordingSession() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
        
        // 停止音频录制（正常结束，等待最终结果）
        _ = audioService.stopRecording()
        
        // 切换到处理状态
        hudManager.startProcessing()
        
        logger.info("⏹️ Recording stopped, processing...")
        
        // 处理转写结果
        processTranscription()
    }
    
    /// 完成录音（用户点击"完成录音"按钮时调用）
    func completeRecordingSession() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
        
        // 停止音频录制（正常结束，等待最终结果）
        _ = audioService.stopRecording()
        
        // 重置热键状态
        hotKeyService.isRecording = false
        
        // 切换到处理状态
        hudManager.startProcessing()
        
        logger.info("⏹️ Recording completed by user button")
        
        // 处理转写结果
        processTranscription()
    }
    
    /// 取消录音（用户点击"取消录音"按钮时调用）
    func cancelRecordingSession() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
        lastTranscription = ""
        
        // 取消音频录制（丢弃结果）
        audioService.cancelRecording()
        
        // 重置热键状态
        hotKeyService.isRecording = false
        
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
    
    private func processTranscription() {
        Task {
            // 等待最终结果（最多等待 2 秒，每 100ms 检查一次）
            var waitTime = 0
            while waitTime < Self.maxWaitForFinalResult {
                try? await Task.sleep(for: .milliseconds(Self.checkInterval))
                waitTime += Self.checkInterval
                // 如果 recognitionTask 已完成，提前退出
                if audioService.recognitionTask == nil { break }
            }
            
            let text = lastTranscription
            
            if text.isEmpty {
                hudManager.fail(with: "未检测到语音")
                return
            }
            
            // TODO: 这里后续接入 AI 处理
            // let processedText = await aiPipeline.process(text)
            
            // 目前直接使用原始转写文本
            let finalText = text
            
            // 完成
            hudManager.complete(with: finalText)
            
            // 复制到剪贴板
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(finalText, forType: .string)
            
            // 清理临时文件
            audioService.cleanupTempFile()
            
            logger.info("✅ Transcription complete: \(finalText)")
        }
    }
}
