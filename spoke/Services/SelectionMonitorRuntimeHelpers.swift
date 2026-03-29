import AppKit
import Foundation

func runSelectionMonitorOnMain(
    _ service: SelectionMonitorService?,
    _ action: @escaping @MainActor (SelectionMonitorService) -> Void
) {
    runtimeRunOnMain(owner: service, action)
}

func makeSelectionMonitorDebounceTimer(
    interval: TimeInterval,
    owner: SelectionMonitorService,
    action: @escaping @MainActor (SelectionMonitorService) -> Void
) -> Timer {
    runtimeMakeOwnedTimer(interval: interval, owner: owner, action: action)
}

func invalidateSelectionMonitorTimer(
    _ timer: inout Timer?
) {
    runtimeInvalidateTimer(&timer)
}

@MainActor
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
    runtimeRunDetachedValue(
        priority: .userInitiated,
        operation: { loadSelection(frontApp).map { ($0.0, $0.1, bundleId, appName) } }
    ) { result in
        onResult(result.0, result.1, result.2, result.3)
    }
}
