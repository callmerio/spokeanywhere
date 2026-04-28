import AppKit
import Foundation

func selectionToolbarAccessibilityAppName(
    bundleURL: URL = Bundle.main.bundleURL,
    fallbackName: String = AppIdentity.displayName
) -> String {
    let candidate = bundleURL.deletingPathExtension().lastPathComponent
        .trimmingCharacters(in: .whitespacesAndNewlines)

    guard !candidate.isEmpty, candidate != "/" else {
        return fallbackName
    }

    return candidate
}

func selectionToolbarAccessibilityInformativeText(
    appName: String = selectionToolbarAccessibilityAppName()
) -> String {
    """
    选择工具栏需要辅助功能权限才能检测文本选择。

    请在「系统设置 → 隐私与安全性 → 辅助功能」中授权 \(appName)。
    """
}

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
