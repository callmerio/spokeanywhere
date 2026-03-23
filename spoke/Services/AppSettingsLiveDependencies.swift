import AppKit
import Foundation
import ServiceManagement

@MainActor
extension AppSettingsDependencies {
    static let live = AppSettingsDependencies(
        notificationCenter: .default,
        updateLoginItemRegistration: { enabled in
            if #available(macOS 13.0, *) {
                if enabled {
                    try? SMAppService.mainApp.register()
                } else {
                    try? SMAppService.mainApp.unregister()
                }
            }
        },
        applyDockVisibility: { showInDock in
            if showInDock {
                NSApp.setActivationPolicy(.regular)
            } else {
                NSApp.setActivationPolicy(.accessory)
            }
        },
        updateSelectionToolbarEnabled: { enabled in
            if enabled {
                SelectionToolbarManager.shared.start(requestPermissionIfNeeded: true)
            } else {
                SelectionToolbarManager.shared.stop()
            }
        }
    )
}
