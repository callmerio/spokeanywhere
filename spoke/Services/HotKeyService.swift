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
    
    /// 是否正在录音
    var isRecording = false
    
    /// 是否是 Toggle 模式触发的录音（用于区分长按结束后的逻辑）
    private var isToggleSession = false
    
    /// 事件处理器
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    /// 快捷键变更观察者
    private var shortcutObserver: NSObjectProtocol?
    
    /// 回调
    var onRecordingStart: (() -> Void)?
    var onRecordingStop: (() -> Void)?
    
    // MARK: - Init
    
    private init() {
        loadShortcutFromSettings()
        setupShortcutObserver()
    }
    
    private func loadShortcutFromSettings() {
        let settings = AppSettings.shared
        currentKeyCode = UInt32(settings.shortcutKeyCode)
        currentModifiers = NSEvent.ModifierFlags(rawValue: UInt(settings.shortcutModifiers))
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
        
        let isModifiersPressed = checkModifiersMatch(flags: flags)
        let isTargetKey = keyCode == currentKeyCode
        
        switch type {
        case .keyDown:
            // keyDown 需要修饰键 + 目标键同时按下
            guard isTargetKey && isModifiersPressed else {
                return Unmanaged.passRetained(event)
            }
            handleKeyDown()
            return nil // 吞掉事件
            
        case .keyUp:
            // keyUp 只需要是目标键，且当前正在录音
            guard isTargetKey && isRecording else {
                return Unmanaged.passRetained(event)
            }
            handleKeyUp()
            return nil
            
        case .flagsChanged:
            // 监听修饰键松开
            if !isModifiersPressed && isRecording {
                handleRelease()
            }
            return Unmanaged.passRetained(event)
            
        default:
            break
        }
        
        return Unmanaged.passRetained(event)
    }
    
    /// 检查当前按下的修饰键是否匹配配置
    private func checkModifiersMatch(flags: CGEventFlags) -> Bool {
        var matches = true
        
        // 检查 Option
        if currentModifiers.contains(.option) {
            matches = matches && flags.contains(.maskAlternate)
        }
        // 检查 Command
        if currentModifiers.contains(.command) {
            matches = matches && flags.contains(.maskCommand)
        }
        // 检查 Control
        if currentModifiers.contains(.control) {
            matches = matches && flags.contains(.maskControl)
        }
        // 检查 Shift
        if currentModifiers.contains(.shift) {
            matches = matches && flags.contains(.maskShift)
        }
        
        return matches
    }
    
    private func handleKeyDown() {
        if !isRecording {
            // 开始录音
            startRecording()
            recordingStartTime = Date()
            isToggleSession = false
        } else {
            // 正在录音中
            if isToggleSession {
                // 如果已经是 Toggle 模式（之前短按触发），再次按下则停止
                stopRecording()
            } else {
                // 如果是 Hold 模式（正在按住），忽略重复的 KeyDown
            }
        }
    }
    
    private func handleKeyUp() {
        handleRelease()
    }
    
    private func handleRelease() {
        guard isRecording else { return }
        
        if isToggleSession {
            // Toggle 模式下，松开键不停止录音
            return
        }
        
        // 检查按压时长
        guard let startTime = recordingStartTime else { return }
        let duration = Date().timeIntervalSince(startTime)
        
        if duration < holdThreshold {
            // 短按：切换到 Toggle 模式，继续录音
            isToggleSession = true
            logger.info("👆 Short press (\(String(format: "%.2f", duration))s) detected. Switched to Toggle mode.")
        } else {
            // 长按：松手即停止
            logger.info("✋ Long press (\(String(format: "%.2f", duration))s) released. Stopping.")
            stopRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        Task { @MainActor in
            onRecordingStart?()
        }
    }
    
    private func stopRecording() {
        isRecording = false
        isToggleSession = false
        recordingStartTime = nil
        Task { @MainActor in
            onRecordingStop?()
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
