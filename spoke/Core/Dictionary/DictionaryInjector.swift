import Foundation
import Speech
import os

// MARK: - Dictionary Injector Protocol

/// 词典注入器协议
/// 抽象不同 ASR 引擎的词典注入机制
@MainActor
protocol DictionaryInjector: AnyObject {
    
    /// 引擎标识符
    var engineIdentifier: String { get }
    
    /// 是否支持预处理缓存
    var supportsCaching: Bool { get }
    
    /// 是否需要重新准备（词典变化后）
    var needsRePrepare: Bool { get }
    
    /// 准备词典注入（可能耗时，异步执行）
    /// - Parameter entries: 词典条目
    func prepare(with entries: [DictionaryEntry]) async throws
    
    /// 应用词典到识别请求
    /// - Parameter request: 识别请求对象（泛型，不同引擎有不同类型）
    func apply<T>(to request: inout T) throws
    
    /// 重置状态
    func reset()
}

// MARK: - Injection Result

/// 词典注入结果
enum DictionaryInjectionResult {
    case success
    case skipped(reason: String)
    case failed(error: Error)
}

// MARK: - Apple Speech Injector

/// Apple SFSpeechRecognizer / DictationTranscriber 词典注入器
/// 使用 iOS 17+ / macOS 14+ 的 SFSpeechLanguageModel 自定义语言模型
/// 支持预编译 LM，适用于 SFSpeechRecognizer 和 DictationTranscriber
@available(macOS 14.0, iOS 17.0, *)
final class AppleSpeechDictionaryInjector: DictionaryInjector {
    
    // MARK: - Properties
    
