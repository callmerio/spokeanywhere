import Foundation

@MainActor
extension AddToDictionaryHandlerDependencies {
    static let live = AddToDictionaryHandlerDependencies(
        notificationCenter: .default,
        dictionaryService: currentServiceContainer().dictionaryService,
        messagePanelState: currentServiceContainer().messagePanelState
    )

    static let preview = AddToDictionaryHandlerDependencies(
        notificationCenter: NotificationCenter(),
        dictionaryService: currentServiceContainer().dictionaryService,
        messagePanelState: currentServiceContainer().messagePanelState
    )
}

@MainActor
extension AddToDictionarySheetDependencies {
    static let live = AddToDictionarySheetDependencies(
        dictionaryService: currentServiceContainer().dictionaryService,
        addHighlight: { currentServiceContainer().messagePanelState.addHighlightToLatestCard($0) }
    )
}
