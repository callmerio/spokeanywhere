import Foundation

@MainActor
struct AttachmentPickerMenuDependencies {
    let attachmentManager: AttachmentManager
}

@MainActor
extension AttachmentPickerMenuDependencies {
    static let live = Self(attachmentManager: .shared)
}
