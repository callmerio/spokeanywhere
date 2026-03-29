import AppKit

struct AttachmentThumbnailViewDependencies {
    let fileIcon: (String) -> NSImage
    let makeVideoThumbnail: (URL) -> NSImage?
}

@MainActor
extension AttachmentThumbnailViewDependencies {
    static let live = AttachmentThumbnailViewDependencies(
        fileIcon: { NSWorkspace.shared.icon(forFile: $0) },
        makeVideoThumbnail: { Attachment.makeVideoThumbnail(from: $0) }
    )
}

func runAttachmentThumbnailLoad(
    url: URL,
    dependencies: AttachmentThumbnailViewDependencies,
    update: @escaping @MainActor (NSImage?) -> Void
) {
    runtimeRunAsync {
        let thumbnail = await runtimeRunDetachedAsync(priority: .userInitiated) {
            dependencies.makeVideoThumbnail(url)
        }
        await MainActor.run {
            update(thumbnail)
        }
    }
}
