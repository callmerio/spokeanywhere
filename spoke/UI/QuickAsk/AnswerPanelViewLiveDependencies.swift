import AppKit
import Foundation

@MainActor
extension AnswerPanelViewDependencies {
    static let live = AnswerPanelViewDependencies(
        workflowState: .shared,
        ttsService: .shared,
        ttsSettings: .shared,
        messageBubbleDependencies: .live,
        openSettings: {
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.openSettings()
            }
        }
    )
}

@MainActor
extension MessageBubbleViewDependencies {
    static let live = MessageBubbleViewDependencies(
        ttsService: .shared
    )
}
