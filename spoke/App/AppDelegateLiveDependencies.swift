import Foundation

@MainActor
extension AppDelegateDependencies {
    static func makeLive() -> Self {
        let services = currentServiceContainer()
        return .init(
            notificationCenter: .default,
            hotKeyService: services.hotKeyService,
            quickAskService: services.quickAskServiceConcrete,
            screenshotManager: services.screenshotManager,
            liveCaptionManager: services.liveCaptionManager,
            dictionaryPanelManager: services.dictionaryPanelManager,
            debugAutomationTrigger: services.debugAutomationTrigger,
            recordingController: services.recordingController,
            liveCaptionWindowManager: services.liveCaptionWindowManager,
            selectionActionService: services.selectionActionService,
            appSettings: services.appSettingsConcrete,
            selectionToolbarManager: services.selectionToolbarManager,
            trackpadSwipeService: services.trackpadSwipeService,
            messagePanelManager: services.messagePanelManager,
            historyManager: services.historyManagerConcrete,
            resourceMonitor: services.resourceMonitor,
            clipboardHistoryService: services.clipboardHistoryService,
            transcriptionModelManager: services.transcriptionModelManager,
            transcriptionManager: services.transcriptionManagerConcrete,
            crashLogger: services.crashLogger
        )
    }
}
