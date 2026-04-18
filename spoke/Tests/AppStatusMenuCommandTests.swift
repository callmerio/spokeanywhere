import Testing
@testable import SpokenAnyWhere

@Suite("AppStatusMenuCommandRuntime 测试")
@MainActor
struct AppStatusMenuCommandTests {
    @Test("菜单命令运行时会触发录音和 Quick Ask 正式入口")
    func menuCommandsInvokeServiceEntryPoints() {
        var events: [String] = []

        let runtime = AppStatusMenuCommandRuntime(
            toggleRecording: { events.append("toggleRecording") },
            triggerQuickAsk: { events.append("triggerQuickAsk") }
        )

        runtime.toggleRecordingFromMenu()
        runtime.triggerQuickAskFromMenu()

        #expect(events == ["toggleRecording", "triggerQuickAsk"])
    }
}
