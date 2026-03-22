import AppKit
import Testing
@testable import SpokenAnyWhere

@Suite("QuickAskHUDWindowRuntime 测试")
@MainActor
struct QuickAskHUDWindowRuntimeTests {
    @Test("展示前会开启 Quick Ask 输入模式并切到 regular policy")
    func prepareForPresentationEnablesInteractiveMode() {
        var quickAskActive: [Bool] = []
        var debugKeyEvents: [Bool] = []
        var policies: [NSApplication.ActivationPolicy] = []

        let runtime = QuickAskHUDWindowRuntime(
            setQuickAskActive: { quickAskActive.append($0) },
            setDebugKeyEvents: { debugKeyEvents.append($0) },
            setActivationPolicy: { policies.append($0) },
            activateApp: {},
            promotePanel: { _ in }
        )

        runtime.prepareForPresentation()

        #expect(quickAskActive == [true])
        #expect(debugKeyEvents == [true])
        #expect(policies == [.regular])
    }

    @Test("隐藏后只在 restorePolicy 打开时恢复 accessory 模式")
    func restoreAfterDismissalRespectsPolicyFlag() {
        var policies: [NSApplication.ActivationPolicy] = []

        let runtime = QuickAskHUDWindowRuntime(
            setQuickAskActive: { _ in },
            setDebugKeyEvents: { _ in },
            setActivationPolicy: { policies.append($0) },
            activateApp: {},
            promotePanel: { _ in }
        )

        runtime.restoreAfterDismissal(restorePolicy: false)
        #expect(policies.isEmpty)

        runtime.restoreAfterDismissal(restorePolicy: true)
        #expect(policies == [.accessory])
    }
}
