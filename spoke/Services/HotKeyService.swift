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
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // 处理 tap 被系统禁用的情况（超时或其他原因）
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            logger.warning("⚠️ Event tap was disabled, re-enabling...")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }
        
        let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        
        // 检查是否是录音快捷键
        let isRecordingModifiersPressed = checkModifiersMatch(flags: flags, target: currentModifiers)
        let isRecordingKey = keyCode == currentKeyCode
        
        // 检查是否是 Quick Ask 快捷键
        let isQuickAskModifiersPressed = checkModifiersMatch(flags: flags, target: quickAskModifiers)
        let isQuickAskKey = keyCode == quickAskKeyCode
        
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
            
            // 录音快捷键
            if isRecordingKey && isRecordingModifiersPressed {
                handleKeyDown()
                return nil
            }
            
            return Unmanaged.passRetained(event)
            
        case .keyUp:
            // Quick Ask keyUp
            if isQuickAskKey && isQuickAskActive {
                // Quick Ask 不响应 keyUp（只用 keyDown 触发发送）
                return nil
            }
            
            // 录音 keyUp
            if isRecordingKey && isRecording {
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
    
    // MARK: - Modifier Release Check (Multi-Display Fix)
    
    /// 延迟检查修饰键是否真的松开（修复多屏切换时的虚假事件）
    private func scheduleModifierReleaseCheck() {
        // 取消之前的检查（防抖）
        flagsDebounceWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
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
        logger.info("🔄 Quick Ask state reset")
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
            guard self.isRecording else { return }
            
            if self.isToggleSession {
                // Toggle 模式下，松开键不停止录音
                return
            }
            
            // 检查按压时长
            guard let startTime = self.recordingStartTime else { return }
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
