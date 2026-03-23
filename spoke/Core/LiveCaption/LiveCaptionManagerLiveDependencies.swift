import Foundation

@MainActor
extension LiveCaptionManagerDependencies {
    static let preview = LiveCaptionManagerDependencies(
        translator: .makePreview(),
        appCaptureService: .shared,
        systemCaptureService: .shared,
        transcriptionModelManager: .shared,
        dictionaryService: .shared,
        postTranslationUpdate: {}
    )

    static let live = LiveCaptionManagerDependencies(
        translator: .shared,
        appCaptureService: .shared,
        systemCaptureService: .shared,
        transcriptionModelManager: .shared,
        dictionaryService: .shared,
        postTranslationUpdate: {
            NotificationCenter.default.post(name: .translationUpdated, object: nil)
        }
    )
}

