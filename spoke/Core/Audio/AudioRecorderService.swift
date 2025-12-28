import AVFoundation
import CoreAudio
import os
import Speech

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
    
    /// 复用的音频引擎（避免频繁创建销毁导致 CoreAudio -10877）
    private lazy var audioEngine: AVAudioEngine = AVAudioEngine()
    private var isEngineConfigured = false
    private var transcriptionProvider: TranscriptionProvider?
    
    /// 临时音频文件 URL
    private(set) var tempAudioFileURL: URL?
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
    
    /// 配置变更通知观察者
    private var configurationChangeObserver: NSObjectProtocol?
    
    /// 配置变更 debounce
    private var configurationChangeWorkItem: DispatchWorkItem?
    
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
        
        // 🔧 预热 AVAudioEngine，触发 CoreAudio 初始化
        // 避免首次录音时出现 -10877 错误
        warmupAudioEngine()
    }
    
    /// 预热音频引擎，在启动时触发 CoreAudio 初始化
    private func warmupAudioEngine() {
        // 访问 inputNode 会触发 CoreAudio 设备枚举和初始化
        // 这个过程可能产生 -10877，但在启动时触发比录音时更好
        _ = audioEngine.inputNode.outputFormat(forBus: 0)
        logger.info("🔥 Audio engine warmed up")
        
        // 注册配置变更通知 (设备热插拔、采样率变化等)
        setupConfigurationChangeObserver()
    }
    
    /// 注册音频配置变更通知
    private func setupConfigurationChangeObserver() {
        configurationChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleConfigurationChange()
            }
        }
        logger.info("🔔 Audio configuration change observer registered")
    }
    
    /// 处理音频配置变更 (设备切换/拔出)
    private func handleConfigurationChange() {
        // Debounce: 避免高频切换导致连续重启
        configurationChangeWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.logger.warning("⚠️ Audio configuration changed")
                
                guard self.isRecording else {
                    self.logger.info("ℹ️ Not recording, ignoring configuration change")
                    return
                }
                
                // 正在录音时，尝试恢复
                self.logger.info("🔄 Attempting to recover recording after configuration change...")
                
                do {
                    // 1. 停止引擎
                    self.resetAudioEngine()
                    
                    // 2. 重新配置并启动
                    try self.reconfigureAndRestartEngine()
                    
                    self.logger.info("✅ Recording recovered after configuration change")
                } catch {
                    self.logger.error("❌ Failed to recover recording: \(error.localizedDescription)")
                    self.onError?(error)
                }
            }
        }
        
        configurationChangeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    /// 重新配置并启动引擎 (配置变更后恢复)
    private func reconfigureAndRestartEngine() throws {
        // 尝试绑定用户选择的设备
        bindSelectedInputDevice()
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // 重新 installTap
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            try? self.audioFile?.write(from: buffer)
            self.processAudioLevel(buffer: buffer)
            
            if self.isEngineReady {
                try? self.transcriptionProvider?.process(buffer: buffer)
            }
        }
        isEngineConfigured = true
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    /// 绑定用户选择的输入设备
    private func bindSelectedInputDevice() {
        guard let deviceID = AudioDeviceManager.getSelectedAudioDeviceID() else {
            logger.info("ℹ️ No selected device or device not found, using system default")
            return
        }
        
        let inputNode = audioEngine.inputNode
        guard let audioUnit = inputNode.audioUnit else {
            logger.warning("⚠️ Could not get audioUnit from inputNode")
            return
        }
        
        var mutableDeviceID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &mutableDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        
        if status == noErr {
            logger.info("✅ Bound input device: \(deviceID)")
        } else {
            logger.warning("⚠️ Failed to bind input device (status: \(status)), using system default")
        }
    }
    
    // MARK: - Public API
    
    /// 请求麦克风和语音识别权限
    func requestPermissions() async -> Bool {
        await transcriptionManager.requestPermissions()
    }
    
    /// 开始录音
    func startRecording() throws {
        guard !isRecording else { return }
        
        // 🔧 停止并重置引擎状态（复用实例，避免 CoreAudio -10877）
        resetAudioEngine()
        
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
        
        // 创建临时文件用于保存音频
        tempAudioFileURL = createTempAudioFileURL()
        
        // 🎤 绑定用户选择的麦克风 (不随系统默认漂移)
        bindSelectedInputDevice()
        
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
        isEngineConfigured = true
        
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
                    
                    var successCount = 0
                    var failCount = 0
                    for buffer in bufferedAudio {
                        do {
                            try self.transcriptionProvider?.process(buffer: buffer)
                            successCount += 1
                        } catch {
                            failCount += 1
                            self.logger.warning("⚠️ Failed to process buffered chunk: \(error.localizedDescription)")
                        }
                    }
                    if failCount > 0 {
                        self.logger.warning("⚠️ Buffered chunks: \(successCount) success, \(failCount) failed")
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
                // 应用词典后处理
                let processedResult = TranscriptionPostProcessor.shared.process(result)
                
                switch processedResult.type {
                case .partial:
                    // 传递完整的 TranscriptionResult
                    self?.onPartialResult?(processedResult)
                case .final:
                    self?.onFinalResult?(processedResult.text)
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
        isRecording = false
        logger.info("⏹️ Recording stopped")
        
        // 🔧 停止引擎但保留实例（复用，避免 CoreAudio -10877）
        resetAudioEngine()
        
        // 关闭音频文件
        audioFile = nil
        
        // 通知 Provider 结束处理（异步执行，完成后更新状态）
        Task {
            let startTime = CFAbsoluteTimeGetCurrent()
            logger.info("⏳ Waiting for transcription finalization...")
            
            do {
                try await transcriptionProvider?.finishProcessing()
            } catch {
                logger.warning("⚠️ finishProcessing error: \(error.localizedDescription)")
            }
            
            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            logger.info("✅ Transcription finalized in \(String(format: "%.0f", elapsed))ms")
            
            await MainActor.run {
                self.isProcessing = false
            }
        }
        
        return tempAudioFileURL?.path
    }
    
    /// 取消录音（用户主动取消，丢弃结果）
    func cancelRecording() {
        // 即使不在录音状态，也要尝试取消可能残留的任务
        guard isRecording || transcriptionProvider != nil else { return }
        
        // 🔧 停止引擎但保留实例（复用，避免 CoreAudio -10877）
        resetAudioEngine()
        
        // 取消转录
        transcriptionProvider?.cancel()
        transcriptionProvider = nil
        
        // 关闭音频文件
        audioFile = nil
        
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
    
    /// 重置音频引擎状态（复用实例，避免频繁创建销毁导致 CoreAudio -10877）
    private func resetAudioEngine() {
        // 1. 停止引擎
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // 2. 移除 Tap（如果已配置）
        if isEngineConfigured {
            audioEngine.inputNode.removeTap(onBus: 0)
            isEngineConfigured = false
        }
        
        // 注意：不调用 reset() 和不置空引用，保持引擎实例复用
    }
    
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
