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

// MARK: - User Settings

/// User's transcription model settings
/// This is persisted to UserDefaults
struct TranscriptionModelUserSettings: Codable, Equatable {
    /// Currently selected model ID
    var selectedModelId: String
    
    /// Per-model settings, keyed by model ID
    var perModelSettings: [String: PerModelSettings]
    
    /// Default settings for new users
    static let `default` = TranscriptionModelUserSettings(
        selectedModelId: TranscriptionModelDefinition.defaultModelId,
        perModelSettings: [:]
    )
    
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
