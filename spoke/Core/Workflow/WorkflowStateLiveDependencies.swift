import Foundation

@MainActor
extension WorkflowStateDependencies {
    static let live = WorkflowStateDependencies(
        configService: .shared,
        markAsRecent: { WorkflowConfigService.shared.markAsRecent($0) }
    )

    static let preview = WorkflowStateDependencies(
        configService: .shared,
        markAsRecent: { _ in }
    )
}
