import AppKit
import Foundation

func runSelectionToolbarOnMain(
    _ operation: @escaping @MainActor () -> Void
) {
    runtimeRunOnMain(operation)
}

func runSelectionToolbarAfterDelay(
    seconds: Double,
    _ operation: @escaping @MainActor () -> Void
) {
    runtimeRunOnMain(after: seconds, operation)
}

func makeSelectionToolbarTimer(
    interval: TimeInterval,
    repeats: Bool = false,
    owner: SelectionToolbarManager,
    action: @escaping @MainActor (SelectionToolbarManager) -> Void
) -> Timer {
    runtimeMakeOwnedTimer(interval: interval, repeats: repeats, owner: owner, action: action)
}

func invalidateSelectionToolbarTimer(
    _ timer: inout Timer?
) {
    runtimeInvalidateTimer(&timer)
}

func selectionToolbarMouseContainment(
    for window: NSWindow?
) -> Bool? {
    guard let window, window.isVisible else {
        return nil
    }
    return window.frame.contains(NSEvent.mouseLocation)
}

func selectionToolbarVisibleFrame(
    for window: NSWindow?
) -> CGRect? {
    guard let window, window.isVisible else {
        return nil
    }
    return window.frame
}

func cancelSelectionToolbarTask(
    _ task: inout Task<Void, Never>?
) {
    task?.cancel()
    task = nil
}

func makeSelectionToolbarPermissionPollingTask(
    owner: SelectionToolbarManager,
    intervalNs: UInt64,
    isPermissionGranted: @escaping @MainActor (SelectionToolbarManager) -> Bool,
    onPermissionGranted: @escaping @MainActor (SelectionToolbarManager) -> Void
) -> Task<Void, Never> {
    runtimeMakePollingTask(
        owner: owner,
        intervalNs: intervalNs,
        isSatisfied: isPermissionGranted,
        onSatisfied: onPermissionGranted
    )
}
