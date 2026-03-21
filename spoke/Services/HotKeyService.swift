import AppKit
import Carbon.HIToolbox
import os

@MainActor
struct HotKeyServiceDependencies {
    let appSettings: AppSettings
    let notificationCenter: NotificationCenter
}

@MainActor
extension HotKeyServiceDependencies {
    static let live = HotKeyServiceDependencies(
        appSettings: .shared,
        notificationCenter: .default
    )
}

/// 全局快捷键服务
/// 管理录音快捷键的注册和触发
@MainActor
final class HotKeyService {
    
    // MARK: - Singleton
    
    static let shared = HotKeyService(dependencies: .live)
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "HotKey")
    private let dependencies: HotKeyServiceDependencies
    
    // MARK: - Properties
    
    /// 录音开始时间（用于判断长按/短按）
    private var recordingStartTime: Date?
    
    /// 长按阈值（秒）
    private let holdThreshold: TimeInterval = 0.4
    
    /// 当前快捷键 keyCode
    private var currentKeyCode: UInt32 = UInt32(kVK_ANSI_R)
    
    /// 当前快捷键修饰符
    private var currentModifiers: NSEvent.ModifierFlags = .option
    
    /// Quick Ask 快捷键 keyCode
    private var quickAskKeyCode: UInt32 = UInt32(kVK_ANSI_T)
    
    /// Quick Ask 快捷键修饰符
    private var quickAskModifiers: NSEvent.ModifierFlags = .option
    
    /// Message Panel 快捷键 keyCode
    private var messagePanelKeyCode: UInt32 = UInt32(kVK_ANSI_P)
    
    /// Message Panel 快捷键修饰符
    private var messagePanelModifiers: NSEvent.ModifierFlags = .option
    
    /// Live Caption 快捷键 keyCode
    private var liveCaptionKeyCode: UInt32 = UInt32(kVK_ANSI_S)
    
    /// Live Caption 快捷键修饰符
    private var liveCaptionModifiers: NSEvent.ModifierFlags = .option
    
    /// Clipboard Pipeline 快捷键 keyCode (⌥V)
    private var clipboardPipelineKeyCode: UInt32 = UInt32(kVK_ANSI_V)
    
    /// Clipboard Pipeline 快捷键修饰符
    private var clipboardPipelineModifiers: NSEvent.ModifierFlags = .option
    
    /// Screenshot 快捷键 keyCode (⌥A)
    private var screenshotKeyCode: UInt32 = UInt32(kVK_ANSI_A)
    
    /// Screenshot 快捷键修饰符
    private var screenshotModifiers: NSEvent.ModifierFlags = .option
    
    /// 是否正在录音
    var isRecording = false
    
    /// 是否是 Toggle 模式触发的录音（用于区分长按结束后的逻辑）
    private var isToggleSession = false
    
    /// 是否处于 Quick Ask 模式
    var isQuickAskActive = false
    
    /// 事件处理器
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    /// 快捷键变更观察者
    private var shortcutObservers: [NSObjectProtocol] = []
    
    /// flagsChanged 防抖工作项（用于多屏切换时的二次确认）
    private var flagsDebounceWorkItem: DispatchWorkItem?
    
    /// 延迟停止 Task（用于取消之前的延迟停止）
    private var delayedStopTask: Task<Void, Never>?
    
    /// 当前录音会话 ID（用于确保延迟停止只影响对应会话）
    private var currentSessionId: UUID?
    
    /// 回调
    var onRecordingStart: (() -> Void)?
    var onRecordingStop: (() -> Void)?
    
    /// Quick Ask 回调
    var onQuickAskStart: (() -> Void)?
    var onQuickAskSend: (() -> Void)?
    
    /// Message Panel 回调
    var onMessagePanelToggle: (() -> Void)?
    
    /// Live Caption 回调
    var onLiveCaptionToggle: (() -> Void)?
    
    /// Clipboard Pipeline 回调
    var onClipboardPipelineTrigger: (() -> Void)?
    
    /// Screenshot 回调
    var onScreenshotTrigger: (() -> Void)?
    
    /// 打开设置回调
    var onOpenSettings: (() -> Void)?

    private struct EventMatchContext {
        let keyCode: UInt32
        let flags: CGEventFlags
        let isRecordingModifiersPressed: Bool
        let isRecordingKey: Bool
        let isQuickAskModifiersPressed: Bool
        let isQuickAskKey: Bool
        let isMessagePanelModifiersPressed: Bool
        let isMessagePanelKey: Bool
        let isLiveCaptionModifiersPressed: Bool
        let isLiveCaptionKey: Bool
        let isClipboardPipelineModifiersPressed: Bool
        let isClipboardPipelineKey: Bool
        let isScreenshotModifiersPressed: Bool
        let isScreenshotKey: Bool
        let isCommandPressed: Bool
        let isCommaKey: Bool
    }
    
    // MARK: - Init
    
    private init(
        dependencies: HotKeyServiceDependencies
    ) {
        self.dependencies = dependencies
        loadShortcutFromSettings()
        setupShortcutObserver()
    }

    deinit {
        shortcutObservers.forEach { dependencies.notificationCenter.removeObserver($0) }
    }
    
    private func loadShortcutFromSettings() {
        currentKeyCode = UInt32(dependencies.appSettings.shortcutKeyCode)
        currentModifiers = NSEvent.ModifierFlags(rawValue: UInt(dependencies.appSettings.shortcutModifiers))
        quickAskKeyCode = UInt32(dependencies.appSettings.quickAskKeyCode)
        quickAskModifiers = NSEvent.ModifierFlags(rawValue: UInt(dependencies.appSettings.quickAskModifiers))
        messagePanelKeyCode = UInt32(dependencies.appSettings.messagePanelKeyCode)
        messagePanelModifiers = NSEvent.ModifierFlags(rawValue: UInt(dependencies.appSettings.messagePanelModifiers))
        liveCaptionKeyCode = UInt32(dependencies.appSettings.liveCaptionKeyCode)
        liveCaptionModifiers = NSEvent.ModifierFlags(rawValue: UInt(dependencies.appSettings.liveCaptionModifiers))
        screenshotKeyCode = UInt32(dependencies.appSettings.screenshotKeyCode)
        screenshotModifiers = NSEvent.ModifierFlags(rawValue: UInt(dependencies.appSettings.screenshotModifiers))
    }
    
    private func setupShortcutObserver() {
        observeShortcutChange(AppSettings.shortcutDidChangeNotification) { service in
            service.reloadShortcut()
        }
        observeShortcutChange(AppSettings.quickAskShortcutDidChangeNotification) { service in
            service.reloadQuickAskShortcut()
        }
        observeShortcutChange(AppSettings.messagePanelShortcutDidChangeNotification) { service in
            service.reloadMessagePanelShortcut()
        }
        observeShortcutChange(AppSettings.liveCaptionShortcutDidChangeNotification) { service in
            service.reloadLiveCaptionShortcut()
        }
        observeShortcutChange(AppSettings.screenshotShortcutDidChangeNotification) { service in
            service.reloadScreenshotShortcut()
        }
    }

    private func observeShortcutChange(
        _ name: Notification.Name,
        action: @escaping @MainActor @Sendable (HotKeyService) -> Void
    ) {
        shortcutObservers.append(
            dependencies.notificationCenter.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    action(self)
                }
            }
        )
    }
    
    private func reloadScreenshotShortcut() {
        screenshotKeyCode = UInt32(self.dependencies.appSettings.screenshotKeyCode)
        screenshotModifiers = NSEvent.ModifierFlags(rawValue: UInt(self.dependencies.appSettings.screenshotModifiers))
        logger.info("🔄 Screenshot shortcut reloaded: \(self.dependencies.appSettings.screenshotShortcutDisplayString)")
    }
    
    private func reloadLiveCaptionShortcut() {
        liveCaptionKeyCode = UInt32(self.dependencies.appSettings.liveCaptionKeyCode)
        liveCaptionModifiers = NSEvent.ModifierFlags(rawValue: UInt(self.dependencies.appSettings.liveCaptionModifiers))
        logger.info("🔄 Live Caption shortcut reloaded: \(self.dependencies.appSettings.liveCaptionShortcutDisplayString)")
    }
    
    private func reloadMessagePanelShortcut() {
        messagePanelKeyCode = UInt32(self.dependencies.appSettings.messagePanelKeyCode)
        messagePanelModifiers = NSEvent.ModifierFlags(rawValue: UInt(self.dependencies.appSettings.messagePanelModifiers))
        logger.info("🔄 Message Panel shortcut reloaded: \(self.dependencies.appSettings.messagePanelShortcutDisplayString)")
    }
    
    private func reloadQuickAskShortcut() {
        quickAskKeyCode = UInt32(self.dependencies.appSettings.quickAskKeyCode)
        quickAskModifiers = NSEvent.ModifierFlags(rawValue: UInt(self.dependencies.appSettings.quickAskModifiers))
        logger.info("🔄 Quick Ask shortcut reloaded: \(self.dependencies.appSettings.quickAskShortcutDisplayString)")
    }
    
    /// 重新加载快捷键配置并重新注册
    func reloadShortcut() {
        loadShortcutFromSettings()
        
        // 如果已注册，重新注册
        if eventTap != nil {
            unregister()
            register()
        }
        
        logger.info("🔄 Shortcut reloaded: \(self.dependencies.appSettings.shortcutDisplayString)")
    }
    
    // MARK: - Public API
    
    /// 注册全局快捷键
    func register() {
        // 创建事件监听
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let service = Unmanaged<HotKeyService>.fromOpaque(refcon).takeUnretainedValue()
                return service.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            logger.warning("⚠️ Failed to create event tap. Check Accessibility permissions.")
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            logger.info("✅ HotKey registered: \(self.dependencies.appSettings.shortcutDisplayString)")
        }
    }
    
    /// 注销快捷键
    func unregister() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }
    
    // MARK: - Private
    
    /// 是否启用调试日志（用于排查输入法问题）
    var debugKeyEvents = false
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if let tapResult = handleTapDisabledEvent(type: type, event: event) {
            return tapResult
        }

        let context = makeEventMatchContext(for: event)
        if let quickAskBypassResult = handleQuickAskBypassIfNeeded(type: type, context: context, event: event) {
            return quickAskBypassResult
        }

        logDebugKeyEventIfNeeded(type: type, context: context)

        switch type {
        case .keyDown:
            return routeKeyDown(context, event: event)
        case .keyUp:
            return routeKeyUp(context, event: event)
        case .flagsChanged:
            return routeFlagsChanged(context, event: event)
        default:
            return passThrough(event)
        }
    }

    private func handleTapDisabledEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .tapDisabledByTimeout || type == .tapDisabledByUserInput else {
            return nil
        }
        guard !isQuickAskActive else {
            return passThrough(event)
        }

        logger.warning("⚠️ Event tap was disabled by system, re-enabling...")
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return passThrough(event)
    }

    private func makeEventMatchContext(for event: CGEvent) -> EventMatchContext {
        let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        return EventMatchContext(
            keyCode: keyCode,
            flags: flags,
            isRecordingModifiersPressed: checkModifiersMatch(flags: flags, target: currentModifiers),
            isRecordingKey: keyCode == currentKeyCode,
            isQuickAskModifiersPressed: checkModifiersMatch(flags: flags, target: quickAskModifiers),
            isQuickAskKey: keyCode == quickAskKeyCode,
            isMessagePanelModifiersPressed: checkModifiersMatch(flags: flags, target: messagePanelModifiers),
            isMessagePanelKey: keyCode == messagePanelKeyCode,
            isLiveCaptionModifiersPressed: checkModifiersMatch(flags: flags, target: liveCaptionModifiers),
            isLiveCaptionKey: keyCode == liveCaptionKeyCode,
            isClipboardPipelineModifiersPressed: checkModifiersMatch(flags: flags, target: clipboardPipelineModifiers),
            isClipboardPipelineKey: keyCode == clipboardPipelineKeyCode,
            isScreenshotModifiersPressed: checkModifiersMatch(flags: flags, target: screenshotModifiers),
            isScreenshotKey: keyCode == screenshotKeyCode,
            isCommandPressed: checkModifiersMatch(flags: flags, target: .command),
            isCommaKey: keyCode == UInt32(kVK_ANSI_Comma)
        )
    }

    private func handleQuickAskBypassIfNeeded(
        type: CGEventType,
        context: EventMatchContext,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        guard isQuickAskActive else { return nil }

        if type == .keyDown && context.isQuickAskKey && context.isQuickAskModifiersPressed {
            handleQuickAskKeyDown()
            return nil
        }

        return passThrough(event)
    }

    private func logDebugKeyEventIfNeeded(type: CGEventType, context: EventMatchContext) {
        guard debugKeyEvents, type == .keyDown || type == .keyUp else { return }

        let typeStr = type == .keyDown ? "↓" : "↑"
        let char = keyCodeToChar(context.keyCode)
        let modStr = flagsToString(context.flags)
        let qaState = isQuickAskActive
        let tapEnabled = eventTap != nil ? CGEvent.tapIsEnabled(tap: eventTap!) : false
        logger.debug("🔑 \(typeStr) key=\(context.keyCode)(\(char)) mod=[\(modStr)] qa=\(qaState) tap=\(tapEnabled ? "ON" : "OFF")")
    }

    private func routeKeyDown(_ context: EventMatchContext, event: CGEvent) -> Unmanaged<CGEvent>? {
        if context.isCommaKey && context.isCommandPressed {
            guard NSApp.isActive else {
                return passThrough(event)
            }
            handleOpenSettings()
            return nil
        }

        if context.isQuickAskKey && context.isQuickAskModifiersPressed {
            handleQuickAskKeyDown()
            return nil
        }

        if context.isMessagePanelKey && context.isMessagePanelModifiersPressed {
            handleMessagePanelToggle()
            return nil
        }

        if context.isLiveCaptionKey && context.isLiveCaptionModifiersPressed {
            handleLiveCaptionToggle()
            return nil
        }

        if context.isClipboardPipelineKey && context.isClipboardPipelineModifiersPressed {
            handleClipboardPipelineTrigger()
            return nil
        }

        if context.isScreenshotKey && context.isScreenshotModifiersPressed {
            handleScreenshotTrigger()
            return nil
        }

        if context.isRecordingKey && context.isRecordingModifiersPressed {
            handleKeyDown()
            return nil
        }

        return passThrough(event)
    }

    private func routeKeyUp(_ context: EventMatchContext, event: CGEvent) -> Unmanaged<CGEvent>? {
        if context.isQuickAskKey && context.isQuickAskModifiersPressed && isQuickAskActive {
            return nil
        }

        if context.isRecordingKey && isRecording {
            logger.info("⬆️ [keyUp] R键松开，触发 handleKeyUp")
            handleKeyUp()
            return nil
        }

        return passThrough(event)
    }

    private func routeFlagsChanged(_ context: EventMatchContext, event: CGEvent) -> Unmanaged<CGEvent>? {
        let modifiersReleased = !context.isRecordingModifiersPressed
        if modifiersReleased {
            logger.info("🚩 [flagsChanged] 修饰键松开检测 | modifiersReleased=true")
        }

        dispatchOnMain { service in
            if modifiersReleased && service.isRecording && !service.isQuickAskActive {
                service.logger.info("🚩 [flagsChanged] 调度 scheduleModifierReleaseCheck")
                service.scheduleModifierReleaseCheck()
            }
        }

        return passThrough(event)
    }

    private func passThrough(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        Unmanaged.passRetained(event)
    }

    private func dispatchOnMain(_ work: @escaping (HotKeyService) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            work(self)
        }
    }

    private func invokeCallbackOnMain(_ callback: @escaping (HotKeyService) -> (() -> Void)?) {
        dispatchOnMain { service in
            callback(service)?()
        }
    }
    
    /// 检查当前按下的修饰键是否匹配目标配置（严格匹配）
    private func checkModifiersMatch(flags: CGEventFlags, target: NSEvent.ModifierFlags) -> Bool {
        // 提取当前按下的所有修饰键
        var currentFlags: NSEvent.ModifierFlags = []
        
        if flags.contains(.maskAlternate) { currentFlags.insert(.option) }
        if flags.contains(.maskCommand) { currentFlags.insert(.command) }
        if flags.contains(.maskControl) { currentFlags.insert(.control) }
        if flags.contains(.maskShift) { currentFlags.insert(.shift) }
        
        // 提取目标修饰键（只关心主要的四个：opt, cmd, ctrl, shift）
        let targetFlags = target.intersection([.option, .command, .control, .shift])
        
        // 必须完全相等（不能多按，也不能少按）
        return currentFlags == targetFlags
    }
    
    // MARK: - Debug Helpers
    
    /// keyCode 转字符（调试用）
    private func keyCodeToChar(_ keyCode: UInt32) -> String {
        #if DEBUG
        // 常用键码映射表
        let keyMap: [Int: String] = [
            kVK_ANSI_A: "A", kVK_ANSI_S: "S", kVK_ANSI_D: "D", kVK_ANSI_F: "F", kVK_ANSI_H: "H", kVK_ANSI_G: "G", kVK_ANSI_Z: "Z", kVK_ANSI_X: "X", kVK_ANSI_C: "C", kVK_ANSI_V: "V",
            kVK_ANSI_B: "B", kVK_ANSI_Q: "Q", kVK_ANSI_W: "W", kVK_ANSI_E: "E", kVK_ANSI_R: "R", kVK_ANSI_Y: "Y", kVK_ANSI_T: "T", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
            kVK_ANSI_4: "4", kVK_ANSI_6: "6", kVK_ANSI_5: "5", kVK_ANSI_Equal: "=", kVK_ANSI_9: "9", kVK_ANSI_7: "7", kVK_ANSI_Minus: "-", kVK_ANSI_8: "8", kVK_ANSI_0: "0", kVK_ANSI_RightBracket: "]",
            kVK_ANSI_O: "O", kVK_ANSI_U: "U", kVK_ANSI_LeftBracket: "[", kVK_ANSI_I: "I", kVK_ANSI_P: "P", kVK_ANSI_L: "L", kVK_ANSI_J: "J", kVK_ANSI_Quote: "'", kVK_ANSI_K: "K", kVK_ANSI_Semicolon: ";",
            kVK_ANSI_Backslash: "\\", kVK_ANSI_Comma: ",", kVK_ANSI_Slash: "/", kVK_ANSI_N: "N", kVK_ANSI_M: "M", kVK_ANSI_Period: ".", kVK_ANSI_Grave: "`", kVK_ANSI_KeypadDecimal: ".",
            kVK_ANSI_KeypadMultiply: "*", kVK_ANSI_KeypadPlus: "+", kVK_ANSI_KeypadClear: "Clear", kVK_ANSI_KeypadDivide: "/", kVK_ANSI_KeypadEnter: "Enter", kVK_ANSI_KeypadMinus: "-", kVK_ANSI_KeypadEquals: "=",
            kVK_ANSI_Keypad0: "0", kVK_ANSI_Keypad1: "1", kVK_ANSI_Keypad2: "2", kVK_ANSI_Keypad3: "3", kVK_ANSI_Keypad4: "4", kVK_ANSI_Keypad5: "5", kVK_ANSI_Keypad6: "6", kVK_ANSI_Keypad7: "7",
            kVK_ANSI_Keypad8: "8", kVK_ANSI_Keypad9: "9", kVK_Return: "⏎", kVK_Tab: "⇥", kVK_Space: "␣", kVK_Delete: "⌫", kVK_Escape: "⎋", kVK_Command: "⌘", kVK_Shift: "⇧", kVK_CapsLock: "⇪", kVK_Option: "⌥",
            kVK_Control: "⌃", kVK_RightShift: "⇧", kVK_RightOption: "⌥", kVK_RightControl: "⌃", kVK_Function: "Fn", kVK_F17: "F17", kVK_VolumeUp: "Vol+", kVK_VolumeDown: "Vol-", kVK_Mute: "Mute",
            kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20", kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F3: "F3", kVK_F8: "F8", kVK_F9: "F9", kVK_F11: "F11", kVK_F13: "F13", kVK_F16: "F16",
            kVK_F14: "F14", kVK_F10: "F10", kVK_F12: "F12", kVK_F15: "F15", kVK_Help: "Help", kVK_Home: "Home", kVK_PageUp: "PgUp", kVK_ForwardDelete: "Del", kVK_F4: "F4", kVK_End: "End",
            kVK_F2: "F2", kVK_PageDown: "PgDn", kVK_F1: "F1", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_DownArrow: "↓", kVK_UpArrow: "↑"
        ]
        
        return keyMap[Int(keyCode)] ?? "?"
        #else
        return "?"
        #endif
    }
    
    /// flags 转字符串（调试用）
    private func flagsToString(_ flags: CGEventFlags) -> String {
        var parts: [String] = []
        if flags.contains(.maskCommand) { parts.append("⌘") }
        if flags.contains(.maskAlternate) { parts.append("⌥") }
        if flags.contains(.maskControl) { parts.append("⌃") }
        if flags.contains(.maskShift) { parts.append("⇧") }
        return parts.isEmpty ? "none" : parts.joined()
    }
    
    // MARK: - Modifier Release Check (Multi-Display Fix)
    
    /// 延迟检查修饰键是否真的松开（修复多屏切换时的虚假事件）
    private func scheduleModifierReleaseCheck() {
        // 如果已经是 Toggle 模式，不需要检查修饰键释放
        if isToggleSession {
            logger.debug("🔍 scheduleModifierReleaseCheck: Toggle mode, skip")
            return
        }
        
        // 取消之前的检查（防抖）
        flagsDebounceWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // 再次检查 Toggle 模式（可能在等待期间已经切换）
            if self.isToggleSession {
                self.logger.debug("🔍 Modifier check: Toggle mode now, skip")
                return
            }
            
            // 100ms 后再次检查当前修饰键状态
            let currentFlags = NSEvent.modifierFlags
            let targetFlags = self.currentModifiers.intersection([.option, .command, .control, .shift])
            
            var actualFlags: NSEvent.ModifierFlags = []
            if currentFlags.contains(.option) { actualFlags.insert(.option) }
            if currentFlags.contains(.command) { actualFlags.insert(.command) }
            if currentFlags.contains(.control) { actualFlags.insert(.control) }
            if currentFlags.contains(.shift) { actualFlags.insert(.shift) }
            
            // 如果修饰键确实已松开，才停止录音
            if actualFlags != targetFlags {
                self.logger.info("🔍 Modifier release confirmed after delay check")
                self.handleRelease(fromKeyUp: false)
            } else {
                self.logger.info("🔍 Modifier still held, ignoring false flagsChanged event (multi-display fix)")
            }
        }
        
        flagsDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }
    
    // MARK: - Settings Handler
    
    private func handleOpenSettings() {
        invokeCallbackOnMain { $0.onOpenSettings }
    }
    
    // MARK: - Quick Ask Handlers
    
    private func handleQuickAskKeyDown() {
        if !isQuickAskActive {
            // 开始 Quick Ask
            startQuickAsk()
        } else {
            // 已经在 Quick Ask 中，再按一次触发发送
            sendQuickAsk()
        }
    }
    
    private func startQuickAsk() {
        dispatchOnMain { service in
            service.isQuickAskActive = true
            service.onQuickAskStart?()
        }
        logger.info("🚀 Quick Ask started")
    }
    
    private func sendQuickAsk() {
        dispatchOnMain { service in
            service.isQuickAskActive = false
            service.onQuickAskSend?()
        }
        logger.info("📤 Quick Ask sending")
    }
    
    /// 重置 Quick Ask 状态
    func resetQuickAskState() {
        isQuickAskActive = false
        // 重新启用 event tap
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        logger.info("🔄 Quick Ask state reset, event tap re-enabled")
    }
    
    /// 设置 Quick Ask 激活状态
    /// 注意：不禁用 event tap，而是在 handleEvent 中智能处理
    /// 这样 Option+T 仍能被拦截用于发送
    func setQuickAskActive(_ active: Bool) {
        isQuickAskActive = active
        logger.info("🔥 Quick Ask active: \(active)")
    }
    
    // MARK: - Message Panel Handler
    
    private func handleMessagePanelToggle() {
        invokeCallbackOnMain { $0.onMessagePanelToggle }
        logger.info("📋 Message Panel toggle triggered")
    }
    
    // MARK: - Live Caption Handler
    
    private func handleLiveCaptionToggle() {
        invokeCallbackOnMain { $0.onLiveCaptionToggle }
        logger.info("🎬 Live Caption toggle triggered")
    }
    
    // MARK: - Clipboard Pipeline Handler
    
    private func handleClipboardPipelineTrigger() {
        invokeCallbackOnMain { $0.onClipboardPipelineTrigger }
        logger.info("📋 Clipboard Pipeline triggered")
    }
    
    // MARK: - Screenshot Handler
    
    private func handleScreenshotTrigger() {
        invokeCallbackOnMain { $0.onScreenshotTrigger }
    }
    
    // MARK: - Recording Handlers
    
    private func handleKeyDown() {
        dispatchOnMain { service in
            // 诊断日志：记录当前状态
            let taskStatus = service.delayedStopTask != nil ? "SET" : "nil"
            service.logger.info("⬇️ [keyDown] isRecording=\(service.isRecording), isToggleSession=\(service.isToggleSession), delayedStopTask=\(taskStatus, privacy: .public)")
            
            if !service.isRecording {
                // 开始新录音
                // 1. 先取消之前的延迟停止（如果有）
                service.delayedStopTask?.cancel()
                service.delayedStopTask = nil
                
                // 2. 创建新的会话 ID
                service.currentSessionId = UUID()
                
                // 3. 开始录音
                service.isRecording = true
                service.recordingStartTime = Date()
                service.isToggleSession = false
                service.onRecordingStart?()
                
                service.logger.info("🎙️ New recording session started: \(service.currentSessionId?.uuidString.prefix(8) ?? "nil") | startTime=\(service.recordingStartTime?.timeIntervalSince1970 ?? 0)")
            } else {
                // 正在录音中
                service.logger.debug("⬇️ [keyDown] 已在录音中, isToggleSession=\(service.isToggleSession), delayedStopTask=\(service.delayedStopTask != nil ? "SET" : "nil")")
                
                if service.isToggleSession {
                    // 如果已经是 Toggle 模式（之前短按触发），再次按下则延迟停止
                    service.logger.info("🔄 Toggle mode: 第二次按下，Stopping in 0.8s...")
                    service.isToggleSession = false  // 标记为停止中，防止重复触发
                    
                    // 捕获当前会话 ID
                    let sessionToStop = service.currentSessionId
                    
                    // 取消之前的延迟停止 Task（如果有）
                    service.delayedStopTask?.cancel()
                    
                    // 延迟 0.8 秒再停止录音，让语音识别处理尾音
                    service.delayedStopTask = Task {
                        try? await Task.sleep(for: .milliseconds(800))
                        await MainActor.run {
                            // Task 完成后清空引用
                            service.delayedStopTask = nil
                            
                            // 确保是同一个会话，且仍在录音中
                            guard service.isRecording,
                                  service.currentSessionId == sessionToStop else {
                                service.logger.debug("🔍 Delayed stop skipped: session changed or not recording")
                                return
                            }
                            
                            service.isRecording = false
                            service.recordingStartTime = nil
                            service.currentSessionId = nil
                            service.onRecordingStop?()
                        }
                    }
                } else if service.delayedStopTask != nil {
                    // ⚠️ 在延迟停止期间再次按下：用户想开始新录音
                    // 取消延迟停止，停止当前录音，然后开始新录音
                    service.logger.info("🔄 [keyDown] 延迟停止期间按下，取消延迟并开始新录音")
                    service.delayedStopTask?.cancel()
                    service.delayedStopTask = nil
                    
                    // 先停止当前录音
                    service.isRecording = false
                    service.recordingStartTime = nil
                    let oldSessionId = service.currentSessionId
                    service.currentSessionId = nil
                    service.onRecordingStop?()
                    
                    // 立即开始新录音
                    service.currentSessionId = UUID()
                    service.isRecording = true
                    service.recordingStartTime = Date()
                    service.isToggleSession = false
                    service.onRecordingStart?()
                    
                    service.logger.info("🎙️ New recording session started (interrupted delayed stop): old=\(oldSessionId?.uuidString.prefix(8) ?? "nil") → new=\(service.currentSessionId?.uuidString.prefix(8) ?? "nil")")
                }
                // 如果是 Hold 模式（正在按住），忽略重复的 KeyDown
            }
        }
    }
    
    private func handleKeyUp() {
        dispatchOnMain { service in
            // keyUp 是明确的结束信号，取消任何待执行的防抖检查
            // 必须在主线程执行 cancel，否则与 scheduleModifierReleaseCheck 的 workItem 存在竞态条件
            service.flagsDebounceWorkItem?.cancel()
            service.flagsDebounceWorkItem = nil
            
            service.logger.debug("⬆️ [keyUp] 已取消 flagsDebounceWorkItem，调用 handleRelease")
            service.handleRelease(fromKeyUp: true)
        }
    }
    
    /// 处理按键释放
    /// - Parameter fromKeyUp: true 表示来自 keyUp 事件，false 表示来自 flagsChanged 事件
    private func handleRelease(fromKeyUp: Bool) {
        dispatchOnMain { service in
            // 调试日志：当前状态
            service.logger.debug("🔍 handleRelease: isRecording=\(service.isRecording), isToggleSession=\(service.isToggleSession), fromKeyUp=\(fromKeyUp)")
            
            guard service.isRecording else {
                service.logger.debug("🔍 handleRelease: not recording, skip")
                return
            }
            
            if service.isToggleSession {
                // Toggle 模式下，松开键不停止录音（等待第二次按下）
                service.logger.debug("🔍 handleRelease: Toggle mode, skip")
                return
            }
            
            // 检查按压时长
            guard let startTime = service.recordingStartTime else {
                service.logger.debug("🔍 handleRelease: no startTime, skip")
                return
            }
            let duration = Date().timeIntervalSince(startTime)
            service.logger.info("🔍 handleRelease: duration=\(String(format: "%.3f", duration))s, threshold=\(service.holdThreshold)s, fromKeyUp=\(fromKeyUp)")
            
            if duration < service.holdThreshold && fromKeyUp {
                // 短按：切换到 Toggle 模式，继续录音
                // ⚠️ 只有 keyUp 事件才能触发 Toggle 模式，避免 flagsChanged 误判
                service.isToggleSession = true
                service.logger.info("👆 Short press (\(String(format: "%.2f", duration))s) detected. Switched to Toggle mode.")
            } else if duration < service.holdThreshold && !fromKeyUp {
                // flagsChanged 触发但 duration < holdThreshold，跳过（等待 keyUp 来决定是否进入 Toggle 模式）
                service.logger.debug("🔍 handleRelease: flagsChanged with short duration, waiting for keyUp")
                return
            } else {
                // 长按：松手后延迟停止，以捕获尾音
                // 检查是否已经设置了延迟停止任务，避免重复触发
                if service.delayedStopTask != nil {
                    service.logger.debug("🔍 handleRelease: delayedStopTask already set, skip")
                    return
                }
                
                service.logger.info("✋ Long press (\(String(format: "%.2f", duration))s) released. Stopping in 0.8s...")
                
                // 取消任何待执行的修饰键检查，防止 flagsChanged 的 async 块后执行导致重复触发
                service.flagsDebounceWorkItem?.cancel()
                service.flagsDebounceWorkItem = nil
                
                // 捕获当前会话 ID
                let sessionToStop = service.currentSessionId
                
                // 延迟 0.8 秒再停止录音，让语音识别处理尾音
                service.delayedStopTask = Task {
                    try? await Task.sleep(for: .milliseconds(800))
                    await MainActor.run {
                        // Task 完成后清空引用
                        service.delayedStopTask = nil
                        
                        // 确保是同一个会话，且仍在录音中，且不是 Toggle 模式
                        guard service.isRecording,
                              service.currentSessionId == sessionToStop,
                              !service.isToggleSession else {
                            service.logger.debug("🔍 Long press delayed stop skipped: session changed or state invalid")
                            return
                        }
                        
                        service.isRecording = false
                        service.recordingStartTime = nil
                        service.currentSessionId = nil
                        service.onRecordingStop?()
                    }
                }
            }
        }
    }
    
    /// 强制重置状态（用于异常恢复或取消录音）
    func resetState() {
        isRecording = false
        isToggleSession = false
        recordingStartTime = nil
        currentSessionId = nil
        
        // 取消任何待执行的延迟停止
        delayedStopTask?.cancel()
        delayedStopTask = nil
        
        // 取消任何待执行的防抖检查
        flagsDebounceWorkItem?.cancel()
        flagsDebounceWorkItem = nil
        
        logger.info("🔄 HotKey state reset")
    }
}
