import AppKit
import Carbon.HIToolbox
import os

/// 全局热键监听器
/// 负责底层的 CGEvent tap 管理和事件分发
@MainActor
final class HotKeyListener {

    private let logger = Logger(subsystem: "com.spokeanywhere", category: "HotKeyListener")

    /// 事件处理器
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// 注册表引用
    private weak var registry: HotKeyRegistry?

    /// 事件路由回调（由 HotKeyService 设置，处理复杂的事件逻辑）
    var onEvent: ((_ type: CGEventType, _ keyCode: UInt32, _ flags: CGEventFlags) -> Bool)?

    /// 是否启用调试日志
    var debugKeyEvents = false

    init(registry: HotKeyRegistry) {
        self.registry = registry
    }

    // MARK: - Public API

    /// 注册全局事件监听
    func register() {
        let eventMask = (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.keyUp.rawValue) |
                        (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let listener = Unmanaged<HotKeyListener>.fromOpaque(refcon).takeUnretainedValue()
                return listener.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            logger.warning("Failed to create event tap. Check Accessibility permissions.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            logger.info("HotKey listener registered")
        }
    }

    /// 注销事件监听
    func unregister() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        logger.info("HotKey listener unregistered")
    }

    /// 启用/禁用事件监听
    func setEnabled(_ enabled: Bool) {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: enabled)
        }
    }

    /// 检查事件监听是否启用
    var isEnabled: Bool {
        guard let tap = eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    // MARK: - Event Handling

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // 处理 tap 被系统禁用的情况
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // 通过回调询问是否应该重新启用
            let shouldReenable = onEvent?(.tapDisabledByTimeout, 0, []) ?? true
            if shouldReenable {
                logger.warning("Event tap was disabled by system, re-enabling...")
                if let tap = eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            }
            return Unmanaged.passRetained(event)
        }

        let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        // 调试日志
        if debugKeyEvents && (type == .keyDown || type == .keyUp) {
            let typeStr = type == .keyDown ? "DOWN" : "UP"
            logger.debug("Key \(typeStr): code=\(keyCode) flags=\(String(describing: flags))")
        }

        // 通过回调路由事件
        if let onEvent = onEvent {
            let handled = onEvent(type, keyCode, flags)
            if handled {
                return nil  // 吞掉事件
            }
        }

        return Unmanaged.passRetained(event)
    }
}
