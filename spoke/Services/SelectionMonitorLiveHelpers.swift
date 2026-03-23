import AppKit

@MainActor
struct SelectionMonitorLiveServices {
    let serviceContainer: ServiceContainer

    static let shared = SelectionMonitorLiveServices(serviceContainer: .shared)

    var workspace: NSWorkspace { serviceContainer.workspace }
    var selectionToolbarManager: SelectionToolbarManager { serviceContainer.selectionToolbarManager }
}
