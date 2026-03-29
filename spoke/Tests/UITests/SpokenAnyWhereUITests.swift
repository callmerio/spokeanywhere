import AppKit
import ApplicationServices
import Foundation
import XCTest

final class SpokenAnyWhereUITests: XCTestCase {
    private static let appBundleIdentifier = "app.spokenly"
    private static let enableSmokeEnvKey = "ENABLE_AX_SMOKE_TESTS"

    // MARK: - Window Identifiers

    private static let liveCaptionWindowIdentifier = "ui.live-caption.window"
    private static let liveCaptionRootIdentifier = "ui.live-caption.root"
    private static let screenshotWindowIdentifier = "ui.screenshot.window"
    private static let screenshotContentIdentifier = "ui.screenshot.content"
    private static let floatingHUDWindowIdentifier = "ui.hud.floating-capsule.window"
    private static let floatingHUDRootIdentifier = "ui.hud.floating-capsule.root"
    private static let messagePanelWindowIdentifier = "ui.message-panel.window"
    private static let messagePanelRootIdentifier = "ui.message-panel.root"
    private static let quickAskCapsuleWindowIdentifier = "ui.quickask.capsule.window"
    private static let quickAskCapsuleRootIdentifier = "ui.quickask.capsule.root"
    private static let quickAskInputIdentifier = "ui.quickask.input"

    // MARK: - Lifecycle

    override func tearDown() {
        terminateRunningApps()
        super.tearDown()
    }

    // MARK: - Smoke Tests

    /// Live Caption 窗口标识验证
    func testLiveCaptionAccessibilityIdentifierSmoke() throws {
        let (appElement, _) = try launchAppForSmokeTesting()

        postDebugAutomationAction("caption.toggle")

        XCTAssertTrue(
            waitForAccessibilityIdentifier(Self.liveCaptionWindowIdentifier, in: appElement),
            "未发现实时字幕窗口标识"
        )
        XCTAssertTrue(
            waitForAccessibilityIdentifier(Self.liveCaptionRootIdentifier, in: appElement),
            "未发现实时字幕根视图标识"
        )

        // 清理：关闭字幕
        postDebugAutomationAction("caption.toggle")
    }

    /// Screenshot 窗口标识验证
    func testScreenshotAccessibilityIdentifierSmoke() throws {
        let (appElement, _) = try launchAppForSmokeTesting()

        postDebugAutomationAction("screenshot.capture")

        XCTAssertTrue(
            waitForAccessibilityIdentifier(Self.screenshotWindowIdentifier, in: appElement, timeout: 8),
            "未发现截图窗口标识"
        )
        XCTAssertTrue(
            waitForAccessibilityIdentifier(Self.screenshotContentIdentifier, in: appElement, timeout: 3),
            "未发现截图内容视图标识"
        )
    }

    /// HUD / 浮动胶囊窗口标识验证（录音触发 → HUD 出现）
    func testFloatingHUDAccessibilityIdentifierSmoke() throws {
        let (appElement, _) = try launchAppForSmokeTesting()

        // 开始录音 → HUD 出现
        postDebugAutomationAction("recording.toggle")

        XCTAssertTrue(
            waitForAccessibilityIdentifier(Self.floatingHUDWindowIdentifier, in: appElement, timeout: 8),
            "未发现 HUD 浮动胶囊窗口标识"
        )
        XCTAssertTrue(
            waitForAccessibilityIdentifier(Self.floatingHUDRootIdentifier, in: appElement, timeout: 3),
            "未发现 HUD 浮动胶囊根视图标识"
        )

        // 清理：停止录音
        postDebugAutomationAction("recording.toggle")
    }

    /// MessagePanel 窗口标识验证
    func testMessagePanelAccessibilityIdentifierSmoke() throws {
        let (appElement, _) = try launchAppForSmokeTesting()

        postDebugAutomationAction("messagePanel.toggle")

        XCTAssertTrue(
            waitForAccessibilityIdentifier(Self.messagePanelWindowIdentifier, in: appElement),
            "未发现 MessagePanel 窗口标识"
        )
        XCTAssertTrue(
            waitForAccessibilityIdentifier(Self.messagePanelRootIdentifier, in: appElement),
            "未发现 MessagePanel 根视图标识"
        )

        // 清理：关闭面板
        postDebugAutomationAction("messagePanel.toggle")
    }

    /// QuickAsk 胶囊窗口标识验证
    func testQuickAskCapsuleAccessibilityIdentifierSmoke() throws {
        let (appElement, _) = try launchAppForSmokeTesting()

        postDebugAutomationAction("quickAsk.trigger")

        XCTAssertTrue(
            waitForAccessibilityIdentifier(Self.quickAskCapsuleWindowIdentifier, in: appElement, timeout: 8),
            "未发现 QuickAsk 胶囊窗口标识"
        )
        XCTAssertTrue(
            waitForAccessibilityIdentifier(Self.quickAskCapsuleRootIdentifier, in: appElement, timeout: 3),
            "未发现 QuickAsk 胶囊根视图标识"
        )
        XCTAssertTrue(
            waitForAccessibilityIdentifier(Self.quickAskInputIdentifier, in: appElement, timeout: 3),
            "未发现 QuickAsk 输入框标识"
        )
    }

    /// 多窗口共存验证：同时打开 LiveCaption + MessagePanel
    func testMultipleWindowsCoexistSmoke() throws {
        let (appElement, _) = try launchAppForSmokeTesting()

        // 同时打开两个窗口
        postDebugAutomationAction("caption.toggle")
        postDebugAutomationAction("messagePanel.toggle")

        XCTAssertTrue(
            waitForAccessibilityIdentifier(Self.liveCaptionWindowIdentifier, in: appElement),
            "共存测试：未发现字幕窗口"
        )
        XCTAssertTrue(
            waitForAccessibilityIdentifier(Self.messagePanelWindowIdentifier, in: appElement),
            "共存测试：未发现 MessagePanel 窗口"
        )

        // 清理
        postDebugAutomationAction("caption.toggle")
        postDebugAutomationAction("messagePanel.toggle")
    }

