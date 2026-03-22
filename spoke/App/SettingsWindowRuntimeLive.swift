import AppKit

@MainActor
extension SettingsWindowRuntime {
    static let live = SettingsWindowRuntime(
        setActivationPolicy: { NSApp.setActivationPolicy($0) },
        activateApp: { NSApp.activate(ignoringOtherApps: true) },
        focusWindow: { window in
            window.makeKeyAndOrderFront(nil)
        }
    )
}