    let engineIdentifier = "apple.sfspeechrecognizer"
    let supportsCaching = true
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "AppleSpeechInjector")
    
    /// 预处理输出文件 URL
    private var modelOutputURL: URL?
    private var lexiconOutputURL: URL?
    
    /// 当前词典内容的 hash（用于检测变化）
    private var currentEntriesHash: Int = 0
    
    /// 是否已准备好
    private var isPrepared = false
    
    /// 预编译 LM 配置（供 DictationTranscriber 使用）
    /// 注意：此属性在 prepare() 成功后可用
    var languageModelConfiguration: SFSpeechLanguageModel.Configuration? {
        guard isPrepared, let outputURL = modelOutputURL else { return nil }
        if let lexiconURL = lexiconOutputURL {
            return SFSpeechLanguageModel.Configuration(languageModel: outputURL, vocabulary: lexiconURL)
        }
        return SFSpeechLanguageModel.Configuration(languageModel: outputURL)
    }
    
    // MARK: - DictionaryInjector
    
    var needsRePrepare: Bool {
        !isPrepared || hasEntriesChanged()
    }
    
    func prepare(with entries: [DictionaryEntry]) async throws {
        guard !entries.isEmpty else {
            logger.info("📚 No dictionary entries, skipping LM preparation")
            isPrepared = true
            return
        }
        
        let newHash = entries.hashValue
        
        // 检查缓存是否有效
        if isPrepared && currentEntriesHash == newHash && modelOutputURL != nil {
            logger.info("📚 Using cached language model (词典未变化)")
            return
        }
        
        let totalStartTime = CFAbsoluteTimeGetCurrent()
        logger.info("📚 [预编译 LM] 开始准备自定义语言模型，词条数: \(entries.count)")
        
        // 1. 构建训练数据
        let buildStartTime = CFAbsoluteTimeGetCurrent()
        let trainingData = buildTrainingData(from: entries)
        logger.info("⏱️ [预编译 LM] 构建训练数据耗时: \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - buildStartTime) * 1000))ms")
        
        // 2. 写入临时文件
        let writeStartTime = CFAbsoluteTimeGetCurrent()
        let inputURL = try await writeTrainingData(trainingData)
        logger.info("⏱️ [预编译 LM] 写入临时文件耗时: \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent() - writeStartTime) * 1000))ms")
        
        // 3. 准备输出路径
        let (outputURL, lexiconURL) = prepareOutputURLs()
        
        // 4. 执行预处理（耗时操作）
        let prepareStartTime = CFAbsoluteTimeGetCurrent()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            SFSpeechLanguageModel.prepareCustomLanguageModel(
                for: inputURL,
                configuration: .init(languageModel: outputURL, vocabulary: lexiconURL),
                ignoresCache: false
            ) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        let prepareTime = (CFAbsoluteTimeGetCurrent() - prepareStartTime) * 1000
        logger.info("⏱️ [预编译 LM] SFSpeechLanguageModel.prepareCustomLanguageModel 耗时: \(String(format: "%.2f", prepareTime))ms")
        
        // 5. 更新状态
        self.modelOutputURL = outputURL
        self.lexiconOutputURL = lexiconURL
        self.currentEntriesHash = newHash
        self.isPrepared = true
        
        let totalTime = (CFAbsoluteTimeGetCurrent() - totalStartTime) * 1000
        logger.info("✅ [预编译 LM] 自定义语言模型准备完成，总耗时: \(String(format: "%.2f", totalTime))ms")
        logger.info("📍 [预编译 LM] 模型路径: \(outputURL.path)")
    }
    
    func apply<T>(to request: inout T) throws {
        guard let speechRequest = request as? SFSpeechAudioBufferRecognitionRequest else {
            throw DictionaryInjectionError.unsupportedRequestType
        }
        
        guard isPrepared, let outputURL = modelOutputURL else {
            logger.warning("⚠️ Language model not prepared, skipping injection")
            return
        }
        
        // 强制本地识别（自定义语言模型要求）
        speechRequest.requiresOnDeviceRecognition = true
        
        // 附加自定义语言模型
        if let lexiconURL = lexiconOutputURL {
            speechRequest.customizedLanguageModel = SFSpeechLanguageModel.Configuration(
                languageModel: outputURL,
                vocabulary: lexiconURL
            )
        } else {
            speechRequest.customizedLanguageModel = SFSpeechLanguageModel.Configuration(
                languageModel: outputURL
            )
        }
        
        // 类型擦除返回
        request = speechRequest as! T
        
        logger.debug("📚 Applied custom language model to request")
    }
    
    func reset() {
        isPrepared = false
        currentEntriesHash = 0
        modelOutputURL = nil
        lexiconOutputURL = nil
    }
    
    // MARK: - Private
    
    private func hasEntriesChanged() -> Bool {
        let currentHash = DictionaryService.shared.entries.hashValue
        return currentHash != currentEntriesHash
    }
    
    private func buildTrainingData(from entries: [DictionaryEntry]) -> SFCustomLanguageModelData {
        let locale = Locale(identifier: "zh-CN")
        
        return SFCustomLanguageModelData(
            locale: locale,
            identifier: "com.spokeanywhere.dictionary",
            version: "1.0"
        ) {
            // 双轨策略：
            // 1. 单词本身作为基础（contextualStrings 也会注入）
            // 2. 用户纠正时收集的完整句子作为训练短语（WWDC23 推荐方式）
            
            let weightLevel = UserDefaults.standard.dictionaryWeightLevel
            
            for entry in entries {
                let weight = weightLevel.baseWeight + entry.frequency
                
                // 单词本身
                SFCustomLanguageModelData.PhraseCount(
                    phrase: entry.word,
                    count: weight
                )
                
                // 用户收集的训练短语（效果更强）
                for phrase in entry.trainingPhrases {
                    SFCustomLanguageModelData.PhraseCount(
                        phrase: phrase,
                        count: weight * 2  // 用户主动收集的短语给更高权重
                    )
                }
            }
        }
    }
    
    private func writeTrainingData(_ data: SFCustomLanguageModelData) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let inputURL = tempDir.appendingPathComponent("dictionary_training_\(UUID().uuidString).bin")
        try await data.export(to: inputURL)
        return inputURL
    }
    
    private func prepareOutputURLs() -> (URL, URL) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let spokeDir = appSupport.appendingPathComponent("Spoke/LanguageModels", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: spokeDir, withIntermediateDirectories: true)
        
        let outputURL = spokeDir.appendingPathComponent("custom_lm.bin")
        let lexiconURL = spokeDir.appendingPathComponent("custom_lexicon.bin")
        
        return (outputURL, lexiconURL)
    }
}

