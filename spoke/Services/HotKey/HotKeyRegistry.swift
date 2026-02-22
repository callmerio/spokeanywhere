import AppKit
import os

/// 热键注册表
/// 管理所有热键绑定的存储和查询
@MainActor
final class HotKeyRegistry {

    private let logger = Logger(subsystem: "com.spokeanywhere", category: "HotKeyRegistry")

    /// 所有已注册的处理器
    private var handlers: [HotKeyType: HotKeyHandler] = [:]

    /// 快捷键变更观察者
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []

    init() {
        setupObservers()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Handler Registration

    /// 注册一个热键处理器
    func register(_ handler: HotKeyHandler) {
        handlers[handler.hotKeyType] = handler
        logger.info("Registered handler for: \(handler.hotKeyType.rawValue)")
    }

    /// 注销一个热键处理器
    func unregister(type: HotKeyType) {
        handlers.removeValue(forKey: type)
    }

    /// 获取指定类型的处理器
    func handler(for type: HotKeyType) -> HotKeyHandler? {
        return handlers[type]
    }

    /// 获取所有处理器
    var allHandlers: [HotKeyHandler] {
        return Array(handlers.values)
    }

    // MARK: - Event Matching

    /// 查找匹配给定事件的处理器
    /// - Parameters:
    ///   - keyCode: 按键码
    ///   - flags: 修饰键状态
    /// - Returns: 匹配的处理器，如果没有匹配则返回 nil
    func findHandler(for keyCode: UInt32, flags: CGEventFlags) -> HotKeyHandler? {
        for handler in handlers.values {
            if handler.binding.matches(keyCode: keyCode, flags: flags) {
                return handler
            }
        }
        return nil
    }

    // MARK: - Settings Observers

    private func setupObservers() {
        // Recording 快捷键变更
        observers.append(NotificationCenter.default.addObserver(
            forName: AppSettings.shortcutDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlers[.recording]?.reloadBinding()
                self?.logger.info("Recording shortcut reloaded")
            }
        })

        // Quick Ask 快捷键变更
        observers.append(NotificationCenter.default.addObserver(
            forName: AppSettings.quickAskShortcutDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlers[.quickAsk]?.reloadBinding()
                self?.logger.info("Quick Ask shortcut reloaded")
            }
        })

        // Message Panel 快捷键变更
        observers.append(NotificationCenter.default.addObserver(
            forName: AppSettings.messagePanelShortcutDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlers[.messagePanel]?.reloadBinding()
                self?.logger.info("Message Panel shortcut reloaded")
            }
        })

        // Live Caption 快捷键变更
        observers.append(NotificationCenter.default.addObserver(
            forName: AppSettings.liveCaptionShortcutDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlers[.liveCaption]?.reloadBinding()
                self?.logger.info("Live Caption shortcut reloaded")
            }
        })

        // Screenshot 快捷键变更
        observers.append(NotificationCenter.default.addObserver(
            forName: AppSettings.screenshotShortcutDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlers[.screenshot]?.reloadBinding()
                self?.logger.info("Screenshot shortcut reloaded")
            }
        })
    }

    /// 重新加载所有热键绑定
    func reloadAllBindings() {
        for handler in handlers.values {
            handler.reloadBinding()
        }
        logger.info("All hotkey bindings reloaded")
    }
}
