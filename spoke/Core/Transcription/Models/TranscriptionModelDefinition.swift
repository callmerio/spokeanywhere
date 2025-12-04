import Foundation

// MARK: - Defaults

enum TranscriptionDefaults {
    static let locale = "zh-Hans"
}

// MARK: - Accuracy/Speed Rating

enum TranscriptionRating: Int, Codable {
    case low = 1
    case belowAverage = 2
    case average = 3
    case good = 4
    case excellent = 5
}

// MARK: - Model Type

/// Transcription engine type
enum TranscriptionModelType: String, Codable, CaseIterable {
    /// Apple DictationTranscriber - built-in, supports precompiled LM
    case dictation
    /// Apple SpeechTranscriber - stronger model, requires download (~2GB)
    case speechTranscriber
    /// OpenAI Whisper API - cloud processing
    case whisperAPI
    /// whisper.cpp - local CoreML model
    case whisperLocal
}

// MARK: - Model Source

/// Where the model comes from
enum TranscriptionModelSource: String, Codable {
    /// Built into the system, no download needed
    case builtin
    /// Requires model download
    case download
    /// Cloud API, requires network
    case api
}

// MARK: - Model Definition (Static)

/// Static definition of a transcription model
/// These are predefined and do not change at runtime
struct TranscriptionModelDefinition: Identifiable, Codable, Equatable {
    let id: String
    let type: TranscriptionModelType
    let source: TranscriptionModelSource
    
    /// Download size in MB, nil if built-in or cloud
    let downloadSizeMB: Int?
    
    /// Default locale for this model
    let defaultLocale: String
    
    /// All supported locales, use ["multilingual"] for models that support all
    let supportedLocales: [String]
    
    /// Accuracy rating
    let accuracy: TranscriptionRating
    
    /// Speed rating
    let speed: TranscriptionRating
    
    // MARK: - Capabilities
    
    /// Whether this model supports contextualStrings injection
    let supportsContextualStrings: Bool
    
    /// Whether this model supports precompiled language model
    let supportsPrecompiledLM: Bool
    
    /// Whether this model supports multiple languages in one session
    let supportsMultilingual: Bool
    
    /// Whether this model supports streaming output (required for live caption)
    let supportsStreaming: Bool
    
    // MARK: - Availability
    
    /// Whether this model is currently available for use
    let isAvailable: Bool
    
    /// Whether to show "Coming Soon" badge
    let isComingSoon: Bool
    
    /// Minimum OS version required, e.g., "macOS 26"
    let minimumOS: String?
}

// MARK: - Default Models

extension TranscriptionModelDefinition {
    
    /// All available model definitions
    static let allModels: [TranscriptionModelDefinition] = [
        appleDictation,
        appleSpeechTranscriber,
        openAIWhisper,
        whisperLocal
    ]
    
    /// Default model ID for new users
    static let defaultModelId = "apple-dictation"
    
    /// Find model by ID
    static func find(by id: String) -> TranscriptionModelDefinition? {
        allModels.first { $0.id == id }
    }
    
    // MARK: - Model Definitions
    
    /// Apple Dictation - built-in, supports precompiled LM
    static let appleDictation = TranscriptionModelDefinition(
        id: "apple-dictation",
        type: .dictation,
        source: .builtin,
        downloadSizeMB: nil,
        defaultLocale: "zh-Hans",
        supportedLocales: [
            "zh-Hans", "zh-Hant", "en-US", "en-GB", "en-AU",
            "ja-JP", "ko-KR", "de-DE", "fr-FR", "es-ES", "it-IT", "pt-BR"
        ],
        accuracy: .average,
        speed: .good,
        supportsContextualStrings: true,
        supportsPrecompiledLM: true,
        supportsMultilingual: false,
        supportsStreaming: true,  // ✅ 支持流式输出
        isAvailable: true,
        isComingSoon: false,
        minimumOS: nil
    )
    
