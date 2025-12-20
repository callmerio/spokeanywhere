import AVFoundation
import os

/// 转录引擎类型
enum TranscriptionEngineType: String, CaseIterable {
    case speechAnalyzer = "speech_analyzer"     // macOS 26+ (优先)
    case sfSpeech = "sf_speech_recognizer"      // macOS 15+ (回退)
    case whisperLocal = "whisper_local"         // 本地 Whisper (未实现)
    
    var displayName: String {
        switch self {
        case .speechAnalyzer: return "Apple 语音分析器"
        case .sfSpeech: return "Apple Dictation"
        case .whisperLocal: return "Whisper 本地"
        }
    }
    
    var minOSVersion: String {
        switch self {
        case .speechAnalyzer: return "macOS 26.0+"
        case .sfSpeech: return "macOS 15.0+"
        case .whisperLocal: return "macOS 14.0+"
        }
    }
}

/// 转录引擎管理器
/// 负责自动选择最佳引擎，管理引擎生命周期
@MainActor
final class TranscriptionManager {
    
    // MARK: - Singleton
    
    static let shared = TranscriptionManager()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "TranscriptionManager")
    
    /// 当前活跃的引擎
    private(set) var currentProvider: TranscriptionProvider?
    
    /// 当前引擎类型
    private(set) var currentEngineType: TranscriptionEngineType?
    
    /// 当前词典注入器
    private(set) var dictionaryInjector: DictionaryInjector?
    
    /// 词典是否已准备好（预编译 LM 是否完成）
    /// 注意：contextualStrings 是轻量级注入，不需要预编译，实时生效
    private(set) var isDictionaryPrepared = false
    
    /// 首选语言 (now derived from TranscriptionModelManager)
    var preferredLocale: Locale {
        if #available(macOS 26.0, *) {
            let config = TranscriptionModelManager.shared.getProviderConfiguration()
            return config.locale
        }
        return Locale(identifier: "zh-CN")
    }
    
    /// 是否强制使用特定引擎（用于测试/调试）
    var forceEngineType: TranscriptionEngineType?
    
    /// 是否启用词典注入
    var isDictionaryInjectionEnabled: Bool {
        get { UserDefaults.standard.isDictionaryEnabled }
        set { UserDefaults.standard.isDictionaryEnabled = newValue }
    }
    
    // MARK: - Init
    
    private init() {
        // 监听词典变化，标记需要重新准备
        NotificationCenter.default.addObserver(
            forName: .dictionaryDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isDictionaryPrepared = false
                self?.logger.info("📚 Dictionary changed, will re-prepare on next use")
            }
        }
        
        // 监听训练数据变更，后台触发预编译（仅当模型支持时）
        NotificationCenter.default.addObserver(
            forName: .dictionaryTrainingDataChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                // 检查当前模型是否支持预编译 LM
                if #available(macOS 26.0, *) {
                    let config = TranscriptionModelManager.shared.getProviderConfiguration()
                    guard config.enablePrecompiledLM else {
                        self?.logger.info("📚 训练数据变更，但当前模型不支持预编译 LM，跳过")
                        return
                    }
                }
                self?.logger.notice("📚 训练数据变更，后台预编译 LM...")
                await self?.prepareDictionary()
            }
        }
        
        // 监听模型切换，释放当前 provider
        NotificationCenter.default.addObserver(
            forName: .transcriptionModelChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.logger.notice("🔄 Transcription model changed, releasing provider")
                self?.releaseProvider()
            }
        }
    }
    
    // MARK: - Public API
    
    /// 获取所有可用的引擎信息
    func availableEngines() -> [TranscriptionProviderInfo] {
        var engines: [TranscriptionProviderInfo] = []
        
        // SpeechAnalyzer (macOS 26+)
        if #available(macOS 26.0, *) {
            engines.append(SpeechAnalyzerProvider.info)
        }
        
        // SFSpeechRecognizer (始终可用)
        engines.append(SFSpeechProvider.info)
        
        // TODO: Whisper Local
        
        return engines
    }
    
    /// 获取当前最佳引擎类型
    func bestAvailableEngine() -> TranscriptionEngineType {
        if let forced = forceEngineType {
            return forced
        }
        
        // 优先使用 SpeechAnalyzer (macOS 26+)
        if #available(macOS 26.0, *) {
            return .speechAnalyzer
        }
        
        // 回退到 SFSpeechRecognizer
        return .sfSpeech
    }
    
    /// 创建指定类型的引擎
    func createProvider(type: TranscriptionEngineType) -> TranscriptionProvider? {
        switch type {
        case .speechAnalyzer:
            if #available(macOS 26.0, *) {
                // Use TranscriptionModelManager configuration
                let config = TranscriptionModelManager.shared.getProviderConfiguration()
                let provider = SpeechAnalyzerProvider(config: config)
                logger.info("📍 Created SpeechAnalyzerProvider with model: \(config.modelType.rawValue, privacy: .public), locale: \(config.locale.identifier, privacy: .public), precompiledLM: \(config.enablePrecompiledLM, privacy: .public)")
                return provider
            }
            return nil
            
        case .sfSpeech:
            return SFSpeechProvider(locale: preferredLocale)
            
        case .whisperLocal:
            // TODO: 实现 Whisper 本地引擎
            logger.warning("⚠️ Whisper Local not implemented yet")
            return nil
        }
    }
    
    /// 自动选择并创建最佳引擎
    func createBestProvider() -> TranscriptionProvider {
        let engineType = bestAvailableEngine()
        
        if let provider = createProvider(type: engineType) {
            currentProvider = provider
            currentEngineType = engineType
            
            // 只在 injector 不存在时才创建，避免覆盖已准备好的 injector
            if dictionaryInjector == nil {
                dictionaryInjector = DictionaryInjectorFactory.createInjector(for: engineType)
                logger.info("📚 Created new dictionary injector for \(engineType.displayName)")
            }
            
            // 根据模型类型显示不同的词典状态
            if #available(macOS 26.0, *) {
                let config = TranscriptionModelManager.shared.getProviderConfiguration()
                if config.modelType == .dictation {
                    // DictationTranscriber: 预编译 LM + contextualStrings
                    logger.info("✅ Using engine: \(engineType.displayName) [预编译LM=\(self.isDictionaryPrepared ? "✓" : "✗"), contextualStrings=✓]")
                } else {
                    // SpeechTranscriber: 仅 contextualStrings
                    logger.info("✅ Using engine: \(engineType.displayName) [contextualStrings=✓] (不支持预编译LM)")
                }
            } else {
                logger.info("✅ Using engine: \(engineType.displayName), isDictionaryPrepared=\(self.isDictionaryPrepared)")
            }
            return provider
        }
        
        // 强制回退到 SFSpeech
        let fallback = SFSpeechProvider(locale: preferredLocale)
        currentProvider = fallback
        currentEngineType = .sfSpeech
        
        // 只在 injector 不存在时才创建
        if dictionaryInjector == nil {
            dictionaryInjector = DictionaryInjectorFactory.createInjector(for: .sfSpeech)
        }
        logger.warning("⚠️ Fallback to SFSpeech")
        return fallback
    }
    
    // MARK: - Dictionary Integration
    
    /// 准备词典（异步，可能耗时）
    /// 建议在 App 启动时或设置变更后调用
    func prepareDictionary() async {
        // 检查当前模型是否支持预编译 LM
        if #available(macOS 26.0, *) {
            let config = TranscriptionModelManager.shared.getProviderConfiguration()
            guard config.enablePrecompiledLM else {
                logger.info("📚 [预编译 LM] 当前模型 \(config.modelType.rawValue, privacy: .public) 不支持预编译 LM，跳过")
                return
            }
        }
        
        logger.info("📚 [预编译 LM] 开始准备词典... isDictionaryInjectionEnabled=\(self.isDictionaryInjectionEnabled)")
        
        guard isDictionaryInjectionEnabled else {
            logger.info("📚 Dictionary injection disabled, skipping preparation")
            return
        }
        
        guard let injector = dictionaryInjector else {
            // 如果还没有创建 provider，先创建一个临时的 injector
            logger.info("📚 [预编译 LM] dictionaryInjector 为 nil，创建新的 injector...")
            let engineType = bestAvailableEngine()
            dictionaryInjector = DictionaryInjectorFactory.createInjector(for: engineType)
            guard let injector = dictionaryInjector else {
                logger.error("❌ [预编译 LM] 无法创建 dictionaryInjector")
                return
            }
            await prepareInjector(injector)
            return
        }
        
        await prepareInjector(injector)
    }
    
    private func prepareInjector(_ injector: DictionaryInjector) async {
        // 在主线程获取词典条目
        let entries = await MainActor.run { DictionaryService.shared.activeEntries }
        
        logger.info("📚 [预编译 LM] 获取到词典条目数: \(entries.count)")
        
        guard !entries.isEmpty else {
            logger.info("📚 No dictionary entries, skipping preparation")
            isDictionaryPrepared = true
            return
        }
        
        do {
            logger.info("📚 [预编译 LM] 开始预编译 \(entries.count) 个词条...")
            try await injector.prepare(with: entries)
            isDictionaryPrepared = true
            logger.info("✅ [预编译 LM] 词典准备完成！")
        } catch {
            logger.error("❌ [预编译 LM] 词典预编译失败: \(error.localizedDescription)")
            isDictionaryPrepared = false
        }
    }
    
    /// 检查词典是否需要重新准备
    var needsDictionaryPreparation: Bool {
        guard isDictionaryInjectionEnabled else { return false }
        guard let injector = dictionaryInjector else { return true }
        return !isDictionaryPrepared || injector.needsRePrepare
    }
    
    /// 请求所有必要权限
    func requestPermissions() async -> Bool {
        // 麦克风权限
        let micGranted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
        
        guard micGranted else {
            logger.warning("⚠️ Microphone permission denied")
            return false
        }
        
        // 语音识别权限 (通过 provider 请求)
        let provider = createBestProvider()
        let speechGranted = await provider.requestAuthorization()
        
        guard speechGranted else {
            logger.warning("⚠️ Speech recognition permission denied")
            return false
        }
        
        logger.info("✅ All permissions granted")
        return true
    }
    
    /// 获取当前引擎状态描述
    func engineStatusDescription() -> String {
        guard let type = currentEngineType else {
            return "未初始化"
        }
        
        let available = currentProvider?.isAvailable ?? false
        let status = available ? "可用" : "不可用"
        
        return "\(type.displayName) - \(status)"
    }
    
    /// 释放当前引擎
    func releaseProvider() {
        currentProvider?.reset()
        currentProvider = nil
        currentEngineType = nil
        logger.info("🔄 Provider released")
    }
}

// MARK: - Debug

extension TranscriptionManager {
    /// 打印调试信息 (使用 logger.debug，仅在调试时可见)
    func printDebugInfo() {
        #if DEBUG
        logger.debug("=== TranscriptionManager ===")
        logger.debug("Best Engine: \(self.bestAvailableEngine().displayName)")
        logger.debug("Current Engine: \(self.currentEngineType?.displayName ?? "None")")
        logger.debug("macOS 26+ Available: \(SpeechAnalyzerAvailability.isSupported)")
        #endif
    }
}
