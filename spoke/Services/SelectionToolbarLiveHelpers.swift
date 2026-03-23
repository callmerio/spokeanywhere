import AppKit

@MainActor
struct SelectionToolbarLiveServices {
    let serviceContainer: ServiceContainer

    var state: SelectionToolbarState { serviceContainer.selectionToolbarState }
    var configService: ToolbarConfigService { serviceContainer.toolbarConfigService }
    var selectionMonitorService: SelectionMonitorService { serviceContainer.selectionMonitorService }
    var workspace: NSWorkspace { serviceContainer.workspace }
}

@MainActor
func currentSelectionToolbarLiveServices() -> SelectionToolbarLiveServices {
    SelectionToolbarLiveServices(serviceContainer: currentServiceContainer())
}

@MainActor
func currentSelectionToolbarSelectionMonitor() -> SelectionMonitorService {
    currentSelectionToolbarLiveServices().selectionMonitorService
}

@MainActor
func openSelectionToolbarSystemSettings(
    _ url: URL
) {
    currentSelectionToolbarLiveServices().workspace.open(url)
}
