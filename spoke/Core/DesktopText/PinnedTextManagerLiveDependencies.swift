import AppKit
import Foundation

@MainActor
extension PinnedTextManagerDependencies {
    static let live = PinnedTextManagerDependencies(
        pasteboardText: { currentServiceContainer().pasteboard.string(forType: .string) },
        storageRootDirectory: {
            if let override = ProcessInfo.processInfo.environment["SPOKE_PINNED_TEXT_BASE_DIR"], !override.isEmpty {
                return URL(fileURLWithPath: override, isDirectory: true)
            }
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            return appSupport.appendingPathComponent("Spoke", isDirectory: true)
        },
        beep: {
            NSSound.beep()
        }
    )
}
