import AppKit
import Foundation

@MainActor
extension AnswerPanelViewDependencies {
    static let live = AnswerPanelViewDependencies(
        workflowState: .shared,
        ttsService: .shared,
        ttsSettings: .shared,
        openSettings: {
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.openSettings()
            }
        }
    )
}

