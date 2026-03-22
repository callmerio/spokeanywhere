import Foundation

func runQuickAskServiceOnMain(
    _ service: QuickAskService?,
    _ action: @escaping @MainActor (QuickAskService) async -> Void
) {
    Task { @MainActor in
        guard let service else { return }
        await action(service)
    }
}

func runQuickAskHUDManagerOnMain(
    _ manager: QuickAskHUDManager?,
    _ action: @escaping @MainActor (QuickAskHUDManager) -> Void
) {
    Task { @MainActor in
        guard let manager else { return }
        action(manager)
    }
}

func runQuickAskHUDManagerAfterDelay(
    _ manager: QuickAskHUDManager?,
    seconds: Double,
    _ action: @escaping @MainActor (QuickAskHUDManager) -> Void
) {
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(seconds))
        guard let manager else { return }
        action(manager)
    }
}
