import AppKit
import Foundation

func runSelectionToolbarOnMain(
    _ operation: @escaping @MainActor () -> Void
) {
    Task { @MainActor in
        operation()
    }
}

func runSelectionToolbarAfterDelay(
    seconds: Double,
    _ operation: @escaping @MainActor () -> Void
) {
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(seconds))
        operation()
    }
}

func makeSelectionToolbarTimer(
    interval: TimeInterval,
    repeats: Bool = false,
    owner: SelectionToolbarManager,
    action: @escaping @MainActor (SelectionToolbarManager) -> Void
) -> Timer {
    Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats) { [weak owner] _ in
        runSelectionToolbarOnMain {
            guard let owner else { return }
            action(owner)
        }
    }
}

func invalidateSelectionToolbarTimer(
    _ timer: inout Timer?
) {
    timer?.invalidate()
    timer = nil
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
    Task { [weak owner] in
        guard let owner else { return }

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: intervalNs)
            let isGranted = await MainActor.run {
                isPermissionGranted(owner)
            }

            if isGranted {
                await MainActor.run {
                    onPermissionGranted(owner)
                }
                break
            }
        }
    }
}
