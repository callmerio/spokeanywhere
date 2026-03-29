import Foundation

@MainActor
struct AttachmentImageCacheDependencies {
    let storage: CardAttachmentStorage
}

@MainActor
extension AttachmentImageCacheDependencies {
    static let live = Self(storage: .shared)
}
