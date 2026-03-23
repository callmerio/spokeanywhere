import AppKit

@MainActor
extension SelectionToolbarManagerDependencies {
    static func makeLive() -> SelectionToolbarManagerDependencies {
        let services = currentSelectionToolbarLiveServices()
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
