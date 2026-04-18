import AppKit
import os

@MainActor
struct HotKeyRegistryDependencies {
    let notificationCenter: NotificationCenter
}

@MainActor
extension HotKeyRegistryDependencies {
    static let live = HotKeyRegistryDependencies(notificationCenter: .default)
}

/// 热键注册表
/// 管理所有热键绑定的存储和查询
@MainActor
final class HotKeyRegistry {

    private let logger = Logger(subsystem: "com.spokeanywhere", category: "HotKeyRegistry")
    private let dependencies: HotKeyRegistryDependencies

    /// 所有已注册的处理器
    private var handlers: [HotKeyType: HotKeyHandler] = [:]

    /// 快捷键变更观察者
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []

    init() {
        self.dependencies = .live
        setupObservers()
    }

    init(dependencies: HotKeyRegistryDependencies) {
        self.dependencies = dependencies
        setupObservers()
    }

    deinit {
        observers.forEach { dependencies.notificationCenter.removeObserver($0) }
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

    func reloadBinding(for type: HotKeyType) {
        handlers[type]?.reloadBinding()
    }

    func logReload(_ message: String) {
        logger.info("\(message, privacy: .public)")
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
        observeShortcutChange(AppSettings.shortcutDidChangeNotification, type: .recording, logMessage: "Recording shortcut reloaded")
        observeShortcutChange(AppSettings.quickAskShortcutDidChangeNotification, type: .quickAsk, logMessage: "Quick Ask shortcut reloaded")
        observeShortcutChange(AppSettings.messagePanelShortcutDidChangeNotification, type: .messagePanel, logMessage: "Message Panel shortcut reloaded")
        observeShortcutChange(AppSettings.liveCaptionShortcutDidChangeNotification, type: .liveCaption, logMessage: "Live Caption shortcut reloaded")
        observeShortcutChange(AppSettings.clipboardPipelineShortcutDidChangeNotification, type: .clipboardPipeline, logMessage: "Clipboard Pipeline shortcut reloaded")
        observeShortcutChange(AppSettings.screenshotShortcutDidChangeNotification, type: .screenshot, logMessage: "Screenshot shortcut reloaded")
    }

    private func observeShortcutChange(
        _ notificationName: Notification.Name,
        type: HotKeyType,
        logMessage: String
    ) {
        observers.append(dependencies.notificationCenter.addObserver(
            forName: notificationName,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            runHotKeyRegistryObserver(self, type: type, logMessage: logMessage)
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
