import Foundation

func runDictionaryPanelAsync(
    _ operation: @escaping @MainActor () async -> Void
) {
    runtimeRunOnMainAsync(operation)
}

func runDictionaryPanelManagerOnMain(
    _ manager: DictionaryPanelManager?,
    _ action: @escaping @MainActor (DictionaryPanelManager) -> Void
) {
    runtimeRunOnMain(owner: manager, action)
}

func runDictionaryPanelDetached<Value: Sendable>(
    priority: TaskPriority = .userInitiated,
    _ operation: @escaping @Sendable () -> Value
) async -> Value {
    await Task.detached(priority: priority) {
        operation()
    }.value
}

func makeDictionaryPanelSearchTask<Owner: AnyObject>(
    delay: Double,
    owner: Owner?,
    _ action: @escaping @MainActor (Owner) async -> Void
) -> Task<Void, Never> {
    Task { @MainActor [weak owner] in
        try? await Task.sleep(for: .seconds(delay))
        guard let owner else { return }
        await action(owner)
    }
}
