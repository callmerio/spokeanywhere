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
    
    /// 首选语言
    var preferredLocale: Locale = Locale(identifier: "zh-CN")
    
    /// 是否强制使用特定引擎（用于测试/调试）
    var forceEngineType: TranscriptionEngineType?
    
    // MARK: - Init
    
    private init() {}
    
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
                return SpeechAnalyzerProvider(locale: preferredLocale)
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
            logger.info("✅ Using engine: \(engineType.displayName)")
            return provider
        }
        
        // 强制回退到 SFSpeech
        let fallback = SFSpeechProvider(locale: preferredLocale)
        currentProvider = fallback
        currentEngineType = .sfSpeech
        logger.warning("⚠️ Fallback to SFSpeech")
        return fallback
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
    /// 打印调试信息
    func printDebugInfo() {
        print("=== TranscriptionManager Debug ===")
        print("Best Engine: \(bestAvailableEngine().displayName)")
        print("Current Engine: \(currentEngineType?.displayName ?? "None")")
        print("Available Engines:")
        for engine in availableEngines() {
            print("  - \(engine.displayName) (\(engine.minOSVersion)): \(engine.isAvailable ? "✅" : "❌")")
        }
        print("macOS 26+ Available: \(SpeechAnalyzerAvailability.isSupported)")
        print("==================================")
    }
}
