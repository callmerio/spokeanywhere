import Foundation

@MainActor
struct AttachmentManagerDependencies {
    let textExtractor: TextExtractionService
    let screenCapture: ScreenCaptureService

    static let preview = AttachmentManagerDependencies(
        textExtractor: .shared,
        screenCapture: .shared
    )
}

@MainActor
extension AttachmentManagerDependencies {
    static let live = AttachmentManagerDependencies(
        textExtractor: .shared,
        screenCapture: .shared
    )
}
