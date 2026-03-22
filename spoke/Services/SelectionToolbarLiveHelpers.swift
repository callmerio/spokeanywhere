import AppKit

@MainActor
struct SelectionToolbarLiveServices {
    let state: SelectionToolbarState
    let configService: ToolbarConfigService

    static let shared = SelectionToolbarLiveServices(
        state: .shared,
        configService: .shared
    )
}

@MainActor
func currentSelectionToolbarSelectionMonitor() -> SelectionMonitorService {
    SelectionMonitorService.shared
}

func openSelectionToolbarSystemSettings(
    _ url: URL,
    workspace: NSWorkspace = .shared
) {
    workspace.open(url)
}
