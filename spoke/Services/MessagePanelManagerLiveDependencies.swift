import Foundation

@MainActor
extension MessagePanelManagerDependencies {
    static let live = MessagePanelManagerDependencies(
        state: .shared,
        historyService: .shared,
        dictionaryHandler: .shared,
        hoverState: .shared,
        hotKeyService: .shared,
        tagLibrary: .shared,
        summaryService: .shared,
        answerPanelManager: .shared,
        clipboardPipelineService: { .shared }
    )
}
