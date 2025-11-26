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
    
    /// 当前快捷键 (默认: ⌥ + R)
    private(set) var currentKeyCombo: (keyCode: UInt32, modifiers: UInt32) = (
        keyCode: UInt32(kVK_ANSI_R),
        modifiers: UInt32(optionKey)
    )
    
    /// 是否正在录音
    var isRecording = false
    
    /// 是否是 Toggle 模式触发的录音（用于区分长按结束后的逻辑）
    private var isToggleSession = false
    
    /// 事件处理器
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    /// 回调
    var onRecordingStart: (() -> Void)?
    var onRecordingStop: (() -> Void)?
    
    // MARK: - Init
    
    private init() {}
    
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
            logger.info("✅ HotKey registered: ⌥ + R")
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
        let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        
        let isOptionPressed = flags.contains(.maskAlternate)
        let isTargetKey = keyCode == currentKeyCombo.keyCode
        
        switch type {
        case .keyDown:
            // keyDown 需要 Option + R 同时按下
            guard isTargetKey && isOptionPressed else {
                return Unmanaged.passRetained(event)
            }
            handleKeyDown()
            return nil // 吞掉事件
            
        case .keyUp:
            // keyUp 只需要是 R 键，且当前正在录音（因为 Option 可能已经先松开）
            guard isTargetKey && isRecording else {
                return Unmanaged.passRetained(event)
            }
            handleKeyUp()
            return nil
            
        case .flagsChanged:
            // 监听 Option 键松开
            if !isOptionPressed && isRecording {
                handleRelease()
            }
            return Unmanaged.passRetained(event)
            
        default:
            break
        }
        
        return Unmanaged.passRetained(event)
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
        Task { @MainActor in
            onRecordingStop?()
        }
    }
}
