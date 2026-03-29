#if DEBUG
import Foundation
import os

/// Debug-only 自动化触发通道
/// 通过 NSDistributedNotificationCenter 接收外部脚本触发指令。
@MainActor
final class DebugAutomationTriggerService {
    static let shared = DebugAutomationTriggerService(dependencies: .live)

    static let notificationName = Notification.Name("com.spokeanywhere.debug.automation.trigger")
    static let enableEnvKey = "SPOKE_DEBUG_AUTOMATION"

    enum Action: String {
        case ping
        case recordingToggle = "recording.toggle"
        case captionToggle = "caption.toggle"
        case screenshotCapture = "screenshot.capture"
        case messagePanelToggle = "messagePanel.toggle"
        case quickAskTrigger = "quickAsk.trigger"
    }

    private let logger = Logger(subsystem: "com.spokeanywhere", category: "DebugAutomation")
    private let dependencies: DebugAutomationTriggerServiceDependencies
    private var observer: NSObjectProtocol?

    var onRecordingToggle: (() -> Void)?
    var onCaptionToggle: (() -> Void)?
    var onScreenshotCapture: (() -> Void)?
    var onMessagePanelToggle: (() -> Void)?
    var onQuickAskTrigger: (() -> Void)?

    private init(dependencies: DebugAutomationTriggerServiceDependencies) {
        self.dependencies = dependencies
    }

    /// Debug 启动参数：
    /// - `SPOKE_DEBUG_AUTOMATION=1|true|yes|on` => 启用
    /// - `SPOKE_DEBUG_AUTOMATION=0|false|no|off` 或未设置 => 禁用（默认）
    private static func isEnabledByEnvironment() -> Bool {
        guard let raw = ProcessInfo.processInfo.environment[enableEnvKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return false
        }

        switch raw.lowercased() {
        case "1", "true", "yes", "on":
            return true
        default:
            return false
        }
    }

    @discardableResult
    func start() -> Bool {
        guard Self.isEnabledByEnvironment() else {
            logger.info("🧪 [DebugAutomation] disabled by env \(Self.enableEnvKey, privacy: .public)")
            return false
        }

        guard observer == nil else { return true }

        observer = dependencies.addObserver(
            Self.notificationName,
            nil,
            .main
        ) { [weak self] notification in
            runDebugAutomationTriggerOnMain(self) { service in
                service.handle(notification)
            }
        }

        logger.info("🧪 [DebugAutomation] listener started")
        return true
    }

    func stop() {
        guard let observer else { return }
        dependencies.removeObserver(observer)
        self.observer = nil
        logger.info("🧪 [DebugAutomation] listener stopped")
    }

    private func handle(_ notification: Notification) {
        guard let raw = (notification.userInfo?["action"] as? String) ?? (notification.object as? String),
              let action = Action(rawValue: raw) else {
            logger.warning("⚠️ [DebugAutomation] invalid action payload")
            return
        }

        switch action {
        case .ping:
            let pid = ProcessInfo.processInfo.processIdentifier
            logger.info("🧪 [DebugAutomation] pong pid=\(pid, privacy: .public)")
        case .recordingToggle:
            logger.info("🧪 [DebugAutomation] action=recording.toggle")
            onRecordingToggle?()
        case .captionToggle:
            logger.info("🧪 [DebugAutomation] action=caption.toggle")
            onCaptionToggle?()
        case .screenshotCapture:
            logger.info("🧪 [DebugAutomation] action=screenshot.capture")
            onScreenshotCapture?()
        case .messagePanelToggle:
            logger.info("🧪 [DebugAutomation] action=messagePanel.toggle")
            onMessagePanelToggle?()
        case .quickAskTrigger:
            logger.info("🧪 [DebugAutomation] action=quickAsk.trigger")
            onQuickAskTrigger?()
        }
    }
}
#endif
