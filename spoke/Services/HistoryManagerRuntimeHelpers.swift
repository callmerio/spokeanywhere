import Foundation

func runHistoryManagerDetached<Value: Sendable>(
    priority: TaskPriority = .utility,
    _ operation: @escaping @Sendable () async -> Value
) async -> Value {
    await Task.detached(priority: priority) {
        await operation()
    }.value
}

func runHistoryManagerDetachedThrowing<Value: Sendable>(
    priority: TaskPriority = .utility,
    _ operation: @escaping @Sendable () throws -> Value
) async throws -> Value {
    try await Task.detached(priority: priority) {
        try operation()
    }.value
}
