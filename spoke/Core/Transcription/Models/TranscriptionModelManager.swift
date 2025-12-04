import Foundation
import os
import Speech

/// Manages transcription model selection and settings
@MainActor
@Observable
final class TranscriptionModelManager {
    
    // MARK: - Singleton
    
    static let shared = TranscriptionModelManager()
    
    // MARK: - Properties
    
    /// User settings (persisted)
    private(set) var settings: TranscriptionModelUserSettings {
        didSet { save() }
    }
    
    /// Download states for each model
    private(set) var downloadStates: [String: ModelDownloadState] = [:]
    
    // MARK: - Private
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "TranscriptionModelManager")
    private let defaults = UserDefaults.standard
    private let settingsKey = "transcription.modelSettings"
    
    // MARK: - Init
    
    private init() {
        self.settings = Self.load(from: defaults, key: settingsKey)
        initializeDownloadStates()
        logger.info("✅ TranscriptionModelManager initialized, selected: \(self.settings.selectedModelId, privacy: .public)")
    }
    
    // MARK: - Public API
    
    /// All available models (including coming soon)
    var allModels: [TranscriptionModelDefinition] {
        TranscriptionModelDefinition.allModels
    }
    
    /// Models that are currently available for use
    var availableModels: [TranscriptionModelDefinition] {
        allModels.filter { $0.isAvailable }
    }
    
    /// Currently selected model
    var selectedModel: TranscriptionModelDefinition? {
        settings.selectedModel
    }
    
    /// Current model settings
    var currentModelSettings: PerModelSettings {
        settings.currentSettings
    }
    
    /// Select a model
    func selectModel(_ modelId: String) {
        guard TranscriptionModelDefinition.find(by: modelId) != nil else {
            logger.warning("⚠️ Attempted to select unknown model: \(modelId)")
            return
        }
        
        if settings.selectedModelId != modelId {
            settings.selectedModelId = modelId
            logger.info("📍 Selected model: \(modelId, privacy: .public)")
            
            NotificationCenter.default.post(
                name: .transcriptionModelChanged,
                object: nil,
                userInfo: ["modelId": modelId]
            )
        }
    }
    
    /// Update settings for a specific model (with change detection)
    func updateSettings(for modelId: String, _ update: (inout PerModelSettings) -> Void) {
        let oldSettings = settings.settings(for: modelId)
        var newSettings = oldSettings
        update(&newSettings)
        
        // Only save if actually changed
        guard newSettings != oldSettings else { return }
        
        settings.perModelSettings[modelId] = newSettings
        logger.info("📝 Updated settings for model: \(modelId, privacy: .public)")
    }
    
    /// Update locale for current model
    func setLocale(_ locale: String) {
        updateSettings(for: settings.selectedModelId) { s in
            s.locale = locale
        }
    }
    
    /// Toggle precompiled LM for current model
    func setPrecompiledLMEnabled(_ enabled: Bool) {
        updateSettings(for: settings.selectedModelId) { s in
            s.enablePrecompiledLM = enabled
        }
    }
    
    /// Get download state for a model
    func downloadState(for modelId: String) -> ModelDownloadState {
        downloadStates[modelId] ?? .notNeeded
    }
    
    /// Check if a model is ready to use
    func isModelReady(_ modelId: String) -> Bool {
        guard let model = TranscriptionModelDefinition.find(by: modelId) else {
            return false
        }
        
        if !model.isAvailable {
            return false
        }
        
        switch model.source {
        case .builtin:
            return true
        case .api:
            return true // API availability checked elsewhere
        case .download:
            return downloadState(for: modelId).isReady
        }
    }
    
    /// Check SpeechTranscriber model availability
    func checkSpeechTranscriberAvailability() async -> Bool {
        guard #available(macOS 26, *) else {
            return false
        }
        return SpeechTranscriber.isAvailable
    }
    
    /// "Download" a model
    /// Note: For SpeechTranscriber, Apple handles download automatically via AssetInventory
    /// This method just checks availability and marks state accordingly
    func downloadModel(_ modelId: String) async {
        guard let model = TranscriptionModelDefinition.find(by: modelId),
              model.source == .download else {
            return
        }
        
        logger.info("📥 Checking model availability: \(modelId, privacy: .public)")
        downloadStates[modelId] = .downloading(progress: 0)
        
        // For SpeechTranscriber: system manages download via AssetInventory
        // We just need to check SpeechTranscriber.isAvailable
        if modelId == TranscriptionModelDefinition.appleSpeechTranscriber.id {
            let isAvailable = await checkSpeechTranscriberAvailability()
            if isAvailable {
                downloadStates[modelId] = .downloaded
                updateSettings(for: modelId) { s in
                    s.isDownloaded = true
                }
                logger.info("✅ SpeechTranscriber is available (system managed)")
            } else {
                // Model not yet available, system will download when needed
                downloadStates[modelId] = .notDownloaded
                logger.notice("⏳ SpeechTranscriber not yet available, system will download on first use")
            }
            return
        }
        
        // FIXME: Implement actual download for Whisper Local when ready
        // For now, mock the download process
        do {
            try await Task.sleep(for: .seconds(1))
            downloadStates[modelId] = .downloaded
            updateSettings(for: modelId) { s in
                s.isDownloaded = true
            }
            logger.info("✅ Model downloaded (mock): \(modelId)")
        } catch {
            downloadStates[modelId] = .failed(error: error.localizedDescription)
            logger.error("❌ Failed to download model: \(modelId), error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Configuration for Provider
    
    /// Get the configuration needed by TranscriptionProvider
    func getProviderConfiguration() -> TranscriptionProviderConfig {
        guard let model = selectedModel else {
            return TranscriptionProviderConfig(
                modelType: .dictation,
                locale: Locale(identifier: TranscriptionDefaults.locale),
                enablePrecompiledLM: true,
                enableContextualStrings: true
            )
        }
        
        let perSettings = settings.settings(for: model.id)
        
        return TranscriptionProviderConfig(
            modelType: model.type,
            locale: Locale(identifier: perSettings.locale),
            enablePrecompiledLM: model.supportsPrecompiledLM && perSettings.enablePrecompiledLM,
            enableContextualStrings: model.supportsContextualStrings
        )
    }
    
    // MARK: - Private
    
    private func initializeDownloadStates() {
        for model in allModels {
            switch model.source {
            case .builtin, .api:
                downloadStates[model.id] = .notNeeded
            case .download:
                let perSettings = settings.settings(for: model.id)
                downloadStates[model.id] = perSettings.isDownloaded ? .downloaded : .notDownloaded
            }
        }
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(settings)
            defaults.set(data, forKey: settingsKey)
            logger.debug("💾 Settings saved")
        } catch {
            logger.error("❌ Failed to save settings: \(error.localizedDescription)")
        }
    }
    
    private static func load(from defaults: UserDefaults, key: String) -> TranscriptionModelUserSettings {
        guard let data = defaults.data(forKey: key) else {
            return .default
        }
        
        do {
            return try JSONDecoder().decode(TranscriptionModelUserSettings.self, from: data)
        } catch {
            Logger(subsystem: "com.spokeanywhere", category: "TranscriptionModelManager")
                .warning("⚠️ Failed to decode settings, using defaults: \(error.localizedDescription)")
            return .default
        }
    }
}

// MARK: - Provider Configuration

/// Configuration passed to TranscriptionProvider
struct TranscriptionProviderConfig {
    let modelType: TranscriptionModelType
    let locale: Locale
    let enablePrecompiledLM: Bool
    let enableContextualStrings: Bool
}

// MARK: - Notifications

extension Notification.Name {
    static let transcriptionModelChanged = Notification.Name("transcriptionModelChanged")
}
