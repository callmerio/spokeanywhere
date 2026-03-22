import AppKit

@MainActor
struct SelectionMonitorLiveServices {
    let workspace: NSWorkspace

    static let shared = SelectionMonitorLiveServices(
        workspace: .shared
    )
}

@MainActor
func currentSelectionMonitorToolbarManager() -> SelectionToolbarManager {
    SelectionToolbarManager.shared
}
