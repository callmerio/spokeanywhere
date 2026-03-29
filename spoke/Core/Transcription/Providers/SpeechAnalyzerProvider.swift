@preconcurrency import AVFoundation
import CoreMedia
import os
import Speech

/// SpeechAnalyzer 实现（支持 DictationTranscriber 和 SpeechTranscriber）
/// 适用于 macOS 26+ / iOS 26+
/// 新一代设备端语音识别，更快更准确，支持自定义词典
@available(macOS 26.0, iOS 26.0, *)
@MainActor
struct SpeechAnalyzerProviderDictionaryInjectionState {
    let isEnabled: Bool
    let isPrepared: Bool
    let injector: DictionaryInjector?
}

@available(macOS 26.0, iOS 26.0, *)
@MainActor
struct SpeechAnalyzerProviderDictionaryLexicon {
    let words: Set<String>
    let trainingPhrases: [(word: String, phrase: String)]

    var hasTrainingPhrases: Bool {
        !trainingPhrases.isEmpty
    }

    var contextualStrings: [String] {
        var allStrings = Array(words)
        for (_, phrase) in trainingPhrases {
            allStrings.append(phrase)
        }
        return allStrings
    }
}

@available(macOS 26.0, iOS 26.0, *)
@MainActor
struct SpeechAnalyzerProviderDependencies {
    let dictionaryInjectionState: () -> SpeechAnalyzerProviderDictionaryInjectionState
    let dictionaryLexicon: () -> SpeechAnalyzerProviderDictionaryLexicon
}

@available(macOS 26.0, iOS 26.0, *)
@MainActor
final class SpeechAnalyzerProvider: TranscriptionProvider {
    
    // MARK: - Properties
    
    let identifier = "speech_analyzer"
    let displayName = "Apple SpeechAnalyzer"
    
    let capabilities: TranscriptionCapability = [.realtime, .offline, .longForm, .punctuation, .multilingual]
    
    /// Model type to use (from TranscriptionModelManager)
    var modelType: TranscriptionModelType {
        didSet {
            if modelType != oldValue {
                needsRecreate = true
            }
        }
    }
    
    /// Whether to enable precompiled LM (only for .dictation model)
    var enablePrecompiledLM: Bool = true
    
    var locale: Locale {
        didSet {
            if locale != oldValue {
                needsRecreate = true
            }
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
            Locale(identifier: "es-ES")
        ]
    }
    
    var onResult: ((TranscriptionResult) -> Void)?
    var onError: ((Error) -> Void)?
    
