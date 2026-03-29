import Foundation

@MainActor
extension HistoryManagerDependencies {
    static let live = HistoryManagerDependencies(
        llmPipeline: .shared
    )
}
