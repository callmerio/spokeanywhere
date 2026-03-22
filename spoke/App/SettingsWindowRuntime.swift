import AppKit

@MainActor
struct SettingsWindowRuntime {
    let setActivationPolicy: (NSApplication.ActivationPolicy) -> Void
    let activateApp: () -> Void
    let focusWindow: (NSWindow) -> Void

    func prepareForPresentation() {
        setActivationPolicy(.regular)
    }

    func reuseExistingWindow(_ window: NSWindow) {
        focusWindow(window)
        activateApp()
    }

    func showNewWindow(_ window: NSWindow) {
        focusWindow(window)
        activateApp()
    }

    func restoreAfterClose(showInDock: Bool) {
        guard !showInDock else { return }
        setActivationPolicy(.accessory)
    }
}
