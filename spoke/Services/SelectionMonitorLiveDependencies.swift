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
                currentSelectionMonitorToolbarManager().toolbarWindow
            },
            hideToolbar: { force in
                currentSelectionMonitorToolbarManager().hide(force: force)
            }
        )
    }
}