// MARK: - Whisper Injector

/// Whisper 词典注入器
/// 使用 initial_prompt 方式注入词典
final class WhisperDictionaryInjector: DictionaryInjector {
    
    // MARK: - Properties
    
    let engineIdentifier = "whisper"
    let supportsCaching = false  // Whisper 每次都需要传 prompt
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "WhisperInjector")
    
    /// 生成的 prompt 字符串
    private var promptString: String = ""
    
    /// 是否已准备好
    private var isPrepared = false
    
    // MARK: - DictionaryInjector
    
    var needsRePrepare: Bool {
        // Whisper 实际上不需要预处理，但保持接口一致
        !isPrepared
    }
    
    func prepare(with entries: [DictionaryEntry]) async throws {
        guard !entries.isEmpty else {
            promptString = ""
            isPrepared = true
            return
        }
        
        // 构建 Whisper 友好的 prompt
        // 格式 1: Glossary 列表（适合专有名词）
        // 格式 2: 上下文描述（适合领域术语）
        
        let words = entries.map { $0.word }
        
        // 使用 Glossary 格式（更简洁有效）
        promptString = "Glossary: " + words.joined(separator: ", ")
        
        isPrepared = true
        logger.info("📚 Prepared Whisper prompt with \(entries.count) words")
    }
    
    func apply<T>(to request: inout T) throws {
        // Whisper 的实现取决于具体的 Whisper 封装
        // 这里预留接口，实际实现时需要适配
        
        // 示例：如果是字典类型的配置
        if var config = request as? [String: Any] {
            config["initial_prompt"] = promptString
            request = config as! T
        }
        
        // 示例：如果是自定义的 WhisperConfig 结构体
        // 需要根据实际 Whisper 封装来实现
        
        logger.debug("📚 Applied Whisper prompt: \(self.promptString.prefix(50))...")
    }
    
    func reset() {
        isPrepared = false
        promptString = ""
    }
    
    /// 获取当前 prompt（供外部直接使用）
    var currentPrompt: String {
        promptString
    }
}

// MARK: - Post-Processing Injector

/// 后处理词典注入器（文本替换方式）
/// 作为 fallback，适用于不支持原生词典的引擎
final class PostProcessingDictionaryInjector: DictionaryInjector {
    
    let engineIdentifier = "post-processing"
    let supportsCaching = true
    
    private var isPrepared = false
    
    var needsRePrepare: Bool { !isPrepared }
    
    func prepare(with entries: [DictionaryEntry]) async throws {
        // 后处理不需要准备，直接使用 DictionaryService
        isPrepared = true
    }
    
    func apply<T>(to request: inout T) throws {
        // 后处理不需要修改请求
        // 实际处理在 TranscriptionPostProcessor 中完成
    }
    
    func reset() {
        isPrepared = false
    }
}

// MARK: - Injector Factory

/// 词典注入器工厂
@MainActor
final class DictionaryInjectorFactory {
    
    /// 根据引擎类型创建对应的注入器
    static func createInjector(for engineType: TranscriptionEngineType) -> DictionaryInjector {
        switch engineType {
        case .speechAnalyzer, .sfSpeech:
            // macOS 14+ 使用原生 LM 自定义
            if #available(macOS 14.0, iOS 17.0, *) {
                return AppleSpeechDictionaryInjector()
            } else {
                // 旧版本使用后处理
                return PostProcessingDictionaryInjector()
            }
            
        case .whisperLocal:
            return WhisperDictionaryInjector()
        }
    }
}

// MARK: - Errors

enum DictionaryInjectionError: LocalizedError {
    case unsupportedRequestType
    case preparationFailed(String)
    case injectionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedRequestType:
            return "不支持的请求类型"
        case .preparationFailed(let reason):
            return "词典准备失败: \(reason)"
        case .injectionFailed(let reason):
            return "词典注入失败: \(reason)"
        }
    }
}

