import AppKit

@MainActor
extension SelectionToolbarManagerDependencies {
    static func makeLive() -> SelectionToolbarManagerDependencies {
        let services = SelectionToolbarLiveServices.shared
        return SelectionToolbarManagerDependencies(
            state: services.state,
            selectionMonitor: { currentSelectionToolbarSelectionMonitor() },
            notificationCenter: .default,
            configService: services.configService,
            openSystemSettings: { url in
                openSelectionToolbarSystemSettings(url)
            }
        )
    }
}
