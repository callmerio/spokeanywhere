import Foundation

@MainActor
extension AddToDictionaryHandlerDependencies {
    static let live = AddToDictionaryHandlerDependencies(
        notificationCenter: .default,
        dictionaryService: .shared,
        messagePanelState: .shared
    )

    static let preview = AddToDictionaryHandlerDependencies(
        notificationCenter: NotificationCenter(),
        dictionaryService: .shared,
        messagePanelState: .shared
    )
}

@MainActor
extension AddToDictionarySheetDependencies {
    static let live = AddToDictionarySheetDependencies(
        dictionaryService: .shared,
        addHighlight: { MessagePanelState.shared.addHighlightToLatestCard($0) }
    )
}

