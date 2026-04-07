import AppKit
import Foundation

@MainActor
extension AnswerPanelViewDependencies {
    static let live = AnswerPanelViewDependencies(
        workflowState: currentServiceContainer().workflowState,
        ttsService: currentServiceContainer().ttsService,
        ttsSettings: currentServiceContainer().ttsSettings,
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
        ttsService: currentServiceContainer().ttsService
    )
}

@MainActor
extension AnswerPanelInputDependencies {
    static let live = AnswerPanelInputDependencies(
        addImage: { image, onAdd in
            currentServiceContainer().attachmentManager.addImage(image, source: .paste, onAdd: onAdd)
        },
        handleDrop: { providers, onAdd in
            currentServiceContainer().attachmentManager.handleDrop(providers: providers, onAdd: onAdd)
        }
    )
}
