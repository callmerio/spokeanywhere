import Foundation

func runScreenshotManagerDetached<Value: Sendable>(
    priority: TaskPriority = .userInitiated,
    _ operation: @escaping @Sendable () -> Value
) async -> Value {
    await Task.detached(priority: priority) {
        operation()
    }.value
}

func runScreenshotManagerDetachedThrowing<Value: Sendable>(
    priority: TaskPriority = .utility,
    _ operation: @escaping @Sendable () throws -> Value
) async throws -> Value {
    try await Task.detached(priority: priority) {
        try operation()
    }.value
}

