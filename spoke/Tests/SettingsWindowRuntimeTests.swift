import AppKit
import Foundation
import Testing
@testable import SpokenAnyWhere

@Suite("SettingsWindowRuntime 测试")
@MainActor
struct SettingsWindowRuntimeTests {
    @Test("展示前切到 regular policy")
    func prepareForPresentationUsesRegularPolicy() {
        var policies: [NSApplication.ActivationPolicy] = []

        let runtime = SettingsWindowRuntime(
            setActivationPolicy: { policies.append($0) },
            activateApp: {},
            focusWindow: { _ in }
        )

        runtime.prepareForPresentation()

        #expect(policies == [.regular])
    }

    @Test("关闭后仅在不显示 Dock 时恢复 accessory")
    func restoreAfterCloseRespectsShowInDock() {
        var policies: [NSApplication.ActivationPolicy] = []

        let runtime = SettingsWindowRuntime(
            setActivationPolicy: { policies.append($0) },
            activateApp: {},
            focusWindow: { _ in }
        )

        runtime.restoreAfterClose(showInDock: true)
        #expect(policies.isEmpty)

        runtime.restoreAfterClose(showInDock: false)
        #expect(policies == [.accessory])
    }

    @Test("设置窗口不允许通过整块背景拖动")
    func settingsWindowDisablesBackgroundDragging() throws {
        let source = try appDelegateSource()

        #expect(source.contains("window.isMovableByWindowBackground = false"))
        #expect(!source.contains("window.isMovableByWindowBackground = true"))
    }
}

private func appDelegateSource(filePath: String = #filePath) throws -> String {
    let testsFileURL = URL(fileURLWithPath: filePath)
    let repoRootURL = testsFileURL.deletingLastPathComponent().deletingLastPathComponent()
    let sourceURL = repoRootURL
        .appendingPathComponent("App")
        .appendingPathComponent("AppDelegate.swift")

    return try String(contentsOf: sourceURL, encoding: .utf8)
}
