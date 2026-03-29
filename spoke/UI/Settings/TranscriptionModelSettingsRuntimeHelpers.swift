import Foundation

func runTranscriptionModelSettingsDownload(
    manager: TranscriptionModelManager,
    modelId: String
) {
    runtimeRunOnMainAsync {
        await manager.downloadModel(modelId)
    }
}
