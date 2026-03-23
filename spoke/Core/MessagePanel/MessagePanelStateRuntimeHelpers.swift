import Foundation

func runMessagePanelStateAsync(
    _ operation: @escaping @Sendable () async -> Void
) {
    runtimeRunAsync(operation)
}

func runMessagePanelStateOnMain(
    _ operation: @escaping @MainActor () -> Void
) {
    runtimeRunOnMain(operation)
}

func runMessagePanelStateOnMain<Owner: AnyObject>(
    owner: Owner?,
    _ action: @escaping @MainActor (Owner) -> Void
) {
    runtimeRunOnMain(owner: owner, action)
}

func scheduleMessagePanelStateMain(
    after seconds: Double,
    _ operation: @escaping @MainActor () -> Void
) {
    runtimeRunOnMain(after: seconds, operation)
}
