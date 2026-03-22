import AppKit
import Foundation

func runSelectionMonitorOnMain(
    _ service: SelectionMonitorService?,
    _ action: @escaping @MainActor (SelectionMonitorService) -> Void
) {
    Task { @MainActor in
        guard let service else { return }
        action(service)
    }
}

func makeSelectionMonitorDebounceTimer(
    interval: TimeInterval,
    owner: SelectionMonitorService,
    action: @escaping @MainActor (SelectionMonitorService) -> Void
) -> Timer {
    Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak owner] _ in
        runSelectionMonitorOnMain(owner, action)
    }
}

func invalidateSelectionMonitorTimer(
    _ timer: inout Timer?
) {
    timer?.invalidate()
    timer = nil
}

func selectionMonitorToolbarContainsMouse(
    _ window: NSWindow?,
    at location: CGPoint = NSEvent.mouseLocation
) -> Bool {
    guard let window, window.isVisible else {
        return false
    }
    return window.frame.contains(location)
}

func runSelectionMonitorAXQuery(
    frontApp: NSRunningApplication,
    bundleId: String,
    appName: String?,
    loadSelection: @escaping @Sendable (NSRunningApplication) -> (String, CGRect)?,
    onResult: @escaping @MainActor (String, CGRect, String, String?) -> Void
) {
    Task.detached(priority: .userInitiated) {
        guard let (selectedText, bounds) = loadSelection(frontApp) else {
            return
        }

        await MainActor.run {
            onResult(selectedText, bounds, bundleId, appName)
        }
    }
}
