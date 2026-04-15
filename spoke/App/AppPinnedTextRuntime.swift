import AppKit

@MainActor
struct AppPinnedTextRuntime {
    let makeWindow: (PinnedTextItem) -> PinnedTextWindow
    let updateFrame: (CGRect, PinnedTextItem) -> Void
    let restoreAll: () async -> Void
    let createFromClipboard: () -> Void

    func makeWindowFactory() -> (PinnedTextItem) -> NSPanel {
        { item in
            let window = makeWindow(item)
            window.onFrameChanged = { newFrame in
                updateFrame(newFrame, item)
            }
            return window
        }
    }

    func restorePinnedTexts(log: (String) -> Void) async {
        await restoreAll()
        log("📝 [AppDelegate] Pinned text restore finished")
    }
}
