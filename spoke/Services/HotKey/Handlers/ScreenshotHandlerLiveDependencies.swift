import AppKit
import Foundation

@MainActor
func screenshotHandlerSettings() -> AppSettings {
    AppSettings.shared
}

@MainActor
func messagePanelHandlerSettings() -> AppSettings {
    AppSettings.shared
}

@MainActor
func quickAskHandlerSettings() -> AppSettings {
    AppSettings.shared
}

@MainActor
func captionHandlerSettings() -> AppSettings {
    AppSettings.shared
}

@MainActor
func clipboardPipelineHandlerSettings() -> AppSettings {
    AppSettings.shared
}

@MainActor
func voiceHandlerSettings() -> AppSettings {
    AppSettings.shared
}

@MainActor
func makeHotKeyBinding(keyCode: Int, modifiers: Int) -> HotKeyBinding {
    HotKeyBinding(
        keyCode: UInt32(keyCode),
        modifiers: NSEvent.ModifierFlags(rawValue: UInt(modifiers))
    )
}

@MainActor
func makeScreenshotHandlerBinding() -> HotKeyBinding {
    let settings = screenshotHandlerSettings()
    return makeHotKeyBinding(
        keyCode: settings.screenshotKeyCode,
        modifiers: settings.screenshotModifiers
    )
}

@MainActor
func makeMessagePanelHandlerBinding() -> HotKeyBinding {
    let settings = messagePanelHandlerSettings()
    return makeHotKeyBinding(
        keyCode: settings.messagePanelKeyCode,
        modifiers: settings.messagePanelModifiers
    )
}

@MainActor
func makeQuickAskHandlerBinding() -> HotKeyBinding {
    let settings = quickAskHandlerSettings()
    return makeHotKeyBinding(
        keyCode: settings.quickAskKeyCode,
        modifiers: settings.quickAskModifiers
    )
}

@MainActor
func makeCaptionHandlerBinding() -> HotKeyBinding {
    let settings = captionHandlerSettings()
    return makeHotKeyBinding(
        keyCode: settings.liveCaptionKeyCode,
        modifiers: settings.liveCaptionModifiers
    )
}

@MainActor
func makeClipboardPipelineHandlerBinding() -> HotKeyBinding {
    let settings = clipboardPipelineHandlerSettings()
    return makeHotKeyBinding(
        keyCode: settings.clipboardPipelineKeyCode,
        modifiers: settings.clipboardPipelineModifiers
    )
}

@MainActor
func makeVoiceHandlerBinding() -> HotKeyBinding {
    let settings = voiceHandlerSettings()
    return makeHotKeyBinding(
        keyCode: settings.shortcutKeyCode,
        modifiers: settings.shortcutModifiers
    )
}

func runHotKeyHandlerOnMain<Owner: AnyObject>(
    _ owner: Owner?,
    _ action: @escaping @MainActor (Owner) -> Void
) {
    runtimeRunOnMain(owner: owner, action)
}
