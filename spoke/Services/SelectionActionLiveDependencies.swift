import AppKit
import Foundation

private enum SelectionActionLiveDefaults {
    static let autoHideDelay: TimeInterval = 0.5
}

@MainActor
extension SelectionActionServiceDependencies {
    static func makeLive() -> Self {
        let services = SelectionActionLiveServices.shared
        return SelectionActionServiceDependencies(
            state: services.state,
            ttsService: services.ttsService,
            screenOCR: services.screenOCR,
            llmPipeline: services.llmPipeline,
            dictionaryAPI: services.dictionaryAPI,
            selectionToolbarManager: services.selectionToolbarManager,
            answerPanelManager: services.answerPanelManager,
            llmSettings: services.llmSettings,
            notificationCenter: .default,
            copyText: { text in
                copySelectionActionTextToPasteboard(text)
            },
            scheduleToolbarHide: { [selectionToolbarManager = services.selectionToolbarManager] in
                scheduleSelectionActionToolbarHide(
                    selectionToolbarManager,
                    delay: SelectionActionLiveDefaults.autoHideDelay
                )
            }
        )
    }
}
