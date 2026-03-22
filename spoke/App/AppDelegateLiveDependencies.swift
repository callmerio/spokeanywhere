import Foundation

@MainActor
extension AppDelegateDependencies {
    static func makeLive() -> Self {
        .init(
            notificationCenter: .default,
            hotKeyService: .shared,
            screenshotManager: .shared,
            dictionaryPanelManager: .shared,
            debugAutomationTrigger: .shared,
            recordingController: .shared,
            liveCaptionWindowManager: .shared,
            selectionActionService: .shared,
            appSettings: .shared,
            selectionToolbarManager: .shared,
            trackpadSwipeService: .shared,
            messagePanelManager: .shared,
            historyManager: .shared,
            resourceMonitor: .shared,
            clipboardHistoryService: .shared,
            transcriptionModelManager: .shared,
            transcriptionManager: .shared,
            crashLogger: .shared
        )
    }
}
