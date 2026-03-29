import AppKit

/// UI 自动化稳定标识（跨 R2-3 / D 阶段复用）
enum UITestIdentifiers {
    enum Window {
        static let floatingHUD = "ui.hud.floating-capsule.window"
        static let quickAskCapsule = "ui.quickask.capsule.window"
        static let answerPanel = "ui.quickask.answer-panel.window"
        static let messagePanel = "ui.message-panel.window"
        static let selectionToolbar = "ui.selection-toolbar.window"
        static let liveCaption = "ui.live-caption.window"
        static let screenshot = "ui.screenshot.window"
    }

    enum Element {
        static let floatingHUDRoot = "ui.hud.floating-capsule.root"
        static let quickAskInput = "ui.quickask.input"
        static let quickAskCapsuleRoot = "ui.quickask.capsule.root"
        static let answerPanelRoot = "ui.quickask.answer-panel.root"
        static let messagePanelRoot = "ui.message-panel.root"
        static let selectionToolbarRoot = "ui.selection-toolbar.root"
        static let liveCaptionRoot = "ui.live-caption.root"
        static let screenshotContent = "ui.screenshot.content"
    }
}

