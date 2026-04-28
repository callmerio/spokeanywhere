import AppKit

@MainActor
struct AppScreenshotRuntime {
    let makeWindow: (ScreenshotItem) -> ScreenshotWindow
    let updateFrame: (CGRect, ScreenshotItem) -> Void
    let restoreAll: () async -> Void
    let captureRegion: () async -> Void
    let debugCaptureForAutomation: () async -> Void

    func makeWindowFactory() -> (ScreenshotItem) -> NSPanel {
        { item in
            let window = makeWindow(item)
            window.onFrameChanged = { newFrame in
                updateFrame(newFrame, item)
            }
            return window
        }
    }

    func restorePinnedScreenshots(log: (String) -> Void) async {
        if appShouldSkipSpeechPreparationForMockScenario() {
            log("🧪 [AppDelegate][debug] Skip pinned screenshot restore for live caption mock scenario")
            return
        }
        await restoreAll()
        log("📸 [AppDelegate] Pinned screenshot restore finished")
    }
}
