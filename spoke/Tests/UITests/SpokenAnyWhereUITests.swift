import AppKit
import ApplicationServices
import Foundation
import XCTest

final class SpokenAnyWhereUITests: XCTestCase {
    private static let appBundleIdentifier = "app.spokenly"
    private static let liveCaptionWindowIdentifier = "ui.live-caption.window"
    private static let liveCaptionRootIdentifier = "ui.live-caption.root"
    private static let enableSmokeEnvKey = "ENABLE_AX_SMOKE_TESTS"

    override func tearDown() {
        terminateRunningApps()
        super.tearDown()
    }

    func testLiveCaptionAccessibilityIdentifierSmoke() throws {
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
            return
        }
        let appElement = AXUIElementCreateApplication(runningApp.processIdentifier)

        // 等待应用完成启动链路与 debug automation listener 注册。
        RunLoop.current.run(until: Date().addingTimeInterval(2.0))

        postDebugAutomationAction("caption.toggle")

        XCTAssertTrue(
            waitForAccessibilityIdentifier(Self.liveCaptionWindowIdentifier, in: appElement),
            "未发现实时字幕窗口标识"
        )
        XCTAssertTrue(
            waitForAccessibilityIdentifier(Self.liveCaptionRootIdentifier, in: appElement),
            "未发现实时字幕根视图标识"
        )

        postDebugAutomationAction("caption.toggle")
    }

    private func resolvedAppURL() throws -> URL {
        let env = ProcessInfo.processInfo.environment
        let path = env["APP_BUNDLE_PATH"] ?? ".build/bundler/SpokenAnyWhere.app"
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("未找到可启动的 app bundle: \(url.path)")
        }
        return url
    }

    private func launchApp(at url: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", url.path]
        process.environment = [
            "SPOKE_DEBUG_AUTOMATION": "1",
            "SPOKE_SKIP_ACCESSIBILITY_ALERTS": "1",
            "SPOKE_AUDIO_WARMUP": "0"
        ]

        do {
            try process.run()
            process.waitUntilExit()
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

    private func postDebugAutomationAction(_ action: String) {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.spokeanywhere.debug.automation.trigger"),
            object: nil,
            userInfo: ["action": action],
            deliverImmediately: true
        )
    }

    private func waitForAccessibilityIdentifier(_ identifier: String, in appElement: AXUIElement) -> Bool {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if containsAccessibilityIdentifier(identifier, in: appElement, depth: 0) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
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

    private func terminateRunningApps() {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: Self.appBundleIdentifier)
        for app in runningApps {
            app.terminate()
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
