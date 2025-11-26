import AVFoundation
import Speech
import os

/// 音频录制服务
/// 负责麦克风录音、流式写入磁盘、实时转写
/// 使用 TranscriptionManager 自动选择最佳转录引擎
@MainActor
final class AudioRecorderService: NSObject {
    
    // MARK: - Singleton
    
    static let shared = AudioRecorderService()
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "Audio")
    
    // MARK: - Dependencies
    
    private let transcriptionManager = TranscriptionManager.shared
    
    // MARK: - Properties
    
    private var audioEngine: AVAudioEngine?
    private var transcriptionProvider: TranscriptionProvider?
    
    /// 临时音频文件 URL
    private var tempAudioFileURL: URL?
    private var audioFile: AVAudioFile?
    
    /// 是否正在录音
    private(set) var isRecording = false
    
    /// 是否正在处理中（等待最终结果）
    private(set) var isProcessing = false
    
    /// 引擎是否已准备好
    private var isEngineReady = false
    
    /// 音频缓冲区（引擎准备好之前暂存）
    private var audioBuffer: [AVAudioPCMBuffer] = []
    private let bufferLock = NSLock()
    
    /// 回调
    var onAudioLevelUpdate: ((Float) -> Void)?
    var onPartialResult: ((TranscriptionResult) -> Void)?  // 传递完整结果，包含 finalized/volatile 分离
    var onFinalResult: ((String) -> Void)?
    var onError: ((Error) -> Void)?
    
    /// 当前使用的引擎类型（用于 UI 展示）
    var currentEngineType: TranscriptionEngineType? {
        transcriptionManager.currentEngineType
    }
    
    // MARK: - Init
    
    private override init() {
        super.init()
        
        // 打印调试信息
        transcriptionManager.printDebugInfo()
    }
    
    // MARK: - Public API
    
    /// 请求麦克风和语音识别权限
    func requestPermissions() async -> Bool {
        await transcriptionManager.requestPermissions()
    }
    
    /// 开始录音
    func startRecording() throws {
        guard !isRecording else { return }
        
        // 重置状态
        isEngineReady = false
        bufferLock.lock()
        audioBuffer.removeAll()
        bufferLock.unlock()
        
        // 创建最佳转录引擎
        let provider = transcriptionManager.createBestProvider()
        transcriptionProvider = provider
        
        // 设置回调
        setupProviderCallbacks(provider)
        
        // 确保引擎可用
        guard provider.isAvailable else {
            throw AudioRecorderError.recognizerNotAvailable
        }
        
        // 创建音频引擎
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw AudioRecorderError.engineCreationFailed
        }
        
        // 创建临时文件用于保存音频
        tempAudioFileURL = createTempAudioFileURL()
        
        // 获取输入节点
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // 创建音频文件（用于崩溃恢复）
        if let url = tempAudioFileURL {
            audioFile = try? AVAudioFile(forWriting: url, settings: recordingFormat.settings)
        }
        
        // 安装 Tap 节点 - 立即开始录音
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            // 写入磁盘（崩溃恢复）
            try? self.audioFile?.write(from: buffer)
            
            // 计算音频电平
            self.processAudioLevel(buffer: buffer)
            
            // 根据引擎状态决定发送还是缓存
            if self.isEngineReady {
                // 引擎已准备好，直接发送
                try? self.transcriptionProvider?.process(buffer: buffer)
            } else {
                // 引擎未准备好，缓存音频
                self.bufferLock.lock()
                self.audioBuffer.append(buffer)
                self.bufferLock.unlock()
            }
        }
        
        // 启动音频引擎（立即开始录音）
        audioEngine.prepare()
        try audioEngine.start()
        
        isRecording = true
        logger.info("🎙️ Recording started (engine preparing in background)")
        
        // 异步准备转录引擎
        Task { [weak self] in
            guard let self = self else { return }
            
            do {
                logger.info("⏳ Preparing transcription engine...")
                try await provider.prepare()
                
                await MainActor.run {
                    // 发送缓存的音频
                    self.bufferLock.lock()
                    let bufferedAudio = self.audioBuffer
                    self.audioBuffer.removeAll()
                    self.bufferLock.unlock()
                    
                    self.logger.info("✅ Engine ready, sending \(bufferedAudio.count) buffered chunks")
                    
                    for buffer in bufferedAudio {
                        try? self.transcriptionProvider?.process(buffer: buffer)
                    }
                    
                    // 标记引擎已准备好
                    self.isEngineReady = true
                }
            } catch {
                await MainActor.run {
                    self.logger.error("❌ Engine prepare failed: \(error)")
                    self.onError?(error)
                }
            }
        }
    }
    
    /// 设置 Provider 回调
    private func setupProviderCallbacks(_ provider: TranscriptionProvider) {
        provider.onResult = { [weak self] result in
            Task { @MainActor in
                switch result.type {
                case .partial:
                    // 传递完整的 TranscriptionResult
                    self?.onPartialResult?(result)
                case .final:
                    self?.onFinalResult?(result.text)
                    self?.isProcessing = false
                }
            }
        }
        
        provider.onError = { [weak self] error in
            Task { @MainActor in
                self?.onError?(error)
                self?.isProcessing = false
            }
        }
    }
    
    /// 停止录音（正常结束，等待最终识别结果）
    func stopRecording() -> String? {
        guard isRecording else { return nil }
        
        isProcessing = true
        
        // 停止音频引擎
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        // 通知 Provider 结束处理
        Task {
            try? await transcriptionProvider?.finishProcessing()
        }
        
        // 关闭音频文件
        audioFile = nil
        audioEngine = nil
        
        isRecording = false
        logger.info("⏹️ Recording stopped")
        
        return tempAudioFileURL?.path
    }
    
    /// 取消录音（用户主动取消，丢弃结果）
    func cancelRecording() {
        // 即使不在录音状态，也要尝试取消可能残留的任务
        guard isRecording || transcriptionProvider != nil else { return }
        
        // 停止音频引擎
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        // 取消转录
        transcriptionProvider?.cancel()
        
        // 关闭音频文件
        audioFile = nil
        
        // 清理
        transcriptionProvider = nil
        audioEngine = nil
        
        isRecording = false
        isProcessing = false
        logger.info("🚫 Recording cancelled")
        
        // 清理临时文件
        cleanupTempFile()
    }
    
    /// 清理临时文件
    func cleanupTempFile() {
        if let url = tempAudioFileURL {
            try? FileManager.default.removeItem(at: url)
            tempAudioFileURL = nil
        }
    }
    
    // MARK: - Private
    
    private func createTempAudioFileURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "spoke_\(UUID().uuidString).caf"
        return tempDir.appendingPathComponent(fileName)
    }
    
    private func processAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        // 使用 RMS (均方根) 计算，更能反映听感响度
        var sumSquares: Float = 0
        
        // 降采样以提高性能 (每 4 个采样点取一个)
        let strideStep = 4
        for i in stride(from: 0, to: frameLength, by: strideStep) {
            let sample = channelData[i]
            sumSquares += sample * sample
        }
        
        let rms = sqrt(sumSquares / Float(frameLength / strideStep))
        
        // 非线性放大：
        // 1. 基础放大倍数 5.0
        // 2. 加上一个非线性分量 sqrt(rms) * 2.0 提升小音量表现
        // 3. 限制在 0.01 - 1.0 之间 (保留极小值避免完全静止)
        var level = (rms * 5.0) + (sqrt(rms) * 2.0)
        
        // 添加一点随机抖动，让波形在说话时更生动
        if level > 0.1 {
            level += Float.random(in: -0.05...0.05)
        }
        
        let finalLevel = min(max(level, 0.02), 1.0)
        
        Task { @MainActor in
            onAudioLevelUpdate?(finalLevel)
        }
    }
}

// MARK: - Errors

enum AudioRecorderError: LocalizedError {
    case recognizerNotAvailable
    case engineCreationFailed
    case requestCreationFailed
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .recognizerNotAvailable:
            return "语音识别器不可用"
        case .engineCreationFailed:
            return "音频引擎创建失败"
        case .requestCreationFailed:
            return "识别请求创建失败"
        case .permissionDenied:
            return "权限被拒绝"
        }
    }
}
