import AppKit
import Carbon.HIToolbox
import os

/// Screenshot 热键处理器
@MainActor
final class ScreenshotHandler: HotKeyHandler {

    let hotKeyType: HotKeyType = .screenshot
    var binding: HotKeyBinding

    private let logger = Logger(subsystem: "com.spokeanywhere", category: "ScreenshotHandler")

    /// 回调
    var onTrigger: (() -> Void)?

    init() {
        let settings = AppSettings.shared
        self.binding = HotKeyBinding(
            keyCode: UInt32(settings.screenshotKeyCode),
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(settings.screenshotModifiers))
        )
    }

    func handleKeyDown() -> Bool {
        DispatchQueue.main.async { [weak self] in
            self?.onTrigger?()
        }
        logger.info("Screenshot triggered")
        return true
    }

    func reloadBinding() {
        let settings = AppSettings.shared
        binding = HotKeyBinding(
            keyCode: UInt32(settings.screenshotKeyCode),
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(settings.screenshotModifiers))
        )
        logger.info("Screenshot shortcut reloaded: \(settings.screenshotShortcutDisplayString)")
    }
}

/// Message Panel 热键处理器
@MainActor
final class MessagePanelHandler: HotKeyHandler {

    let hotKeyType: HotKeyType = .messagePanel
    var binding: HotKeyBinding

    private let logger = Logger(subsystem: "com.spokeanywhere", category: "MessagePanelHandler")

    /// 回调
    var onToggle: (() -> Void)?

    init() {
        let settings = AppSettings.shared
        self.binding = HotKeyBinding(
            keyCode: UInt32(settings.messagePanelKeyCode),
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(settings.messagePanelModifiers))
        )
    }

    func handleKeyDown() -> Bool {
        DispatchQueue.main.async { [weak self] in
            self?.onToggle?()
        }
        logger.info("Message Panel toggle triggered")
        return true
    }

    func reloadBinding() {
        let settings = AppSettings.shared
        binding = HotKeyBinding(
            keyCode: UInt32(settings.messagePanelKeyCode),
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(settings.messagePanelModifiers))
        )
        logger.info("Message Panel shortcut reloaded: \(settings.messagePanelShortcutDisplayString)")
    }
}

/// Clipboard Pipeline 热键处理器
@MainActor
final class ClipboardPipelineHandler: HotKeyHandler {

    let hotKeyType: HotKeyType = .clipboardPipeline
    var binding: HotKeyBinding

    private let logger = Logger(subsystem: "com.spokeanywhere", category: "ClipboardPipelineHandler")

    /// 回调
    var onTrigger: (() -> Void)?

    init() {
        // Clipboard Pipeline 暂时没有专门的设置，使用默认值
        self.binding = HotKeyBinding(
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: .option
        )
    }

    func handleKeyDown() -> Bool {
        DispatchQueue.main.async { [weak self] in
            self?.onTrigger?()
        }
        logger.info("Clipboard Pipeline triggered")
        return true
    }

    func reloadBinding() {
        // Clipboard Pipeline 暂无独立设置
    }
}
