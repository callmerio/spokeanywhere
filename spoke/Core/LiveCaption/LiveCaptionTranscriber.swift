import Foundation
import Speech
import AVFoundation
import OSLog

// MARK: - Live Caption Transcriber

/// 实时字幕转录器
/// 将音频流转换为文字
@MainActor
final class LiveCaptionTranscriber: ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "LiveCaptionTranscriber")
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    /// 当前语言
    /// 注意: zh-CN 能识别混入的英文，反之效果较差
    @Published var locale: Locale = Locale(identifier: "en-US")
    
    /// 上下文词汇（提高特定词汇识别率）
    var contextualStrings: [String] = []
    
    /// 是否正在转录
    @Published private(set) var isTranscribing: Bool = false
    
    /// 转录结果回调
    var onTranscription: ((TranscriptionSegment) -> Void)?
    
    /// 错误回调
    var onError: ((Error) -> Void)?
    
    // MARK: - Init
    
    init() {
        setupRecognizer()
    }
    
    // MARK: - Public API
    
    /// 开始转录
    func startTranscribing() throws {
        guard !isTranscribing else { return }
        
        // 重新创建识别器（确保使用最新的 locale）
        setupRecognizer()
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw TranscriberError.recognizerNotAvailable
        }
        
        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let request = recognitionRequest else {
            throw TranscriberError.requestCreationFailed
        }
        
        // 配置请求
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true  // 本地识别，响应更快
        
        // 添加上下文词汇提高识别率
        if !contextualStrings.isEmpty {
            request.contextualStrings = contextualStrings
            logger.debug("📚 Added \(self.contextualStrings.count) contextual strings")
        }
        
        if #available(macOS 13.0, *) {
            request.addsPunctuation = true
        }
        
        // 启动识别任务
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                self?.handleRecognitionResult(result, error: error)
            }
        }
        
        isTranscribing = true
        logger.info("🎤 Transcription started with locale: \(self.locale.identifier)")
    }
    
    /// 停止转录
    func stopTranscribing() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isTranscribing = false
        
        logger.info("🛑 Transcription stopped")
    }
    
    /// 处理音频缓冲区
    func processAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isTranscribing, let request = recognitionRequest else { return }
        
        // 将 CMSampleBuffer 转换为 AVAudioPCMBuffer
        guard let pcmBuffer = convertToPCMBuffer(sampleBuffer) else {
            return
        }
        
        request.append(pcmBuffer)
    }
    
    /// 更新识别语言
    func updateLocale(_ newLocale: Locale) {
        let wasTranscribing = isTranscribing
        
        if wasTranscribing {
            stopTranscribing()
        }
        
        locale = newLocale
        setupRecognizer()
        
        if wasTranscribing {
            try? startTranscribing()
        }
    }
    
    // MARK: - Private
    
    private func setupRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
    }
    
    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            // 忽略取消错误
            if (error as NSError).code != 203 {
                logger.error("❌ Recognition error: \(error.localizedDescription)")
                onError?(error)
            }
            return
        }
        
        guard let result = result else { return }
        
        let text = result.bestTranscription.formattedString
        let isFinal = result.isFinal
        
        guard !text.isEmpty else { return }
        
        let segment = TranscriptionSegment(
            text: text,
            isFinal: isFinal,
            timestamp: Date()
        )
        
        onTranscription?(segment)
        
        if isFinal {
            logger.debug("📝 Final: \(text)")
        }
    }
    
    /// 将 CMSampleBuffer 转换为 AVAudioPCMBuffer
    /// SFSpeech 需要 Float32 格式，16000Hz，单声道
    private func convertToPCMBuffer(_ sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            logger.warning("⚠️ No format description")
            return nil
        }
        
        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee else {
            logger.warning("⚠️ No ASBD")
            return nil
        }
        
        let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)
        guard numSamples > 0 else { return nil }
        
        // 创建 SFSpeech 兼容的输出格式：Float32, 16000Hz, 单声道
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            return nil
        }
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: AVAudioFrameCount(numSamples)) else {
            return nil
        }
        outputBuffer.frameLength = AVAudioFrameCount(numSamples)
        
        // 获取原始音频数据
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }
        
        var lengthAtOffset: Int = 0
        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        
        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: &lengthAtOffset,
            totalLengthOut: &totalLength,
            dataPointerOut: &dataPointer
        )
        
        guard status == kCMBlockBufferNoErr, let data = dataPointer else {
            return nil
        }
        
        guard let outputData = outputBuffer.floatChannelData?[0] else {
            return nil
        }
        
        // 根据输入格式转换数据
        let formatFlags = asbd.mFormatFlags
        let isFloat = (formatFlags & kAudioFormatFlagIsFloat) != 0
        let isSignedInt = (formatFlags & kAudioFormatFlagIsSignedInteger) != 0
        let bitsPerChannel = asbd.mBitsPerChannel
        
        if isFloat && bitsPerChannel == 32 {
            // Float32 输入 - 直接复制
            let floatData = UnsafeRawPointer(data).bindMemory(to: Float.self, capacity: numSamples)
            memcpy(outputData, floatData, numSamples * MemoryLayout<Float>.size)
        } else if isSignedInt && bitsPerChannel == 16 {
            // Int16 输入 - 转换为 Float32
            let int16Data = UnsafeRawPointer(data).bindMemory(to: Int16.self, capacity: numSamples)
            for i in 0..<numSamples {
                outputData[i] = Float(int16Data[i]) / 32768.0
            }
        } else if isSignedInt && bitsPerChannel == 32 {
            // Int32 输入 - 转换为 Float32
            let int32Data = UnsafeRawPointer(data).bindMemory(to: Int32.self, capacity: numSamples)
            for i in 0..<numSamples {
                outputData[i] = Float(int32Data[i]) / Float(Int32.max)
            }
        } else {
            // 不支持的格式
            logger.warning("⚠️ Unsupported audio format: isFloat=\(isFloat), bits=\(bitsPerChannel)")
            return nil
        }
        
        return outputBuffer
    }
}

// MARK: - Supporting Types

struct TranscriptionSegment {
    let text: String
    let isFinal: Bool
    let timestamp: Date
}

// MARK: - Errors

extension LiveCaptionTranscriber {
    
    enum TranscriberError: LocalizedError {
        case recognizerNotAvailable
        case requestCreationFailed
        case notAuthorized
        
        var errorDescription: String? {
            switch self {
            case .recognizerNotAvailable:
                return "语音识别器不可用"
            case .requestCreationFailed:
                return "创建识别请求失败"
            case .notAuthorized:
                return "未授权语音识别权限"
            }
        }
    }
}

// MARK: - Authorization

extension LiveCaptionTranscriber {
    
    /// 请求语音识别权限
    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}
