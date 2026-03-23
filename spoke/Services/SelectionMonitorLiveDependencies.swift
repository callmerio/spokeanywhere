import AppKit

@MainActor
extension SelectionMonitorServiceDependencies {
    static func makeLive() -> SelectionMonitorServiceDependencies {
        let services = SelectionMonitorLiveServices.shared
        return SelectionMonitorServiceDependencies(
            workspace: services.workspace,
            hasAccessibilityPermission: {
                AccessibilityHelper.hasAccessibilityPermission()
            },
            requestAccessibilityPermission: {
                AccessibilityHelper.requestAccessibilityPermission()
            },
            toolbarWindow: {
                services.selectionToolbarManager.toolbarWindow
            },
            hideToolbar: { force in
                services.selectionToolbarManager.hide(force: force)
            }
        )
    }
}
