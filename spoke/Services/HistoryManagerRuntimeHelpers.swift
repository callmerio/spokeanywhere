import Foundation

func runHistoryManagerDetached<Value: Sendable>(
    priority: TaskPriority = .utility,
    _ operation: @escaping @Sendable () async -> Value
) async -> Value {
    await Task(priority: priority) {
        await operation()
    }.value
}

func runHistoryManagerDetachedThrowing<Value: Sendable>(
    priority: TaskPriority = .utility,
    _ operation: @escaping @Sendable () throws -> Value
) async throws -> Value {
    try await Task(priority: priority) {
        try operation()
    }.value
}
