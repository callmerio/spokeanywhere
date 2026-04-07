import AppKit
import Foundation

@MainActor
extension CardAttachmentViewDependencies {
    static let live = CardAttachmentViewDependencies(
        imageCache: currentServiceContainer().attachmentImageCache,
        removeAttachment: { attachmentId, cardId in
            currentServiceContainer().messagePanelState.removeAttachment(attachmentId, from: cardId)
        },
        copyImage: { image in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
        },
        saveImageToDesktop: { image, attachmentId in
            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else { return }

            let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            let fileName = "attachment_\(attachmentId.uuidString.prefix(8)).png"
            let fileURL = desktopURL.appendingPathComponent(fileName)
            try? pngData.write(to: fileURL)
        }
    )
}
