import AppKit

/// UI 自动化稳定标识（跨 R2-3 / D 阶段复用）
enum UITestIdentifiers {
    enum Window {
        static let floatingHUD = "ui.hud.floating-capsule.window"
        static let liveCaption = "ui.live-caption.window"
        static let screenshot = "ui.screenshot.window"
    }

    enum Element {
        static let floatingHUDRoot = "ui.hud.floating-capsule.root"
        static let liveCaptionRoot = "ui.live-caption.root"
        static let screenshotContent = "ui.screenshot.content"
    }
}

