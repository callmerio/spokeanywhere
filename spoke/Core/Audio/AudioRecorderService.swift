import AVFoundation
import Speech
import os

/// 音频录制服务
/// 负责麦克风录音、流式写入磁盘、实时转写
@MainActor
final class AudioRecorderService: NSObject {
    
    // MARK: - Constants
    
    /// SFSpeechRecognizer 取消错误码
    private static let speechRecognizerCancelledErrorCode = 216
    
    // MARK: - Singleton
    
    static let shared = AudioRecorderService()
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "Audio")
    
    // MARK: - Properties
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    /// 当前识别任务（外部可读取以检查完成状态）
    private(set) var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    
    /// 临时音频文件 URL
    private var tempAudioFileURL: URL?
    private var audioFile: AVAudioFile?
    
    /// 是否正在录音
    private(set) var isRecording = false
    
    /// 回调
    var onAudioLevelUpdate: ((Float) -> Void)?
    var onPartialResult: ((String) -> Void)?
    var onFinalResult: ((String) -> Void)?
    var onError: ((Error) -> Void)?
    
    // MARK: - Init
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public API
    
    /// 请求麦克风和语音识别权限
    func requestPermissions() async -> Bool {
        // 麦克风权限
        let micStatus = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
        
        guard micStatus else {
            print("⚠️ Microphone permission denied")
            return false
        }
        
        // 语音识别权限
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        
        guard speechStatus else {
            print("⚠️ Speech recognition permission denied")
            return false
        }
        
        print("✅ All audio permissions granted")
        return true
    }
    
    /// 开始录音
    func startRecording() throws {
        guard !isRecording else { return }
        
        // 确保有可用的语音识别器
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw AudioRecorderError.recognizerNotAvailable
        }
        
        // 创建音频引擎
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw AudioRecorderError.engineCreationFailed
        }
        
        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            throw AudioRecorderError.requestCreationFailed
        }
        
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        // 使用 dictation 模式，减少"智能修正"，保留更多原始表达
        request.taskHint = .dictation
        
        // 创建临时文件用于保存音频
        tempAudioFileURL = createTempAudioFileURL()
        
        // 获取输入节点
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // 创建音频文件（用于崩溃恢复）
        if let url = tempAudioFileURL {
            audioFile = try? AVAudioFile(forWriting: url, settings: recordingFormat.settings)
        }
        
        // 安装 Tap 节点
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            // 发送到语音识别
            self?.recognitionRequest?.append(buffer)
            
            // 写入磁盘（崩溃恢复）
            try? self?.audioFile?.write(from: buffer)
            
            // 计算音频电平
            self?.processAudioLevel(buffer: buffer)
        }
        
        // 开始识别任务
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    
                    if result.isFinal {
                        self?.onFinalResult?(text)
                        // 最终结果后清理 task
                        self?.recognitionTask = nil
                    } else {
                        self?.onPartialResult?(text)
                    }
                }
                
                if let error = error {
                    // 只有非取消错误才报告（用户主动取消不算错误）
                    let nsError = error as NSError
                    if nsError.code != Self.speechRecognizerCancelledErrorCode {
                        self?.onError?(error)
                    }
                    self?.recognitionTask = nil
                }
            }
        }
        
        // 启动引擎
        audioEngine.prepare()
        try audioEngine.start()
        
        isRecording = true
        logger.info("🎙️ Recording started")
    }
    
    /// 停止录音（正常结束，等待最终识别结果）
    func stopRecording() -> String? {
        guard isRecording else { return nil }
        
        // 停止音频引擎
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        // 结束识别请求（不要 cancel，让它自然完成）
        recognitionRequest?.endAudio()
        // 注意：不调用 recognitionTask?.cancel()，等待最终结果
        
        // 关闭音频文件
        audioFile = nil
        
        // 清理引擎（但保留 recognitionTask 等待完成）
        recognitionRequest = nil
        audioEngine = nil
        
        isRecording = false
        logger.info("⏹️ Recording stopped")
        
        return tempAudioFileURL?.path
    }
    
    /// 取消录音（用户主动取消，丢弃结果）
    func cancelRecording() {
        // 即使不在录音状态，也要尝试取消可能残留的任务
        guard isRecording || recognitionTask != nil else { return }
        
        // 停止音频引擎
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        // 取消识别任务
        recognitionTask?.cancel()
        recognitionRequest?.endAudio()
        
        // 关闭音频文件
        audioFile = nil
        
        // 清理
        recognitionRequest = nil
        recognitionTask = nil
        audioEngine = nil
        
        isRecording = false
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
