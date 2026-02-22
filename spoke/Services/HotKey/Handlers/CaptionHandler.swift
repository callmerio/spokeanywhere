import AppKit
import Carbon.HIToolbox
import os

/// Live Caption 热键处理器
@MainActor
final class CaptionHandler: HotKeyHandler {

    let hotKeyType: HotKeyType = .liveCaption
    var binding: HotKeyBinding

    private let logger = Logger(subsystem: "com.spokeanywhere", category: "CaptionHandler")

    /// 回调
    var onToggle: (() -> Void)?

    init() {
        let settings = AppSettings.shared
        self.binding = HotKeyBinding(
            keyCode: UInt32(settings.liveCaptionKeyCode),
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(settings.liveCaptionModifiers))
        )
    }

    func handleKeyDown() -> Bool {
        DispatchQueue.main.async { [weak self] in
            self?.onToggle?()
        }
        logger.info("Live Caption toggle triggered")
        return true
    }

    func reloadBinding() {
        let settings = AppSettings.shared
        binding = HotKeyBinding(
            keyCode: UInt32(settings.liveCaptionKeyCode),
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(settings.liveCaptionModifiers))
        )
        logger.info("Live Caption shortcut reloaded: \(settings.liveCaptionShortcutDisplayString)")
    }
}
