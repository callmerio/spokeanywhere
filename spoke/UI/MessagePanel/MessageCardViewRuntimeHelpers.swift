import AppKit
import Foundation

func runMessageCardImageDrop(
    provider: NSItemProvider,
    cardId: UUID,
    addAttachment: @escaping @MainActor (NSImage, UUID) -> Void
) {
    _ = provider.loadObject(ofClass: NSImage.self) { image, _ in
        guard let image = image as? NSImage else { return }
        runtimeRunOnMain {
            addAttachment(image, cardId)
        }
    }
}

func runMessageCardFileDrop(
    provider: NSItemProvider,
    cardId: UUID,
    addAttachment: @escaping @MainActor (NSImage, UUID) -> Void
) {
    provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
        guard let data = data as? Data,
              let url = URL(dataRepresentation: data, relativeTo: nil),
              let image = NSImage(contentsOf: url) else {
            return
        }
        runtimeRunOnMain {
            addAttachment(image, cardId)
        }
    }
}

func runMessageCardCopyFeedback(
    resetScale: @escaping @MainActor () -> Void,
    hideCopied: @escaping @MainActor () -> Void
) {
    Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(150))
        resetScale()

        try? await Task.sleep(for: .milliseconds(1200))
        hideCopied()
    }
}