    /// Apple SpeechTranscriber - stronger model, requires download
    static let appleSpeechTranscriber = TranscriptionModelDefinition(
        id: "apple-speech-transcriber",
        type: .speechTranscriber,
        source: .download,
        downloadSizeMB: 2100,
        defaultLocale: "zh-Hans",
        supportedLocales: [
            "zh-Hans", "en-US", "ja-JP", "de-DE", "fr-FR", "es-ES"
        ],
        accuracy: .excellent,
        speed: .excellent,
        supportsContextualStrings: true,
        supportsPrecompiledLM: false,
        supportsMultilingual: true,
        supportsStreaming: true,  // ✅ 支持流式输出
        isAvailable: true,
        isComingSoon: false,
        minimumOS: "macOS 26"
    )
    
    /// OpenAI Whisper API - cloud processing (Coming Soon)
    static let openAIWhisper = TranscriptionModelDefinition(
        id: "openai-whisper",
        type: .whisperAPI,
        source: .api,
        downloadSizeMB: nil,
        defaultLocale: "multilingual",
        supportedLocales: ["multilingual"],
        accuracy: .excellent,
        speed: .average,
        supportsContextualStrings: false,
        supportsPrecompiledLM: false,
        supportsMultilingual: true,
        supportsStreaming: false,  // ❌ 不支持流式输出
        isAvailable: false,
        isComingSoon: true,
        minimumOS: nil
    )
    
    /// Whisper.cpp Local - CoreML model (Coming Soon)
    static let whisperLocal = TranscriptionModelDefinition(
        id: "whisper-local",
        type: .whisperLocal,
        source: .download,
        downloadSizeMB: 547,
        defaultLocale: "multilingual",
        supportedLocales: ["multilingual"],
        accuracy: .good,
        speed: .average,
        supportsContextualStrings: false,
        supportsPrecompiledLM: false,
        supportsMultilingual: true,
        supportsStreaming: false,  // ❌ 不支持流式输出
        isAvailable: false,
        isComingSoon: true,
        minimumOS: nil
    )
}

// MARK: - Convenience

extension TranscriptionModelDefinition {
    
    /// Whether language selection is needed
    /// 只有真正的 "multilingual" 模型（如 Whisper）不需要选择语言
    /// SpeechTranscriber 虽然支持多语言，但仍需指定一个主语言
    var needsLanguageSelection: Bool {
        supportedLocales.first != "multilingual"
    }
    
    /// Whether this model requires download before use
    var requiresDownload: Bool {
        source == .download
    }
    
    /// Human-readable size string
    var sizeString: String? {
        guard let size = downloadSizeMB else { return nil }
        if size >= 1024 {
            return String(format: "%.1f GB", Double(size) / 1024.0)
        }
        return "\(size) MB"
    }
}

// MARK: - UI Display

extension TranscriptionModelDefinition {
    
    /// 模型显示名称
    var displayName: String {
        switch type {
        case .dictation:
            return "Apple Dictation"
        case .speechTranscriber:
            return "Apple SpeechTranscriber"
        case .whisperAPI:
            return "OpenAI Whisper"
        case .whisperLocal:
            return "Whisper.cpp Local"
        }
    }
    
    /// 模型副标题描述
    var subtitle: String {
        switch type {
        case .dictation:
            return "系统内置，离线可用，支持自定义词典"
        case .speechTranscriber:
            return "更强模型，更好的多语言支持"
        case .whisperAPI:
            return "云端处理，高精度"
        case .whisperLocal:
            return "本地 CoreML 模型，完全离线"
        }
    }
    
    /// 模型图标名称 (SF Symbols)
    var iconName: String {
        switch type {
        case .dictation:
            return "apple.logo"
        case .speechTranscriber:
            return "waveform.badge.magnifyingglass"
        case .whisperAPI:
            return "cloud"
        case .whisperLocal:
            return "cpu"
        }
    }
}
