import AppKit
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

func runQuickAskServiceAfterDelay(
    _ service: QuickAskService?,
    seconds: Double,
    _ action: @escaping @MainActor (QuickAskService) -> Void
) {
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(seconds))
        guard let service else { return }
        action(service)
    }
}

func makeQuickAskTimer(
    interval: TimeInterval,
    repeats: Bool = false,
    owner: QuickAskService,
    action: @escaping @MainActor (QuickAskService) -> Void
) -> Timer {
    Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats) { [weak owner] _ in
        Task { @MainActor in
            guard let owner else { return }
            action(owner)
        }
    }
}

@MainActor
func triggerQuickAskOpenSettings() {
    _ = NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil)
}
