import Testing
@testable import SpokenAnyWhere

@Suite("QuickAskService 测试", .serialized)
@MainActor
struct QuickAskServiceTests {

    @Test("shared service 会把 direct follow-up callback 挂到 AnswerPanelManager")
    func sharedServiceWiresAnswerPanelCallback() {
        _ = QuickAskService.shared
        #expect(AnswerPanelManager.shared.onFollowUp != nil)
    }

    @Test("sendViaShortcut 在无内容时不会激活会话")
    func sendViaShortcutIsNoOpWhenStateCannotSend() {
        let service = QuickAskService.shared
        service.state.reset()

        service.sendViaShortcut()

        #expect(service.state.phase == .idle)
    }
}
