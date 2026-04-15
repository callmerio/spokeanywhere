import Foundation

func runPinnedTextManagerDetached<Value: Sendable>(
    priority: TaskPriority = .userInitiated,
    _ operation: @escaping @Sendable () -> Value
) async -> Value {
    await Task(priority: priority) {
        operation()
    }.value
}

func runPinnedTextManagerDetachedThrowing<Value: Sendable>(
    priority: TaskPriority = .utility,
    _ operation: @escaping @Sendable () throws -> Value
) async throws -> Value {
    try await Task(priority: priority) {
        try operation()
    }.value
}
