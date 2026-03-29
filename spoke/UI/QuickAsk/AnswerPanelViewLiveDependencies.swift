import AppKit
import Foundation

@MainActor
extension AnswerPanelViewDependencies {
    static let live = AnswerPanelViewDependencies(
        workflowState: .shared,
        ttsService: .shared,
        ttsSettings: .shared,
        messageBubbleDependencies: .live,
        inputDependencies: .live,
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

@MainActor
extension AnswerPanelInputDependencies {
    static let live = AnswerPanelInputDependencies(
        addImage: { image, onAdd in
            AttachmentManager.shared.addImage(image, source: .paste, onAdd: onAdd)
        },
        handleDrop: { providers, onAdd in
            AttachmentManager.shared.handleDrop(providers: providers, onAdd: onAdd)
        }
    )
}
