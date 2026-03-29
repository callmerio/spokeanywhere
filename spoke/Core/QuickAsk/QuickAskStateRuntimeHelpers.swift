import Foundation

func runQuickAskStateTask(
    _ operation: @escaping @Sendable () async -> Void
) {
    runtimeRunAsync(operation)
}

func runQuickAskStateOnMain(
    _ state: QuickAskState?,
    _ action: @escaping @MainActor (QuickAskState) -> Void
) {
    runtimeRunOnMain(owner: state, action)
}
