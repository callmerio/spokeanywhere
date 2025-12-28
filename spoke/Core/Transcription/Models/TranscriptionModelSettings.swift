import Foundation

// MARK: - Per-Model Settings

/// User settings for a specific model
struct PerModelSettings: Codable, Equatable {
    /// Selected locale for this model
    var locale: String
    
    /// Whether to enable precompiled LM (only effective if model supports it)
    var enablePrecompiledLM: Bool
    
    /// Whether the model has been downloaded (for downloadable models)
    var isDownloaded: Bool
    
    /// Default settings for a model
    static func defaultSettings(for model: TranscriptionModelDefinition) -> PerModelSettings {
        PerModelSettings(
            locale: model.defaultLocale,
            enablePrecompiledLM: model.supportsPrecompiledLM,
            isDownloaded: model.source != .download
        )
    }
}

// MARK: - Model Role

/// 模型角色
enum TranscriptionModelRole: String, Codable, CaseIterable {
    /// 转录模型（录音→文字，一次性处理）
    case transcription
    /// 实时字幕模型（流式输出，需要 supportsStreaming）
    case liveCaption
    
    var displayName: String {
        switch self {
        case .transcription: return "转录"
        case .liveCaption: return "字幕"
        }
    }
    
    var icon: String {
        switch self {
        case .transcription: return "waveform"
        case .liveCaption: return "captions.bubble"
        }
    }
    
    // swiftlint:disable:next large_tuple
    var badgeColor: (red: Double, green: Double, blue: Double) {
        switch self {
        case .transcription: return (0.9, 0.3, 0.3)  // 红色
        case .liveCaption: return (0.3, 0.7, 0.4)    // 绿色
        }
    }
}

// MARK: - User Settings

/// User's transcription model settings
/// This is persisted to UserDefaults
struct TranscriptionModelUserSettings: Codable, Equatable {
    /// Currently selected model ID (legacy, for backward compatibility)
    var selectedModelId: String
    
    /// 转录模型 ID（录音→文字）
    var transcriptionModelId: String
    
    /// 实时字幕模型 ID（流式输出）
    var liveCaptionModelId: String
    
    /// Per-model settings, keyed by model ID
    var perModelSettings: [String: PerModelSettings]
    
    /// Default settings for new users
    /// 字幕默认使用 SpeechTranscriber（英语），避免与中文转录冲突
    static let `default` = TranscriptionModelUserSettings(
        selectedModelId: TranscriptionModelDefinition.defaultModelId,
        transcriptionModelId: TranscriptionModelDefinition.defaultModelId,
        liveCaptionModelId: TranscriptionModelDefinition.appleSpeechTranscriber.id,  // 字幕默认英语模型
        perModelSettings: [:]
    )
    
    /// 兼容旧版本：如果新字段为空，使用 selectedModelId
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedModelId = try container.decode(String.self, forKey: .selectedModelId)
        transcriptionModelId = try container.decodeIfPresent(String.self, forKey: .transcriptionModelId) ?? selectedModelId
        liveCaptionModelId = try container.decodeIfPresent(String.self, forKey: .liveCaptionModelId) ?? selectedModelId
        perModelSettings = try container.decodeIfPresent([String: PerModelSettings].self, forKey: .perModelSettings) ?? [:]
    }
    
    init(selectedModelId: String, transcriptionModelId: String, liveCaptionModelId: String, perModelSettings: [String: PerModelSettings]) {
        self.selectedModelId = selectedModelId
        self.transcriptionModelId = transcriptionModelId
        self.liveCaptionModelId = liveCaptionModelId
        self.perModelSettings = perModelSettings
    }
    
    // MARK: - Convenience
    
    /// Get settings for a specific model, creating defaults if needed
    func settings(for modelId: String) -> PerModelSettings {
        if let settings = perModelSettings[modelId] {
            return settings
        }
        guard let model = TranscriptionModelDefinition.find(by: modelId) else {
            return PerModelSettings(locale: TranscriptionDefaults.locale, enablePrecompiledLM: false, isDownloaded: false)
        }
        return PerModelSettings.defaultSettings(for: model)
    }
    
    /// Get the currently selected model definition
    var selectedModel: TranscriptionModelDefinition? {
        TranscriptionModelDefinition.find(by: selectedModelId)
    }
    
    /// Get settings for the currently selected model
    var currentSettings: PerModelSettings {
        settings(for: selectedModelId)
    }
    
    // MARK: - Role-based Access
    
    /// 获取指定角色的模型 ID
    func modelId(for role: TranscriptionModelRole) -> String {
        switch role {
        case .transcription: return transcriptionModelId
        case .liveCaption: return liveCaptionModelId
        }
    }
    
    /// 获取指定角色的模型定义
    func model(for role: TranscriptionModelRole) -> TranscriptionModelDefinition? {
        TranscriptionModelDefinition.find(by: modelId(for: role))
    }
    
    /// 检查模型是否担任某个角色
    func roles(for modelId: String) -> [TranscriptionModelRole] {
        var result: [TranscriptionModelRole] = []
        if transcriptionModelId == modelId { result.append(.transcription) }
        if liveCaptionModelId == modelId { result.append(.liveCaption) }
        return result
    }
}

// MARK: - Download State

/// Model download state
enum ModelDownloadState: Equatable {
    case notNeeded          // Built-in or cloud model
    case notDownloaded      // Needs download
    case downloading(progress: Double)
    case downloaded         // Ready to use
    case failed(error: String)
    
    var isReady: Bool {
        switch self {
        case .notNeeded, .downloaded:
            return true
        default:
            return false
        }
    }
}