    // MARK: - Shared Launch Helper

    /// 统一的 app 启动 + 前置检查，返回 (appElement, runningApp)
    private func launchAppForSmokeTesting() throws -> (AXUIElement, NSRunningApplication) {
        guard Self.isSmokeTestEnabled else {
            throw XCTSkip("未启用 AX smoke test；设置 ENABLE_AX_SMOKE_TESTS=1 后再运行")
        }
        let appURL = try resolvedAppURL()
        guard AXIsProcessTrusted() else {
            throw XCTSkip("当前环境未授予 Accessibility 权限，无法执行 AX smoke test")
        }
        terminateRunningApps()

        try launchApp(at: appURL)
        guard let runningApp = waitForRunningApp() else {
            XCTFail("应用未在预期时间内启动")
            throw XCTSkip("应用启动失败")
        }
        let appElement = AXUIElementCreateApplication(runningApp.processIdentifier)

        // 等待应用完成启动链路与 debug automation listener 注册
        RunLoop.current.run(until: Date().addingTimeInterval(3.0))

        return (appElement, runningApp)
    }

    // MARK: - App Lifecycle Helpers

    private func resolvedAppURL() throws -> URL {
        let env = ProcessInfo.processInfo.environment
        let fileManager = FileManager.default

        let candidates: [String] = [
            env["APP_BUNDLE_PATH"],
            NSString(string: "~/Applications/SpokenAnyWhere Dev.app").expandingTildeInPath,
            ".build/bundler/SpokenAnyWhere.app"
        ]
        .compactMap { $0 }

        for path in candidates {
            let url = URL(fileURLWithPath: path)
            if fileManager.fileExists(atPath: url.path) {
                return url
            }
        }

        throw XCTSkip("未找到可启动的 app bundle: \(candidates.joined(separator: ", "))")
    }

    private func launchApp(at url: URL) throws {
        guard let bundle = Bundle(url: url),
              let executableURL = bundle.executableURL else {
            XCTFail("无法解析 app 可执行文件: \(url.path)")
            return
        }

        let process = Process()
        process.executableURL = executableURL
        process.currentDirectoryURL = executableURL.deletingLastPathComponent()
        process.environment = ProcessInfo.processInfo.environment.merging([
            "SPOKE_DEBUG_AUTOMATION": "1",
            "SPOKE_SKIP_ACCESSIBILITY_ALERTS": "1",
            "SPOKE_AUDIO_WARMUP": "0"
        ]) { _, new in new }

        do {
            try process.run()
        } catch {
            XCTFail("启动应用失败: \(error.localizedDescription)")
        }
    }

    private func waitForRunningApp() -> NSRunningApplication? {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: Self.appBundleIdentifier).first {
                return app
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return NSRunningApplication.runningApplications(withBundleIdentifier: Self.appBundleIdentifier).first
    }

    // MARK: - Debug Automation

    private func postDebugAutomationAction(_ action: String) {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.spokeanywhere.debug.automation.trigger"),
            object: action,
            userInfo: ["action": action],
            deliverImmediately: true
        )
    }

    // MARK: - AX Tree Query

    private func waitForAccessibilityIdentifier(
        _ identifier: String,
        in appElement: AXUIElement,
        timeout: TimeInterval = 5
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if containsAccessibilityIdentifier(identifier, in: appElement, depth: 0) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return containsAccessibilityIdentifier(identifier, in: appElement, depth: 0)
    }

    private func containsAccessibilityIdentifier(
        _ identifier: String,
        in element: AXUIElement,
        depth: Int
    ) -> Bool {
        guard depth < 8 else { return false }
        if accessibilityIdentifier(of: element) == identifier {
            return true
        }

        for child in accessibilityChildren(of: element) {
            if containsAccessibilityIdentifier(identifier, in: child, depth: depth + 1) {
                return true
            }
        }

        return false
    }

    private func accessibilityIdentifier(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXIdentifierAttribute as CFString,
            &value
        )
        guard result == .success else { return nil }
        return value as? String
    }

    private func accessibilityChildren(of element: AXUIElement) -> [AXUIElement] {
        let attributes: [CFString] = [
            kAXWindowsAttribute as CFString,
            kAXChildrenAttribute as CFString
        ]
        var result: [AXUIElement] = []

        for attribute in attributes {
            var value: CFTypeRef?
            let copyResult = AXUIElementCopyAttributeValue(element, attribute, &value)
            guard copyResult == .success, let children = value as? [AXUIElement] else {
                continue
            }
            result.append(contentsOf: children)
        }

        return result
    }

    // MARK: - Cleanup

    private func terminateRunningApps() {
        let deadline = Date().addingTimeInterval(5)
        var runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: Self.appBundleIdentifier)
        for app in runningApps {
            app.terminate()
        }

        while !runningApps.isEmpty, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: Self.appBundleIdentifier)
        }

        if !runningApps.isEmpty {
            for app in runningApps {
                app.forceTerminate()
            }
        }

        while !runningApps.isEmpty, Date() < deadline.addingTimeInterval(2) {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: Self.appBundleIdentifier)
        }
    }

    private static var isSmokeTestEnabled: Bool {
        let raw = ProcessInfo.processInfo.environment[enableSmokeEnvKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch raw {
        case "1", "true", "yes", "on":
            return true
        default:
            return false
        }
    }
}
