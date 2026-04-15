import AppKit
import Foundation

@MainActor
extension PinnedTextManagerDependencies {
    static let live = PinnedTextManagerDependencies(
        pasteboardText: { currentServiceContainer().pasteboard.string(forType: .string) },
        storageRootDirectory: {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            return appSupport.appendingPathComponent("Spoke", isDirectory: true)
        },
        beep: {
            NSSound.beep()
        }
    )
}
