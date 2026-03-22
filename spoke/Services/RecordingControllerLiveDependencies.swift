import AppKit
import Foundation

@MainActor
extension RecordingControllerDependencies {
    static func makeLive() -> Self {
        .init(
            hudManager: .shared,
            contextService: .shared,
            hotKeyService: .shared,
            audioService: .shared,
            inputService: .shared,
            settings: .shared,
            llmSettings: .shared,
            llmPipeline: .shared,
            historyManager: .shared,
            quickAskService: .shared,
            screenOCR: .shared,
            messagePanelManager: .shared,
            liveCaptionWindowManager: .shared,
            clipboardPipelineService: .shared,
            copyToClipboard: { text in
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
            },
            openSettings: {
                if !NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil) {
                    assertionFailure("AppDelegate should handle openSettings via responder chain")
                }
            }
        )
    }
}
