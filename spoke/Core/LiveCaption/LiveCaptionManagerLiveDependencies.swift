import Foundation

@MainActor
extension LiveCaptionManagerDependencies {
    static let preview = LiveCaptionManagerDependencies(
        translator: .makePreview(),
        makeAppCaptureService: { .shared },
        makeSystemCaptureService: { .shared },
        transcriptionModelManager: .shared,
        dictionaryService: .shared,
        postTranslationUpdate: {}
    )

    static let live = LiveCaptionManagerDependencies(
        translator: .shared,
        makeAppCaptureService: { .shared },
        makeSystemCaptureService: { .shared },
        transcriptionModelManager: .shared,
        dictionaryService: .shared,
        postTranslationUpdate: {
            NotificationCenter.default.post(name: .translationUpdated, object: nil)
        }
    )
}
