import Foundation

@MainActor
extension AnswerPanelManagerDependencies {
    static let live = AnswerPanelManagerDependencies(
        historyService: currentServiceContainer().sessionHistoryService
    )
}
