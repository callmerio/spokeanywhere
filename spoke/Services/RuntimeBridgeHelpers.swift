import Foundation

func runtimeRunOnMain(
    _ operation: @escaping @MainActor () -> Void
) {
    Task { @MainActor in
        operation()
    }
}

func runtimeRunOnMainAsync(
    _ operation: @escaping @MainActor () async -> Void
) {
    Task { @MainActor in
        await operation()
    }
}

func runtimeRunOnMain<Owner: AnyObject>(
    owner: Owner?,
    _ action: @escaping @MainActor (Owner) -> Void
) {
    runtimeRunOnMain {
        guard let owner else { return }
        action(owner)
    }
}

func runtimeRunOnMainAsync<Owner: AnyObject>(
    owner: Owner?,
    _ action: @escaping @MainActor (Owner) async -> Void
) {
    runtimeRunOnMainAsync {
        guard let owner else { return }
        await action(owner)
    }
}

func runtimeRunOnMainValue<Value>(
    _ value: Value,
    _ action: @escaping @MainActor (Value) -> Void
) {
    runtimeRunOnMain {
        action(value)
    }
}

func runtimeRunAsync(
    _ operation: @escaping @Sendable () async -> Void
) {
    Task {
        await operation()
    }
}

func runtimeRunOnMain(
    after seconds: Double,
    _ operation: @escaping @MainActor () -> Void
) {
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(seconds))
        operation()
    }
}

func runtimeRunOnMain<Owner: AnyObject>(
    after seconds: Double,
    owner: Owner?,
    _ action: @escaping @MainActor (Owner) -> Void
) {
    runtimeRunOnMain(after: seconds) {
        guard let owner else { return }
        action(owner)
    }
}

func runtimeMakeOwnedTimer<Owner: AnyObject>(
    interval: TimeInterval,
    repeats: Bool = false,
    owner: Owner?,
    action: @escaping @MainActor (Owner) -> Void
) -> Timer {
    Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats) { _ in
        runtimeRunOnMain(owner: owner, action)
    }
}

func runtimeInvalidateTimer(
    _ timer: inout Timer?
) {
    timer?.invalidate()
    timer = nil
}

func runtimeMakePollingTask<Owner: AnyObject>(
    owner: Owner,
    intervalNs: UInt64,
    isSatisfied: @escaping @MainActor (Owner) -> Bool,
    onSatisfied: @escaping @MainActor (Owner) -> Void
) -> Task<Void, Never> {
    Task { [weak owner] in
        guard let owner else { return }

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: intervalNs)
            let satisfied = await MainActor.run {
                isSatisfied(owner)
            }

            if satisfied {
                await MainActor.run {
                    onSatisfied(owner)
                }
                break
            }
        }
    }
}

func runtimeRunDetachedValue<Result>(
    priority: TaskPriority = .userInitiated,
    operation: @escaping @Sendable () -> Result?,
    onResult: @escaping @MainActor (Result) -> Void
) {
    Task.detached(priority: priority) {
        guard let result = operation() else { return }
        await MainActor.run {
            onResult(result)
        }
    }
}
