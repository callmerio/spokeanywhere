import AppKit
import Carbon.HIToolbox
import os

/// Quick Ask 热键处理器
/// 处理 Quick Ask 面板的激活和发送
@MainActor
final class QuickAskHandler: HotKeyHandler {

    let hotKeyType: HotKeyType = .quickAsk
    var binding: HotKeyBinding

    private let logger = Logger(subsystem: "com.spokeanywhere", category: "QuickAskHandler")

    /// 是否处于 Quick Ask 激活状态
    var isActive = false

    /// 回调
    var onStart: (() -> Void)?
    var onSend: (() -> Void)?

    init() {
        let settings = AppSettings.shared
        self.binding = HotKeyBinding(
            keyCode: UInt32(settings.quickAskKeyCode),
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(settings.quickAskModifiers))
        )
    }

    func handleKeyDown() -> Bool {
        if !isActive {
            // 开始 Quick Ask
            DispatchQueue.main.async { [weak self] in
                self?.isActive = true
                self?.onStart?()
            }
            logger.info("Quick Ask started")
        } else {
            // 已经在 Quick Ask 中，再按一次触发发送
            DispatchQueue.main.async { [weak self] in
                self?.isActive = false
                self?.onSend?()
            }
            logger.info("Quick Ask sending")
        }
        return true
    }

    func reloadBinding() {
        let settings = AppSettings.shared
        binding = HotKeyBinding(
            keyCode: UInt32(settings.quickAskKeyCode),
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(settings.quickAskModifiers))
        )
        logger.info("Quick Ask shortcut reloaded: \(settings.quickAskShortcutDisplayString)")
    }

    /// 重置状态
    func reset() {
        isActive = false
        logger.info("Quick Ask state reset")
    }

    /// 设置激活状态
    func setActive(_ active: Bool) {
        isActive = active
        logger.info("Quick Ask active: \(active)")
    }
}
