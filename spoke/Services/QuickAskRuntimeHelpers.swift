import AppKit
import Foundation

func runQuickAskServiceOnMain(
    _ service: QuickAskService?,
    _ action: @escaping @MainActor (QuickAskService) async -> Void
) {
    runtimeRunOnMainAsync(owner: service, action)
}

func runQuickAskHUDManagerOnMain(
    _ manager: QuickAskHUDManager?,
    _ action: @escaping @MainActor (QuickAskHUDManager) -> Void
) {
    runtimeRunOnMain(owner: manager, action)
}

func runQuickAskHUDManagerAfterDelay(
    _ manager: QuickAskHUDManager?,
    seconds: Double,
    _ action: @escaping @MainActor (QuickAskHUDManager) -> Void
) {
    runtimeRunOnMain(after: seconds, owner: manager, action)
}

func runQuickAskServiceAfterDelay(
    _ service: QuickAskService?,
    seconds: Double,
    _ action: @escaping @MainActor (QuickAskService) -> Void
) {
    runtimeRunOnMain(after: seconds, owner: service, action)
}

func makeQuickAskTimer(
    interval: TimeInterval,
    repeats: Bool = false,
    owner: QuickAskService,
    action: @escaping @MainActor (QuickAskService) -> Void
) -> Timer {
    runtimeMakeOwnedTimer(interval: interval, repeats: repeats, owner: owner, action: action)
}

@MainActor
func triggerQuickAskOpenSettings() {
    _ = NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil)
}
