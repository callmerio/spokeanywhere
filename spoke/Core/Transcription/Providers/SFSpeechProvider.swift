import AVFoundation
import os
import Speech

/// SFSpeechRecognizer 实现
/// 适用于 macOS 15+ / iOS 10+
/// 回退方案，当 SpeechAnalyzer 不可用时使用
@MainActor
final class SFSpeechProvider: TranscriptionProvider {
    
    // MARK: - Constants
    
    private static let cancelledErrorCode = 216
    
    // MARK: - Properties
    
    let identifier = "sf_speech_recognizer"
    let displayName = "Apple Dictation"
    
    let capabilities: TranscriptionCapability = [.realtime, .punctuation]
    
    var locale: Locale {
        didSet {
            speechRecognizer = SFSpeechRecognizer(locale: locale)
        }
    }
    
    var isAvailable: Bool {
        speechRecognizer?.isAvailable ?? false
    }
    
    var supportedLocales: [Locale] {
        SFSpeechRecognizer.supportedLocales().map { Locale(identifier: $0.identifier) }
    }
    
    var onResult: ((TranscriptionResult) -> Void)?
    var onError: ((Error) -> Void)?
    
    // MARK: - Private
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "SFSpeechProvider")
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // MARK: - Init
    
    init(locale: Locale = Locale(identifier: "zh-CN")) {
        self.locale = locale
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
    }
    
    // MARK: - TranscriptionProvider
    
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    func prepare() async throws {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw TranscriptionError.notAvailable
        }
        
        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard var request = recognitionRequest else {
            throw TranscriptionError.engineNotReady
        }
        
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.taskHint = .dictation
        
        // 应用词典注入（如果启用且已准备好）
        let manager = TranscriptionManager.shared
        if manager.isDictionaryInjectionEnabled,
           manager.isDictionaryPrepared,
           let injector = manager.dictionaryInjector {
            do {
                try injector.apply(to: &request)
                logger.info("📚 Dictionary applied to recognition request")
            } catch {
                logger.warning("⚠️ Failed to apply dictionary: \(error.localizedDescription)")
            }
        }
        
        // 更新 recognitionRequest
        recognitionRequest = request
        
        // 启动识别任务
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                self?.handleRecognitionResult(result: result, error: error)
            }
        }
        
        logger.info("✅ SFSpeechProvider prepared")
    }
    
    func process(buffer: AVAudioPCMBuffer) throws {
        guard let request = recognitionRequest else {
            throw TranscriptionError.engineNotReady
        }
        request.append(buffer)
    }
    
    func finishProcessing() async throws {
        recognitionRequest?.endAudio()
        
        // 等待最终结果
        var waitTime = 0
        let maxWait = 2000
        let interval = 100
        
        while waitTime < maxWait && recognitionTask != nil {
            try? await Task.sleep(for: .milliseconds(interval))
            waitTime += interval
        }
        
        logger.info("✅ SFSpeechProvider finished processing")
    }
    
    func cancel() {
        recognitionTask?.cancel()
        recognitionRequest?.endAudio()
        cleanup()
        logger.info("🚫 SFSpeechProvider cancelled")
    }
    
    func reset() {
        cleanup()
        logger.info("🔄 SFSpeechProvider reset")
    }
    
    // MARK: - Private
    
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result = result {
            let text = result.bestTranscription.formattedString
            let resultType: TranscriptionResultType = result.isFinal ? .final : .partial
            let confidence = result.bestTranscription.segments.last?.confidence
            
            onResult?(TranscriptionResult(
                text: text,
                type: resultType,
                confidence: confidence
            ))
            
            if result.isFinal {
                recognitionTask = nil
            }
        }
        
        if let error = error {
            let nsError = error as NSError
            // 忽略用户取消错误
            if nsError.code != Self.cancelledErrorCode {
                onError?(error)
            }
            recognitionTask = nil
        }
    }
    
    private func cleanup() {
        recognitionRequest = nil
        recognitionTask = nil
    }
}

// MARK: - Provider Info

extension SFSpeechProvider {
    /// 缓存的 SFSpeechRecognizer 实例，避免重复创建导致 SFLocalSpeechRecognitionClient 频繁 Invalidated
    private static let cachedRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    
    static var info: TranscriptionProviderInfo {
        TranscriptionProviderInfo(
            identifier: "sf_speech_recognizer",
            displayName: "Apple Dictation",
            description: "系统内置语音识别，需要网络，适用于 macOS 15+",
            capabilities: [.realtime, .punctuation],
            minOSVersion: "macOS 15.0",
            isAvailable: cachedRecognizer?.isAvailable ?? false
        )
    }
}
