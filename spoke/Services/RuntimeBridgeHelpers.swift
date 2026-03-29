import Foundation

private final class RuntimeWeakRef<Object: AnyObject>: @unchecked Sendable {
    weak var value: Object?

    init(_ value: Object?) {
        self.value = value
    }
}

private struct RuntimeUnsafeBox<Value>: @unchecked Sendable {
    let value: Value
}

func runtimeRunOnMain(
    _ operation: @escaping @MainActor () -> Void
) {
    let operationBox = RuntimeUnsafeBox(value: operation)
    Task { @MainActor in
        operationBox.value()
    }
}

func runtimeRunOnMainAsync(
    _ operation: @escaping @MainActor () async -> Void
) {
    let operationBox = RuntimeUnsafeBox(value: operation)
    Task { @MainActor in
        await operationBox.value()
    }
}

func runtimeRunOnMain<Owner: AnyObject>(
    owner: Owner?,
    _ action: @escaping @MainActor (Owner) -> Void
) {
    let ownerRef = RuntimeWeakRef(owner)
    let actionBox = RuntimeUnsafeBox(value: action)
    runtimeRunOnMain {
        guard let owner = ownerRef.value else { return }
        actionBox.value(owner)
    }
}

func runtimeRunOnMainAsync<Owner: AnyObject>(
    owner: Owner?,
    _ action: @escaping @MainActor (Owner) async -> Void
) {
    let ownerRef = RuntimeWeakRef(owner)
    let actionBox = RuntimeUnsafeBox(value: action)
    runtimeRunOnMainAsync {
        guard let owner = ownerRef.value else { return }
        await actionBox.value(owner)
    }
}

func runtimeRunOnMainValue<Value>(
    _ value: Value,
    _ action: @escaping @MainActor (Value) -> Void
) {
    let valueBox = RuntimeUnsafeBox(value: value)
    let actionBox = RuntimeUnsafeBox(value: action)
    runtimeRunOnMain {
        actionBox.value(valueBox.value)
    }
}

func runtimeRunAsync(
    _ operation: @escaping @Sendable () async -> Void
) {
    Task {
        await operation()
    }
}

func runtimeMakeTask(
    _ operation: @escaping @Sendable () async -> Void
) -> Task<Void, Never> {
    Task {
        await operation()
    }
}

func runtimeMakeValueTask<Result: Sendable>(
    _ operation: @escaping @Sendable () async -> Result
) -> Task<Result, Never> {
    Task {
        await operation()
    }
}

func runtimeMakeMainActorTask<Owner: AnyObject>(
    owner: Owner?,
    _ action: @escaping @MainActor (Owner) async -> Void
) -> Task<Void, Never> {
    let ownerRef = RuntimeWeakRef(owner)
    let actionBox = RuntimeUnsafeBox(value: action)
    return runtimeMakeTask {
        guard let owner = ownerRef.value else { return }
        await actionBox.value(owner)
    }
}

func runtimeMakeDelayedTask<Owner: AnyObject>(
    delayNs: UInt64,
    owner: Owner?,
    _ action: @escaping @MainActor (Owner) -> Void
) -> Task<Void, Never> {
    let ownerRef = RuntimeWeakRef(owner)
    let actionBox = RuntimeUnsafeBox(value: action)
    return runtimeMakeTask {
        try? await Task.sleep(nanoseconds: delayNs)
        guard !Task.isCancelled else { return }
        guard let owner = ownerRef.value else { return }
        await actionBox.value(owner)
    }
}

func runtimeMakeDelayedAsyncTask<Owner: AnyObject>(
    delaySeconds: Double,
    owner: Owner?,
    _ action: @escaping @MainActor (Owner) async -> Void
) -> Task<Void, Never> {
    let ownerRef = RuntimeWeakRef(owner)
    let actionBox = RuntimeUnsafeBox(value: action)
    return runtimeMakeTask {
        try? await Task.sleep(for: .seconds(delaySeconds))
        guard !Task.isCancelled else { return }
        guard let owner = ownerRef.value else { return }
        await actionBox.value(owner)
    }
}

func runtimeRunDetachedAsync<Result: Sendable>(
    priority: TaskPriority = .userInitiated,
    _ operation: @escaping @Sendable () async -> Result
) async -> Result {
    await Task.detached(priority: priority) {
        await operation()
    }.value
}

func runtimeRunOnMain(
    after seconds: Double,
    _ operation: @escaping @MainActor () -> Void
) {
    let operationBox = RuntimeUnsafeBox(value: operation)
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(seconds))
        operationBox.value()
    }
}

func runtimeRunOnMain<Owner: AnyObject>(
    after seconds: Double,
    owner: Owner?,
    _ action: @escaping @MainActor (Owner) -> Void
) {
    let ownerRef = RuntimeWeakRef(owner)
    let actionBox = RuntimeUnsafeBox(value: action)
    runtimeRunOnMain(after: seconds) {
        guard let owner = ownerRef.value else { return }
        actionBox.value(owner)
    }
}

func runtimeMakeOwnedTimer<Owner: AnyObject>(
    interval: TimeInterval,
    repeats: Bool = false,
    owner: Owner?,
    action: @escaping @MainActor (Owner) -> Void
) -> Timer {
    let ownerRef = RuntimeWeakRef(owner)
    return Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats) { _ in
        runtimeRunOnMain(owner: ownerRef.value, action)
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
    let ownerRef = RuntimeWeakRef(owner)
    let isSatisfiedBox = RuntimeUnsafeBox(value: isSatisfied)
    let onSatisfiedBox = RuntimeUnsafeBox(value: onSatisfied)
    return Task {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: intervalNs)
            let satisfied = await MainActor.run { () -> Bool in
                guard let owner = ownerRef.value else { return false }
                return isSatisfiedBox.value(owner)
            }

            if satisfied {
                await MainActor.run {
                    guard let owner = ownerRef.value else { return }
                    onSatisfiedBox.value(owner)
                }
                break
            }
        }
    }
}

func runtimeRunDetachedValue<Result: Sendable>(
    priority: TaskPriority = .userInitiated,
    operation: @escaping @Sendable () -> Result?,
    onResult: @escaping @MainActor (Result) -> Void
) {
    let onResultBox = RuntimeUnsafeBox(value: onResult)
    Task.detached(priority: priority) {
        guard let result = operation() else { return }
        await onResultBox.value(result)
    }
}
