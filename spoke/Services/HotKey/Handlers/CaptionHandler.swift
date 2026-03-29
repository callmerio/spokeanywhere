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
        self.binding = makeCaptionHandlerBinding()
    }

    func handleKeyDown() -> Bool {
        runHotKeyHandlerOnMain(self) { handler in
            handler.onToggle?()
        }
        logger.info("Live Caption toggle triggered")
        return true
    }

    func reloadBinding() {
        let settings = captionHandlerSettings()
        binding = makeCaptionHandlerBinding()
        logger.info("Live Caption shortcut reloaded: \(settings.liveCaptionShortcutDisplayString)")
    }
}
