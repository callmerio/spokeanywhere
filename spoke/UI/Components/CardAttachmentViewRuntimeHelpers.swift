import AppKit

func runCardAttachmentThumbnailLoad(
    attachment: CardAttachment,
    maxWidth: CGFloat,
    dependencies: CardAttachmentViewDependencies,
    update: @escaping @MainActor (NSImage?) -> Void
) {
    Task { @MainActor in
        update(
            dependencies.imageCache.thumbnail(
                for: attachment,
                maxSize: maxWidth * 2
            )
        )
    }
}
