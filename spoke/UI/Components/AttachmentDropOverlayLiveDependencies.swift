import Foundation

@MainActor
struct AttachmentDropHandlerDependencies {
    let attachmentManager: AttachmentManager
}

@MainActor
extension AttachmentDropHandlerDependencies {
    static let live = Self(attachmentManager: .shared)
}
