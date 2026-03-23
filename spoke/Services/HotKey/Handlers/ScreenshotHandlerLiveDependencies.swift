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

func runHotKeyHandlerOnMain<Owner: AnyObject>(
    _ owner: Owner?,
    _ action: @escaping @MainActor (Owner) -> Void
) {
    runtimeRunOnMain(owner: owner, action)
}
