import AppKit

@MainActor
struct QuickAskHUDWindowRuntime {
    let setQuickAskActive: (Bool) -> Void
    let setDebugKeyEvents: (Bool) -> Void
    let setActivationPolicy: (NSApplication.ActivationPolicy) -> Void
    let activateApp: () -> Void
    let promotePanel: (NSWindow) -> Void

    func prepareForPresentation() {
        setQuickAskActive(true)
        setDebugKeyEvents(true)
        setActivationPolicy(.regular)
    }

    func restoreAfterDismissal(restorePolicy: Bool) {
        setDebugKeyEvents(false)
        setQuickAskActive(false)
        if restorePolicy {
            setActivationPolicy(.accessory)
        }
    }

    func activatePanelIfNeeded(_ panel: NSWindow?) {
        guard let panel else { return }
        activateApp()
        promotePanel(panel)
    }
}
