import AppKit
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
}
