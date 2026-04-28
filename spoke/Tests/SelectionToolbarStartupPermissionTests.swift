import Foundation
import Testing
@testable import SpokenAnyWhere

@Suite("SelectionToolbar 启动权限提示测试")
struct SelectionToolbarStartupPermissionTests {
    @Test("默认启用工具栏时，启动链路应请求辅助功能权限提示")
    func startupPathRequestsPermissionPromptWhenToolbarEnabled() throws {
        let source = try loadSource(at: ["App", "AppDelegate.swift"])

        #expect(
            source.contains("selectionToolbarManager.start(requestPermissionIfNeeded: true)"),
            "当 SelectionToolbar 默认启用时，启动链路应请求权限提示，而不是静默跳过"
        )
    }

    @Test("权限提示文案应使用运行时应用名")
    func alertMessageUsesRuntimeAppName() {
        let message = selectionToolbarAccessibilityInformativeText(appName: "SpokenAnyWhere Dev")

        #expect(
            message.contains("SpokenAnyWhere Dev"),
            "权限提示文案应包含运行时应用名"
        )
        #expect(
            !message.contains("授权 SpokenAnyWhere。"),
            "权限提示文案不应硬编码旧的应用名"
        )
    }

    @Test("开发版应用路径应显示 Dev 名称")
    func appNameUsesBundleFolderNameWhenAvailable() {
        let appURL = URL(fileURLWithPath: "/Users/test/Applications/SpokenAnyWhere Dev.app")
        let appName = selectionToolbarAccessibilityAppName(bundleURL: appURL)

        #expect(appName == "SpokenAnyWhere Dev")
    }

    @Test("异常路径时回退到默认应用名")
    func appNameFallsBackToDefaultWhenBundleNameMissing() {
        let appURL = URL(fileURLWithPath: "/")
        let appName = selectionToolbarAccessibilityAppName(
            bundleURL: appURL,
            fallbackName: "SpokenAnyWhere"
        )

        #expect(appName == "SpokenAnyWhere")
    }

    private func loadSource(at components: [String]) throws -> String {
        let testsFileURL = URL(fileURLWithPath: #filePath)
        let projectRoot = testsFileURL.deletingLastPathComponent().deletingLastPathComponent()
        let sourceURL = components.reduce(projectRoot) { partial, component in
            partial.appendingPathComponent(component, isDirectory: false)
        }

        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
