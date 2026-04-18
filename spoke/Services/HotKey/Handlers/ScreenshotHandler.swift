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
        self.binding = makeScreenshotHandlerBinding()
    }

    func handleKeyDown() -> Bool {
        runHotKeyHandlerOnMain(self) { handler in
            handler.onTrigger?()
        }
        logger.info("Screenshot triggered")
        return true
    }

    func reloadBinding() {
        let settings = screenshotHandlerSettings()
        binding = makeScreenshotHandlerBinding()
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
        self.binding = makeMessagePanelHandlerBinding()
    }

    func handleKeyDown() -> Bool {
        runHotKeyHandlerOnMain(self) { handler in
            handler.onToggle?()
        }
        logger.info("Message Panel toggle triggered")
        return true
    }

    func reloadBinding() {
        let settings = messagePanelHandlerSettings()
        binding = makeMessagePanelHandlerBinding()
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
        self.binding = makeClipboardPipelineHandlerBinding()
    }

    func handleKeyDown() -> Bool {
        runHotKeyHandlerOnMain(self) { handler in
            handler.onTrigger?()
        }
        logger.info("Clipboard Pipeline triggered")
        return true
    }

    func reloadBinding() {
        let settings = clipboardPipelineHandlerSettings()
        binding = makeClipboardPipelineHandlerBinding()
        logger.info("Clipboard Pipeline shortcut reloaded: \(settings.clipboardPipelineShortcutDisplayString)")
    }
}
