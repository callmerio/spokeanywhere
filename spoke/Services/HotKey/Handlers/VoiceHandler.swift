import AppKit
import Carbon.HIToolbox
import os

/// 录音热键处理器
/// 处理复杂的录音状态机（长按/短按/Toggle模式）
@MainActor
final class VoiceHandler: HotKeyHandler {

    let hotKeyType: HotKeyType = .recording
    var binding: HotKeyBinding

    private let logger = Logger(subsystem: "com.spokeanywhere", category: "VoiceHandler")

    // MARK: - State

    /// 是否正在录音
    private(set) var isRecording = false

    /// 录音开始时间
    private var recordingStartTime: Date?

    /// 长按阈值（秒）
    private let holdThreshold: TimeInterval = 0.4

    /// 是否是 Toggle 模式触发的录音
    private var isToggleSession = false

    /// 当前录音会话 ID
    private var currentSessionId: UUID?

    /// 延迟停止 Task
    private var delayedStopTask: Task<Void, Never>?

    /// flagsChanged 防抖工作项
    private var flagsDebounceWorkItem: DispatchWorkItem?

    // MARK: - Callbacks

    var onRecordingStart: (() -> Void)?
    var onRecordingStop: (() -> Void)?

    // MARK: - Init

    init() {
        let settings = AppSettings.shared
        self.binding = HotKeyBinding(
            keyCode: UInt32(settings.shortcutKeyCode),
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(settings.shortcutModifiers))
        )
    }

    // MARK: - HotKeyHandler

    func handleKeyDown() -> Bool {
        let taskStatus = delayedStopTask != nil ? "SET" : "nil"
        logger.info("keyDown: isRecording=\(self.isRecording), isToggleSession=\(self.isToggleSession), delayedStopTask=\(taskStatus, privacy: .public)")

        if !isRecording {
            startNewRecording()
        } else {
            handleRecordingKeyDown()
        }
        return true
    }

    func handleKeyUp() -> Bool {
        // 取消任何待执行的防抖检查
        flagsDebounceWorkItem?.cancel()
        flagsDebounceWorkItem = nil

        logger.debug("keyUp: calling handleRelease")
        handleRelease(fromKeyUp: true)
        return true
    }

    func reloadBinding() {
        let settings = AppSettings.shared
        binding = HotKeyBinding(
            keyCode: UInt32(settings.shortcutKeyCode),
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(settings.shortcutModifiers))
        )
        logger.info("Recording shortcut reloaded: \(settings.shortcutDisplayString)")
    }

    // MARK: - Recording Logic

    private func startNewRecording() {
        // 取消之前的延迟停止
        delayedStopTask?.cancel()
        delayedStopTask = nil

        // 创建新会话
        currentSessionId = UUID()
        isRecording = true
        recordingStartTime = Date()
        isToggleSession = false
        onRecordingStart?()

        logger.info("New recording session started: \(self.currentSessionId?.uuidString.prefix(8) ?? "nil")")
    }

    private func handleRecordingKeyDown() {
        if isToggleSession {
            // Toggle 模式，第二次按下延迟停止
            logger.info("Toggle mode: second press, stopping in 0.8s...")
            isToggleSession = false

            let sessionToStop = currentSessionId
            delayedStopTask?.cancel()

            delayedStopTask = Task {
                try? await Task.sleep(for: .milliseconds(800))
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.delayedStopTask = nil

                    guard self.isRecording, self.currentSessionId == sessionToStop else {
                        self.logger.debug("Delayed stop skipped: session changed")
                        return
                    }

                    self.stopRecording()
                }
            }
        } else if delayedStopTask != nil {
            // 延迟停止期间按下：取消并开始新录音
            logger.info("Pressed during delayed stop, starting new recording")
            delayedStopTask?.cancel()
            delayedStopTask = nil

            stopRecording()
            startNewRecording()
        }
    }

    private func handleRelease(fromKeyUp: Bool) {
        guard isRecording else {
            logger.debug("handleRelease: not recording, skip")
            return
        }

        if isToggleSession {
            logger.debug("handleRelease: Toggle mode, skip")
            return
        }

        guard let startTime = recordingStartTime else {
            logger.debug("handleRelease: no startTime, skip")
            return
        }

        let duration = Date().timeIntervalSince(startTime)
        logger.info("handleRelease: duration=\(String(format: "%.3f", duration))s, fromKeyUp=\(fromKeyUp)")

        if duration < holdThreshold && fromKeyUp {
            // 短按：切换到 Toggle 模式
            isToggleSession = true
            logger.info("Short press (\(String(format: "%.2f", duration))s). Switched to Toggle mode.")
        } else if duration < holdThreshold && !fromKeyUp {
            // flagsChanged 短时触发，等待 keyUp
            logger.debug("handleRelease: flagsChanged with short duration, waiting for keyUp")
            return
        } else {
            // 长按：延迟停止
            if delayedStopTask != nil {
                logger.debug("handleRelease: delayedStopTask already set, skip")
                return
            }

            logger.info("Long press (\(String(format: "%.2f", duration))s) released. Stopping in 0.8s...")

            flagsDebounceWorkItem?.cancel()
            flagsDebounceWorkItem = nil

            let sessionToStop = currentSessionId

            delayedStopTask = Task {
                try? await Task.sleep(for: .milliseconds(800))
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.delayedStopTask = nil

                    guard self.isRecording,
                          self.currentSessionId == sessionToStop,
                          !self.isToggleSession else {
                        self.logger.debug("Long press delayed stop skipped")
                        return
                    }

                    self.stopRecording()
                }
            }
        }
    }

    private func stopRecording() {
        isRecording = false
        recordingStartTime = nil
        currentSessionId = nil
        onRecordingStop?()
    }

    // MARK: - Modifier Release (Multi-Display Fix)

    /// 处理修饰键释放（用于多屏切换时的防抖）
    func handleModifierRelease() {
        if isToggleSession {
            logger.debug("scheduleModifierReleaseCheck: Toggle mode, skip")
            return
        }

        flagsDebounceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            if self.isToggleSession {
                self.logger.debug("Modifier check: Toggle mode now, skip")
                return
            }

            let currentFlags = NSEvent.modifierFlags
            let targetFlags = self.binding.modifiers.intersection([.option, .command, .control, .shift])

            var actualFlags: NSEvent.ModifierFlags = []
            if currentFlags.contains(.option) { actualFlags.insert(.option) }
            if currentFlags.contains(.command) { actualFlags.insert(.command) }
            if currentFlags.contains(.control) { actualFlags.insert(.control) }
            if currentFlags.contains(.shift) { actualFlags.insert(.shift) }

            if actualFlags != targetFlags {
                self.logger.info("Modifier release confirmed after delay check")
                self.handleRelease(fromKeyUp: false)
            } else {
                self.logger.info("Modifier still held, ignoring false flagsChanged (multi-display fix)")
            }
        }

        flagsDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }

    // MARK: - Reset

    /// 强制重置状态
    func resetState() {
        isRecording = false
        isToggleSession = false
        recordingStartTime = nil
        currentSessionId = nil

        delayedStopTask?.cancel()
        delayedStopTask = nil

        flagsDebounceWorkItem?.cancel()
        flagsDebounceWorkItem = nil

        logger.info("Voice handler state reset")
    }
}
