import AppKit
import Carbon.HIToolbox
import os

/// 全局快捷键服务
/// 管理录音快捷键的注册和触发
@MainActor
final class HotKeyService {
    
    // MARK: - Singleton
    
    static let shared = HotKeyService()
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "HotKey")
    
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
    private var shortcutObserver: NSObjectProtocol?
    
    /// flagsChanged 防抖工作项（用于多屏切换时的二次确认）
    private var flagsDebounceWorkItem: DispatchWorkItem?
    
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
    
    /// 打开设置回调
    var onOpenSettings: (() -> Void)?
    
    // MARK: - Init
    
    private init() {
        loadShortcutFromSettings()
        setupShortcutObserver()
    }
    
    private func loadShortcutFromSettings() {
        let settings = AppSettings.shared
        currentKeyCode = UInt32(settings.shortcutKeyCode)
        currentModifiers = NSEvent.ModifierFlags(rawValue: UInt(settings.shortcutModifiers))
        quickAskKeyCode = UInt32(settings.quickAskKeyCode)
        quickAskModifiers = NSEvent.ModifierFlags(rawValue: UInt(settings.quickAskModifiers))
        messagePanelKeyCode = UInt32(settings.messagePanelKeyCode)
        messagePanelModifiers = NSEvent.ModifierFlags(rawValue: UInt(settings.messagePanelModifiers))
        liveCaptionKeyCode = UInt32(settings.liveCaptionKeyCode)
        liveCaptionModifiers = NSEvent.ModifierFlags(rawValue: UInt(settings.liveCaptionModifiers))
    }
    
    private func setupShortcutObserver() {
        shortcutObserver = NotificationCenter.default.addObserver(
            forName: AppSettings.shortcutDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reloadShortcut()
            }
        }
        
        // Quick Ask 快捷键变更观察
        NotificationCenter.default.addObserver(
            forName: AppSettings.quickAskShortcutDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reloadQuickAskShortcut()
            }
        }
        
        // Message Panel 快捷键变更观察
        NotificationCenter.default.addObserver(
            forName: AppSettings.messagePanelShortcutDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reloadMessagePanelShortcut()
            }
        }
        
        // Live Caption 快捷键变更观察
        NotificationCenter.default.addObserver(
            forName: AppSettings.liveCaptionShortcutDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reloadLiveCaptionShortcut()
            }
        }
    }
    
    private func reloadLiveCaptionShortcut() {
        let settings = AppSettings.shared
        liveCaptionKeyCode = UInt32(settings.liveCaptionKeyCode)
        liveCaptionModifiers = NSEvent.ModifierFlags(rawValue: UInt(settings.liveCaptionModifiers))
        logger.info("🔄 Live Caption shortcut reloaded: \(settings.liveCaptionShortcutDisplayString)")
    }
    
    private func reloadMessagePanelShortcut() {
        let settings = AppSettings.shared
        messagePanelKeyCode = UInt32(settings.messagePanelKeyCode)
        messagePanelModifiers = NSEvent.ModifierFlags(rawValue: UInt(settings.messagePanelModifiers))
        logger.info("🔄 Message Panel shortcut reloaded: \(settings.messagePanelShortcutDisplayString)")
    }
    
    private func reloadQuickAskShortcut() {
        let settings = AppSettings.shared
        quickAskKeyCode = UInt32(settings.quickAskKeyCode)
        quickAskModifiers = NSEvent.ModifierFlags(rawValue: UInt(settings.quickAskModifiers))
        logger.info("🔄 Quick Ask shortcut reloaded: \(settings.quickAskShortcutDisplayString)")
    }
    
    /// 重新加载快捷键配置并重新注册
    func reloadShortcut() {
        loadShortcutFromSettings()
        
        // 如果已注册，重新注册
        if eventTap != nil {
            unregister()
            register()
        }
        
        logger.info("🔄 Shortcut reloaded: \(AppSettings.shared.shortcutDisplayString)")
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
            logger.info("✅ HotKey registered: \(AppSettings.shared.shortcutDisplayString)")
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
        // 处理 tap 被系统禁用的情况（超时或其他原因）
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // 🔥 如果是 Quick Ask 主动禁用的，不要自动重新启用！
            if isQuickAskActive {
                print("🔥 Event tap disabled event received, but Quick Ask is active - NOT re-enabling")
                return Unmanaged.passRetained(event)
            }
            logger.warning("⚠️ Event tap was disabled by system, re-enabling...")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }
        
        // 🔥🔥🔥 Quick Ask 激活时，完全不处理任何键盘事件（除了 Quick Ask 快捷键本身）
        // 这是解决输入法问题的关键：让事件完全绕过 event tap
        if isQuickAskActive {
            let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            
            // 只处理 Quick Ask 快捷键（用于再次按下发送）
            let isQuickAskModifiersPressed = checkModifiersMatch(flags: flags, target: quickAskModifiers)
            let isQuickAskKey = keyCode == quickAskKeyCode
            
            if type == .keyDown && isQuickAskKey && isQuickAskModifiersPressed {
                handleQuickAskKeyDown()
                return nil
            }
            
            // 其他所有事件都直接放行，不做任何处理
            return Unmanaged.passRetained(event)
        }
        
        let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        
        // 调试日志（直接 print 到终端，方便调试）
        if debugKeyEvents && (type == .keyDown || type == .keyUp) {
            let typeStr = type == .keyDown ? "↓" : "↑"
            let char = keyCodeToChar(keyCode)
            let modStr = flagsToString(flags)
            let qaState = self.isQuickAskActive
            _ = self.isRecording
            // 检查 tap 是否应该被禁用
            let tapEnabled = eventTap != nil ? CGEvent.tapIsEnabled(tap: eventTap!) : false
            print("🔑 \(typeStr) key=\(keyCode)(\(char)) mod=[\(modStr)] qa=\(qaState) tap=\(tapEnabled ? "ON" : "OFF")")
        }
        
        // 检查是否是录音快捷键
        let isRecordingModifiersPressed = checkModifiersMatch(flags: flags, target: currentModifiers)
        let isRecordingKey = keyCode == currentKeyCode
        
        // 检查是否是 Quick Ask 快捷键
        let isQuickAskModifiersPressed = checkModifiersMatch(flags: flags, target: quickAskModifiers)
        let isQuickAskKey = keyCode == quickAskKeyCode
        
        // 检查是否是 Message Panel 快捷键
        let isMessagePanelModifiersPressed = checkModifiersMatch(flags: flags, target: messagePanelModifiers)
        let isMessagePanelKey = keyCode == messagePanelKeyCode
        
        // 检查是否是 Live Caption 快捷键
        let isLiveCaptionModifiersPressed = checkModifiersMatch(flags: flags, target: liveCaptionModifiers)
        let isLiveCaptionKey = keyCode == liveCaptionKeyCode
        
        // 检查是否是 Cmd+逗号 (打开设置)
        let isCommandPressed = checkModifiersMatch(flags: flags, target: .command)
        let isCommaKey = keyCode == UInt32(kVK_ANSI_Comma)
        
        switch type {
        case .keyDown:
            // Cmd+逗号 打开设置（仅当应用在前台时响应）
            if isCommaKey && isCommandPressed {
                if NSApp.isActive {
                    handleOpenSettings()
                    return nil
                }
                // 应用不在前台，放行给其他应用
                return Unmanaged.passRetained(event)
            }
            
            // Quick Ask 快捷键
            if isQuickAskKey && isQuickAskModifiersPressed {
                handleQuickAskKeyDown()
                return nil
            }
            
            // Message Panel 快捷键
            if isMessagePanelKey && isMessagePanelModifiersPressed {
                handleMessagePanelToggle()
                return nil
            }
            
            // Live Caption 快捷键
            if isLiveCaptionKey && isLiveCaptionModifiersPressed {
                handleLiveCaptionToggle()
                return nil
            }
            
            // 录音快捷键
            if isRecordingKey && isRecordingModifiersPressed {
                handleKeyDown()
                return nil
            }
            
            return Unmanaged.passRetained(event)
            
        case .keyUp:
            // Quick Ask keyUp - 必须同时检查修饰键，否则会吞掉普通输入的 keyUp 事件
            if isQuickAskKey && isQuickAskModifiersPressed && isQuickAskActive {
                // Quick Ask 不响应 keyUp（只用 keyDown 触发发送）
                return nil
            }
            
            // 录音 keyUp - 同样需要检查修饰键
            if isRecordingKey && isRecordingModifiersPressed && isRecording {
                handleKeyUp()
                return nil
            }
            
            return Unmanaged.passRetained(event)
            
        case .flagsChanged:
            // 监听修饰键松开（仅针对录音模式）
            // 多显示器/Space切换时 macOS 会发送虚假的 flagsChanged 事件
            // 使用延迟二次确认机制：等待 100ms 后再次检查修饰键状态
            if !isRecordingModifiersPressed && isRecording && !isQuickAskActive {
                scheduleModifierReleaseCheck()
            }
            return Unmanaged.passRetained(event)
            
        default:
            break
        }
        
        return Unmanaged.passRetained(event)
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
                self.handleRelease()
            } else {
                self.logger.info("🔍 Modifier still held, ignoring false flagsChanged event (multi-display fix)")
            }
        }
        
        flagsDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }
    
    // MARK: - Settings Handler
    
    private func handleOpenSettings() {
        // 使用 DispatchQueue.main 而不是 Task，因为 CGEvent 回调不在主线程
        DispatchQueue.main.async { [weak self] in
            self?.onOpenSettings?()
        }
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
        // 使用 DispatchQueue.main 而不是 Task，因为 CGEvent 回调不在主线程
        DispatchQueue.main.async { [weak self] in
            self?.isQuickAskActive = true
            self?.onQuickAskStart?()
        }
        logger.info("🚀 Quick Ask started")
    }
    
    private func sendQuickAsk() {
        DispatchQueue.main.async { [weak self] in
            self?.isQuickAskActive = false
            self?.onQuickAskSend?()
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
    
    /// 设置 Quick Ask 激活状态（用于控制 event tap）
    func setQuickAskActive(_ active: Bool) {
        isQuickAskActive = active
        // Quick Ask 激活时禁用 event tap，避免干扰输入法
        if let tap = eventTap {
            let shouldEnable = !active
            print("🔥 Calling CGEvent.tapEnable(enable: \(shouldEnable)) on tap: \(tap)")
            CGEvent.tapEnable(tap: tap, enable: shouldEnable)
            // 验证是否生效
            let actualState = CGEvent.tapIsEnabled(tap: tap)
            print("🔥 Event tap actual state after toggle: \(actualState ? "ON" : "OFF")")
            if actualState != shouldEnable {
                print("⚠️⚠️⚠️ tapEnable FAILED! Expected \(shouldEnable ? "ON" : "OFF") but got \(actualState ? "ON" : "OFF")")
            }
        } else {
            print("⚠️ Event tap is nil, cannot toggle!")
        }
    }
    
    // MARK: - Message Panel Handler
    
    private func handleMessagePanelToggle() {
        DispatchQueue.main.async { [weak self] in
            self?.onMessagePanelToggle?()
        }
        logger.info("📋 Message Panel toggle triggered")
    }
    
    // MARK: - Live Caption Handler
    
    private func handleLiveCaptionToggle() {
        DispatchQueue.main.async { [weak self] in
            self?.onLiveCaptionToggle?()
        }
        logger.info("🎬 Live Caption toggle triggered")
    }
    
    // MARK: - Recording Handlers
    
    private func handleKeyDown() {
        // CGEvent 回调不在主线程，所有状态访问需要在主线程进行
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if !self.isRecording {
                // 开始录音
                self.isRecording = true
                self.recordingStartTime = Date()
                self.isToggleSession = false
                self.onRecordingStart?()
            } else {
                // 正在录音中
                if self.isToggleSession {
                    // 如果已经是 Toggle 模式（之前短按触发），再次按下则停止
                    self.isRecording = false
                    self.isToggleSession = false
                    self.recordingStartTime = nil
                    self.onRecordingStop?()
                }
                // 如果是 Hold 模式（正在按住），忽略重复的 KeyDown
            }
        }
    }
    
    private func handleKeyUp() {
        // keyUp 是明确的结束信号，取消任何待执行的防抖检查
        flagsDebounceWorkItem?.cancel()
        flagsDebounceWorkItem = nil
        handleRelease()
    }
    
    private func handleRelease() {
        // CGEvent 回调不在主线程，所有状态访问需要在主线程进行
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 调试日志：当前状态
            self.logger.debug("🔍 handleRelease: isRecording=\(self.isRecording), isToggleSession=\(self.isToggleSession)")
            
            guard self.isRecording else {
                self.logger.debug("🔍 handleRelease: not recording, skip")
                return
            }
            
            if self.isToggleSession {
                // Toggle 模式下，松开键不停止录音
                self.logger.debug("🔍 handleRelease: Toggle mode, skip")
                return
            }
            
            // 检查按压时长
            guard let startTime = self.recordingStartTime else {
                self.logger.debug("🔍 handleRelease: no startTime, skip")
                return
            }
            let duration = Date().timeIntervalSince(startTime)
            
            if duration < self.holdThreshold {
                // 短按：切换到 Toggle 模式，继续录音
                self.isToggleSession = true
                self.logger.info("👆 Short press (\(String(format: "%.2f", duration))s) detected. Switched to Toggle mode.")
            } else {
                // 长按：松手即停止
                self.logger.info("✋ Long press (\(String(format: "%.2f", duration))s) released. Stopping.")
                self.isRecording = false
                self.isToggleSession = false
                self.recordingStartTime = nil
                self.onRecordingStop?()
            }
        }
    }
    
    
    /// 强制重置状态（用于异常恢复）
    func resetState() {
        isRecording = false
        isToggleSession = false
        recordingStartTime = nil
        logger.info("🔄 HotKey state reset")
    }
}
