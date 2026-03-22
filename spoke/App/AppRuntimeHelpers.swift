import Foundation

func runAppMainActorAsync(
    _ operation: @escaping @MainActor () async -> Void
) {
    Task { @MainActor in
        await operation()
    }
}

func runAppMainActor(
    _ operation: @escaping @MainActor () -> Void
) {
    Task { @MainActor in
        operation()
    }
}
