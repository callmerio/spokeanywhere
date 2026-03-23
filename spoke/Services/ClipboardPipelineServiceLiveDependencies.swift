import AppKit
import Foundation

@MainActor
extension ClipboardPipelineServiceDependencies {
    static let live = ClipboardPipelineServiceDependencies(
        messagePanelManager: { .shared },
        currentSourceApp: { SourceAppInfo.fromFrontmost() },
        pasteboardText: { NSPasteboard.general.string(forType: .string) }
    )
}