    // MARK: - Private
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "SpeechAnalyzerProvider")
    
    private var analyzer: SpeechAnalyzer?
    private var dictationTranscriber: DictationTranscriber?
    private var speechTranscriber: SpeechTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var analyzeTask: Task<Void, Never>?
    
    private var needsRecreate = false
    private var targetAudioFormat: AVAudioFormat?
    private var audioConverter: AVAudioConverter?
    
    // 累积的文本
    private var finalizedText: String = ""   // 已确认的文本
    private var volatileText: String = ""    // 当前预览文本
    private let dependencies: SpeechAnalyzerProviderDependencies
    
    // MARK: - Init
    
    init(
        locale: Locale = Locale(identifier: "zh-Hans"),
        modelType: TranscriptionModelType = .dictation,
        dependencies: SpeechAnalyzerProviderDependencies
    ) {
        self.locale = locale
        self.modelType = modelType
        self.dependencies = dependencies
    }

    convenience init(locale: Locale = Locale(identifier: "zh-Hans"), modelType: TranscriptionModelType = .dictation) {
        self.init(locale: locale, modelType: modelType, dependencies: .live)
    }
    
    /// Initialize from TranscriptionModelManager configuration
    convenience init(config: TranscriptionProviderConfig) {
        self.init(locale: config.locale, modelType: config.modelType, dependencies: .live)
        self.enablePrecompiledLM = config.enablePrecompiledLM
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
        
        let analyzer = analyzer
        _ = makeSpeechAnalyzerCancelOperation(analyzer)
        
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
        let setupStartTime = CFAbsoluteTimeGetCurrent()
        
        logger.info("🚀 Setting up SpeechAnalyzer with model: \(self.modelType.rawValue)")
        
        // Route to appropriate setup based on model type
        switch modelType {
        case .dictation:
            try await setupDictationTranscriber()
        case .speechTranscriber:
            try await setupSpeechTranscriber()
        default:
            throw TranscriptionError.processingFailed("Unsupported model type: \(modelType.rawValue)")
        }
        
        let totalTime = (CFAbsoluteTimeGetCurrent() - setupStartTime) * 1000
        logger.info("⏱️ Total setup time: \(String(format: "%.2f", totalTime))ms")
    }
    
    // MARK: - DictationTranscriber Setup
    
    private func setupDictationTranscriber() async throws {
        // Step 1: Get supported locale
        guard let supportedLocale = await DictationTranscriber.supportedLocale(equivalentTo: locale) else {
            logger.error("❌ Locale not supported: \(self.locale.identifier)")
            throw TranscriptionError.unsupportedLocale(locale)
        }
        
        // Step 2: Create DictationTranscriber (supports precompiled LM)
        let transcriber = try await createDictationTranscriber(locale: supportedLocale)
        self.dictationTranscriber = transcriber
        
        // Step 3: Ensure assets are installed
        try await ensureAssetsInstalled(for: transcriber)
        
        // Step 4: Get best audio format
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw TranscriptionError.processingFailed("No compatible audio format")
        }
        self.targetAudioFormat = format
        
        // Step 5: Create input stream
        let (inputSequence, inputBuilder) = AsyncStream.makeStream(of: AnalyzerInput.self)
        self.inputContinuation = inputBuilder
        
        // Step 6: Create SpeechAnalyzer
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer
        
        // Step 7: Inject contextualStrings (words + training phrases)
        try await injectContextualStrings(to: analyzer)
        
        // Step 8: Prepare analyzer
        try await analyzer.prepareToAnalyze(in: format)
        
        // Step 9: Start listening for results
        resultsTask = makeSpeechAnalyzerProviderOperation(owner: self) { provider in
            await provider.listenForDictationResults(transcriber: transcriber)
        }
        
        // Step 10: Start analysis
        analyzeTask = makeSpeechAnalyzerOperation { [weak self] in
            do {
                try await analyzer.start(inputSequence: inputSequence)
            } catch {
                await self?.handleAnalyzerStartFailure(error)
            }
        }
        
        logger.info("✅ DictationTranscriber setup complete for locale: \(supportedLocale.identifier, privacy: .public)")
    }
    
    // MARK: - SpeechTranscriber Setup
    
    private func setupSpeechTranscriber() async throws {
        // Step 1: Get supported locale
        guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            logger.error("❌ Locale not supported: \(self.locale.identifier)")
            throw TranscriptionError.unsupportedLocale(locale)
        }
        
        // Step 2: Create SpeechTranscriber (stronger model, no precompiled LM)
        let transcriber = SpeechTranscriber(
            locale: supportedLocale,
            preset: .progressiveTranscription
        )
        self.speechTranscriber = transcriber
        
        // Step 3: Ensure assets are installed
        logger.info("📌 [ST] Step 3: Checking assets...")
        try await ensureAssetsInstalled(for: transcriber)
        
        // Step 4: Get best audio format
        logger.info("📌 [ST] Step 4: Getting audio format...")
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw TranscriptionError.processingFailed("No compatible audio format")
        }
        self.targetAudioFormat = format
        logger.info("📌 [ST] Audio format: \(format.sampleRate)Hz, \(format.channelCount)ch")
        
        // Step 5: Create input stream
        let (inputSequence, inputBuilder) = AsyncStream.makeStream(of: AnalyzerInput.self)
        self.inputContinuation = inputBuilder
        
        // Step 6: Create SpeechAnalyzer
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer
        
        // Step 7: Inject contextualStrings (words + training phrases)
        logger.info("📌 [ST] Step 7: Injecting contextualStrings...")
        try await injectContextualStrings(to: analyzer)
        
        // Step 8: Prepare analyzer
        logger.info("📌 [ST] Step 8: Preparing analyzer (this may take a while)...")
        try await analyzer.prepareToAnalyze(in: format)
        logger.info("📌 [ST] Step 8: ✅ Analyzer prepared successfully")
        
        // Step 9: Start listening for results
        resultsTask = makeSpeechAnalyzerProviderOperation(owner: self) { provider in
            await provider.listenForSpeechTranscriberResults(transcriber: transcriber)
        }
        
        // Step 10: Start analysis
        logger.info("📌 [ST] Step 10: Starting analysis task...")
        analyzeTask = makeSpeechAnalyzerOperation { [weak self] in
            do {
                try await analyzer.start(inputSequence: inputSequence)
            } catch {
                await self?.handleAnalyzerStartFailure(
                    error,
                    logPrefix: "❌ [ST] analyzer.start failed"
                )
            }
        }
        
        logger.info("✅ SpeechTranscriber setup complete for locale: \(supportedLocale.identifier, privacy: .public)")
    }
    
    // MARK: - Shared Setup Helpers
    
    /// Inject contextualStrings to analyzer (words + training phrases)
    private func injectContextualStrings(to analyzer: SpeechAnalyzer) async throws {
        let injectionState = dependencies.dictionaryInjectionState()
        guard injectionState.isEnabled else {
            logger.info("ℹ️ [词典] 词典注入已禁用")
            return
        }
        
        let allStrings = contextualStringsForAnalyzer()
        
        guard !allStrings.isEmpty else {
            logger.info("⚠️ [词典] 词典为空，跳过注入")
            return
        }
        
        let context = AnalysisContext()
        context.contextualStrings[.general] = allStrings
        
        logger.info("📌 [词典] Calling setContext with \(allStrings.count) strings...")
        try await analyzer.setContext(context)
        logger.info("📌 [词典] setContext completed successfully")
        
        // 显示前 5 个词条用于调试（仅 DEBUG 模式显示具体内容）
        #if DEBUG
        let preview = allStrings.prefix(5).joined(separator: ", ")
        let suffix = allStrings.count > 5 ? "..." : ""
        logger.info("📚 [词典] contextualStrings 已注入: \(allStrings.count, privacy: .public) 个 [\(preview, privacy: .public)\(suffix, privacy: .public)]")
        #else
        logger.info("📚 [词典] contextualStrings 已注入: \(allStrings.count) 个")
        #endif
    }
    
    /// 创建 DictationTranscriber
    /// 双轨词典注入：
    /// 1. contextualStrings（轻量级）- 通过 SpeechAnalyzer.context 注入
    /// 2. 预编译 LM（当有训练短语时）- 通过 contentHints 注入
    private func createDictationTranscriber(locale: Locale) async throws -> DictationTranscriber {
        let basePreset = DictationTranscriber.Preset.progressiveShortDictation
        var contentHints = basePreset.contentHints
        var reportingOptions = basePreset.reportingOptions
        let injectionState = dependencies.dictionaryInjectionState()
        let lexicon = dependencies.dictionaryLexicon()
        
        // Only enable precompiled LM if user setting allows it
        if enablePrecompiledLM,
           injectionState.isEnabled,
           lexicon.hasTrainingPhrases,
           injectionState.isPrepared,
           let injector = injectionState.injector as? AppleSpeechDictionaryInjector,
           let lmConfiguration = injector.languageModelConfiguration {
            
            contentHints.insert(.customizedLanguage(modelConfiguration: lmConfiguration))
            reportingOptions.insert(.frequentFinalization)
            
            let phraseCount = lexicon.trainingPhrases.count
            logger.notice("📚 Precompiled LM enabled, training phrases: \(phraseCount, privacy: .public)")
        } else if !enablePrecompiledLM {
            logger.notice("ℹ️ Precompiled LM disabled by user setting")
        }
        
        let transcriber = DictationTranscriber(
            locale: locale,
            contentHints: contentHints,
            transcriptionOptions: basePreset.transcriptionOptions,
            reportingOptions: reportingOptions,
            attributeOptions: basePreset.attributeOptions
        )
        
        return transcriber
    }

    private func contextualStringsForAnalyzer() -> [String] {
        dependencies.dictionaryLexicon().contextualStrings
    }
    
    // MARK: - [DEPRECATED] SpeechTranscriber Setup (保留用于 fallback)
    // TODO: [Roadmap] 实时注入方案 - 预编译耗时过长时的快速 fallback
    /*
    private func setupSpeechTranscriberFallback() async throws {
        // Step 1: 获取支持的 locale
        guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            logger.error("❌ Locale not supported: \(self.locale.identifier)")
            throw TranscriptionError.unsupportedLocale(locale)
        }
        
        // Step 2: 创建 SpeechTranscriber（支持 contextualStrings 轻量级注入）
        let transcriber = SpeechTranscriber(
            locale: supportedLocale,
            preset: .progressiveTranscription
        )
        self.transcriber = transcriber
        
        // Step 3: 配置 contextualStrings（实时注入，无需预编译）
        let injectionState = dependencies.dictionaryInjectionState()
        if injectionState.isEnabled {
            let context = AnalysisContext()
            let words = Array(dependencies.dictionaryLexicon().words)
            if !words.isEmpty {
                context.contextualStrings[.general] = words
                try await analyzer?.setContext(context)
                logger.info("📚 [词典] contextualStrings 已注入: \(words.count) 个词")
            }
        }
        
        // ... 其余与 DictationTranscriber 相同 ...
    }
    */
    
    private func ensureAssetsInstalled(for transcriber: DictationTranscriber) async throws {
        if let installationRequest = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            logger.info("📥 Downloading DictationTranscriber assets...")
            try await installationRequest.downloadAndInstall()
            logger.info("✅ DictationTranscriber assets installed")
        } else {
            logger.info("✅ DictationTranscriber assets already installed")
        }
    }
    
    private func ensureAssetsInstalled(for transcriber: SpeechTranscriber) async throws {
        if let installationRequest = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            logger.info("📥 Downloading SpeechTranscriber assets (~2GB)...")
            try await installationRequest.downloadAndInstall()
            logger.info("✅ SpeechTranscriber assets installed")
        } else {
            logger.info("✅ SpeechTranscriber assets already installed")
        }
    }
    
    /// 监听 DictationTranscriber 结果
    private func listenForDictationResults(transcriber: DictationTranscriber) async {
        do {
            for try await result in transcriber.results {
                await handleDictationResult(result)
            }
        } catch {
            handleResultsError(error, prefix: "❌ Results error")
        }
    }
    
    /// 处理 DictationTranscriber 结果
    private func handleDictationResult(_ result: DictationTranscriber.Result) async {
        // 从 AttributedString 提取纯文本
        let segmentText = String(result.text.characters)
        applySegmentResult(
            segmentText,
            isFinal: result.isFinal,
            finalizedPrefix: "📝 Finalized segment",
            volatilePrefix: "📝 Volatile"
        )
    }
    
    // MARK: - SpeechTranscriber Results
    
    private func listenForSpeechTranscriberResults(transcriber: SpeechTranscriber) async {
        do {
            for try await result in transcriber.results {
                await handleSpeechTranscriberResult(result)
            }
        } catch {
            handleResultsError(error, prefix: "❌ SpeechTranscriber results error")
        }
    }
    
    private func handleSpeechTranscriberResult(_ result: SpeechTranscriber.Result) async {
        applySegmentResult(
            String(result.text.characters),
            isFinal: result.isFinal,
            finalizedPrefix: "📝 [ST] Finalized",
            volatilePrefix: "📝 [ST] Volatile"
        )
    }
    
    private func cleanup() {
        inputContinuation = nil
        resultsTask = nil
        analyzeTask = nil
        analyzer = nil
        dictationTranscriber = nil
        speechTranscriber = nil
        targetAudioFormat = nil
        audioConverter = nil
    }

    private func handleAnalyzerStartFailure(
        _ error: Error,
        logPrefix: String? = nil
    ) {
        if let logPrefix {
            logger.error("\(logPrefix, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
        onError?(error)
    }

    private func handleResultsError(
        _ error: Error,
        prefix: String
    ) {
        logger.error("\(prefix, privacy: .public): \(error.localizedDescription, privacy: .public)")
        onError?(error)
    }

    private func applySegmentResult(
        _ segmentText: String,
        isFinal: Bool,
        finalizedPrefix: String,
        volatilePrefix: String
    ) {
        if isFinal {
            finalizedText += segmentText
            volatileText = ""
            logger.info("\(finalizedPrefix, privacy: .public): \(segmentText, privacy: .public)")
            if !self.finalizedText.isEmpty {
                logger.info("📝 Total finalized: \(self.finalizedText, privacy: .public)")
            }
        } else {
            if !self.volatileText.isEmpty && segmentText.count < self.volatileText.count {
                logger.warning("⚠️ Volatile shrunk: '\(self.volatileText, privacy: .public)' -> '\(segmentText, privacy: .public)'")
            }
            volatileText = segmentText
            logger.info("\(volatilePrefix, privacy: .public): \(segmentText, privacy: .public)")
        }

        onResult?(
            TranscriptionResult(
                finalizedText: finalizedText,
                volatileText: volatileText,
                type: .partial
            )
        )
    }
}

// MARK: - Provider Info

@available(macOS 26.0, iOS 26.0, *)
extension SpeechAnalyzerProvider {
    static var info: TranscriptionProviderInfo {
        TranscriptionProviderInfo(
            identifier: "speech_analyzer",
            displayName: "Apple 语音分析器",
            description: "新一代设备端语音识别，支持预编译词典，更快更准确，完全离线，适用于 macOS 26+",
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
