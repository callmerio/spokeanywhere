import AVFoundation
import Speech
import os
import CoreMedia

/// SpeechAnalyzer 实现
/// 适用于 macOS 26+ / iOS 26+
/// 新一代设备端语音识别，更快更准确
@available(macOS 26.0, iOS 26.0, *)
@MainActor
final class SpeechAnalyzerProvider: TranscriptionProvider {
    
    // MARK: - Properties
    
    let identifier = "speech_analyzer"
    let displayName = "Apple 语音分析器"
    
    let capabilities: TranscriptionCapability = [.realtime, .offline, .longForm, .punctuation, .multilingual]
    
    var locale: Locale {
        didSet {
            // 需要重新创建 transcriber
            needsRecreate = true
        }
    }
    
    var isAvailable: Bool {
        SpeechTranscriber.isAvailable
    }
    
    var supportedLocales: [Locale] {
        // 返回常见支持的语言列表（避免 async 调用）
        // 实际支持情况会在 prepare() 时检查
        [
            Locale(identifier: "zh-Hans"),
            Locale(identifier: "zh-Hant"),
            Locale(identifier: "en-US"),
            Locale(identifier: "ja-JP"),
            Locale(identifier: "ko-KR"),
            Locale(identifier: "de-DE"),
            Locale(identifier: "fr-FR"),
            Locale(identifier: "es-ES"),
        ]
    }
    
    var onResult: ((TranscriptionResult) -> Void)?
    var onError: ((Error) -> Void)?
    
