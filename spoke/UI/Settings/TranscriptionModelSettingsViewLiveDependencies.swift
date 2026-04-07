import Foundation

@MainActor
extension TranscriptionModelSettingsDependencies {
    static let live = TranscriptionModelSettingsDependencies(
        modelManager: currentServiceContainer().transcriptionModelManager,
        downloadModel: { modelId in
            runTranscriptionModelSettingsDownload(
                manager: currentServiceContainer().transcriptionModelManager,
                modelId: modelId
            )
        }
    )
}
