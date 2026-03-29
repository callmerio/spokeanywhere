import Foundation

@MainActor
extension TranscriptionModelSettingsDependencies {
    static let live = TranscriptionModelSettingsDependencies(
        modelManager: .shared,
        downloadModel: { modelId in
            runTranscriptionModelSettingsDownload(
                manager: .shared,
                modelId: modelId
            )
        }
    )
}