    // MARK: - Private
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "SpeechAnalyzerProvider")
    
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var analyzeTask: Task<Void, Never>?
    
    private var needsRecreate = false
    private var targetAudioFormat: AVAudioFormat?
    private var audioConverter: AVAudioConverter?
    
    // 累积的文本
    private var finalizedText: String = ""   // 已确认的文本
    private var volatileText: String = ""    // 当前预览文本
    
    // MARK: - Init
    
    init(locale: Locale = Locale(identifier: "zh-Hans")) {
        self.locale = locale
    }
    
    // MARK: - TranscriptionProvider
    
    func requestAuthorization() async -> Bool {
        // SpeechAnalyzer 使用设备端处理，主要需要麦克风权限
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        return speechStatus
    }
    
    func prepare() async throws {
        try await setupSpeechAnalyzer()
        logger.info("✅ SpeechAnalyzerProvider prepared")
    }
    
    func process(buffer: AVAudioPCMBuffer) throws {
        guard let continuation = inputContinuation else {
            throw TranscriptionError.engineNotReady
        }
        
        // 转换音频格式（如果需要）
        let convertedBuffer: AVAudioPCMBuffer
        if let targetFormat = targetAudioFormat, buffer.format != targetFormat {
            convertedBuffer = try convertBuffer(buffer, to: targetFormat)
        } else {
            convertedBuffer = buffer
        }
        
        // 创建 AnalyzerInput 并发送
        let input = AnalyzerInput(buffer: convertedBuffer)
        continuation.yield(input)
    }
    
    /// 转换音频缓冲区格式
    private func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        // 创建或复用转换器
        if audioConverter == nil || audioConverter?.inputFormat != buffer.format || audioConverter?.outputFormat != format {
            guard let converter = AVAudioConverter(from: buffer.format, to: format) else {
                throw TranscriptionError.processingFailed("Cannot create audio converter")
            }
            audioConverter = converter
        }
        
        guard let converter = audioConverter else {
            throw TranscriptionError.processingFailed("Audio converter not available")
        }
        
        // 计算输出帧数
        let ratio = format.sampleRate / buffer.format.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: outputFrameCount) else {
            throw TranscriptionError.processingFailed("Cannot create output buffer")
        }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            throw TranscriptionError.processingFailed("Conversion failed: \(error.localizedDescription)")
        }
        
        return outputBuffer
    }
    
    func finishProcessing() async throws {
        // 结束输入流
        inputContinuation?.finish()
        
        // 等待分析完成
        if let analyzer = analyzer {
            try await analyzer.finalizeAndFinishThroughEndOfInput()
        }
        
        // 等待结果处理完成
        await resultsTask?.value
        
        logger.info("✅ SpeechAnalyzerProvider finished processing")
    }
    
    func cancel() {
        inputContinuation?.finish()
        resultsTask?.cancel()
        analyzeTask?.cancel()
        
        Task {
            await analyzer?.cancelAndFinishNow()
        }
        
        cleanup()
        logger.info("🚫 SpeechAnalyzerProvider cancelled")
    }
    
    func reset() {
        cleanup()
        finalizedText = ""
        volatileText = ""
        needsRecreate = true
        logger.info("🔄 SpeechAnalyzerProvider reset")
    }
    
    // MARK: - Private - SpeechAnalyzer Setup
    
    private func setupSpeechAnalyzer() async throws {
        // Step 1: 获取支持的 locale
        guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            logger.error("❌ Locale not supported: \(self.locale.identifier)")
            throw TranscriptionError.unsupportedLocale(locale)
        }
        
        // Step 2: 创建 SpeechTranscriber
        // 使用 progressiveTranscription 预设支持实时转录
        let transcriber = SpeechTranscriber(
            locale: supportedLocale,
            preset: .progressiveTranscription
        )
        self.transcriber = transcriber
        
        // Step 3: 检查并安装所需资产
        try await ensureAssetsInstalled(for: transcriber)
        
        // Step 4: 获取最佳音频格式
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            logger.error("❌ No compatible audio format available")
            throw TranscriptionError.processingFailed("No compatible audio format")
        }
        self.targetAudioFormat = format
        logger.info("📢 Using audio format: \(format)")
        
        // Step 5: 创建输入流
        let (inputSequence, inputBuilder) = AsyncStream.makeStream(of: AnalyzerInput.self)
        self.inputContinuation = inputBuilder
        
        // Step 6: 创建 SpeechAnalyzer
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer
        
        // Step 7: 预热分析器
        try await analyzer.prepareToAnalyze(in: format)
        
        // Step 8: 启动结果监听
        resultsTask = Task { [weak self] in
            await self?.listenForResults(transcriber: transcriber)
        }
        
        // Step 9: 启动分析（自主模式）
        analyzeTask = Task { [weak self] in
            do {
                try await analyzer.start(inputSequence: inputSequence)
            } catch {
                await MainActor.run {
                    self?.onError?(error)
                }
            }
        }
        
        logger.info("✅ SpeechAnalyzer setup complete for locale: \(supportedLocale.identifier)")
    }
    
    private func ensureAssetsInstalled(for transcriber: SpeechTranscriber) async throws {
        // 检查是否需要下载资产
        if let installationRequest = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            logger.info("📥 Downloading speech assets...")
            
            // 下载并安装
            try await installationRequest.downloadAndInstall()
            
            logger.info("✅ Speech assets installed")
        } else {
            logger.info("✅ Speech assets already installed")
        }
    }
    
    private func listenForResults(transcriber: SpeechTranscriber) async {
        do {
            for try await result in transcriber.results {
                await handleResult(result)
            }
        } catch {
            await MainActor.run { [weak self] in
                self?.logger.error("❌ Results error: \(error.localizedDescription)")
                self?.onError?(error)
            }
        }
    }
    
    private func handleResult(_ result: SpeechTranscriber.Result) async {
        // 从 AttributedString 提取纯文本
        let segmentText = String(result.text.characters)
        let isFinal = result.isFinal
        
        await MainActor.run { [weak self] in
            guard let self = self else { return }
            
            if isFinal {
                // Final 结果：累积到 finalizedText
                self.finalizedText += segmentText
                self.volatileText = ""  // 清空 volatile
                
                self.logger.info("📝 Finalized segment: \(segmentText)")
                self.logger.info("📝 Total: \(self.finalizedText)")
            } else {
                // Volatile 结果：更新预览
                self.volatileText = segmentText
                
                self.logger.debug("📝 Volatile: \(segmentText)")
            }
            
            // 使用新的构造器，分离 finalized 和 volatile
            let transcriptionResult = TranscriptionResult(
                finalizedText: self.finalizedText,
                volatileText: self.volatileText,
                type: .partial  // 录音未结束，始终是 partial
            )
            self.onResult?(transcriptionResult)
        }
    }
    
    private func cleanup() {
        inputContinuation = nil
        resultsTask = nil
        analyzeTask = nil
        analyzer = nil
        transcriber = nil
        targetAudioFormat = nil
        audioConverter = nil
    }
}

// MARK: - Provider Info

@available(macOS 26.0, iOS 26.0, *)
extension SpeechAnalyzerProvider {
    static var info: TranscriptionProviderInfo {
        TranscriptionProviderInfo(
            identifier: "speech_analyzer",
            displayName: "Apple 语音分析器",
            description: "新一代设备端语音识别，更快更准确，完全离线，适用于 macOS 26+",
            capabilities: [.realtime, .offline, .longForm, .punctuation, .multilingual],
            minOSVersion: "macOS 26.0",
            isAvailable: SpeechTranscriber.isAvailable
        )
    }
}

// MARK: - Availability Check

enum SpeechAnalyzerAvailability {
    /// 检查当前系统是否支持 SpeechAnalyzer
    static var isSupported: Bool {
        if #available(macOS 26.0, iOS 26.0, *) {
            return true
        }
        return false
    }
}
