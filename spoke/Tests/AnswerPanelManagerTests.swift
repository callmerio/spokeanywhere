import Testing
@testable import SpokenAnyWhere

@Suite("AnswerPanelManager 测试")
@MainActor
struct AnswerPanelManagerTests {

    @Test("appendUserMessage 与 showError 会更新对应 panel state")
    func updatesPanelState() {
        let manager = AnswerPanelManager.makeTesting(
            dependencies: AnswerPanelManagerDependencies(historyService: SessionHistoryService.shared)
        )
        let panelId = manager.installTestingPanel()

        manager.appendUserMessage("hello", attachments: [], for: panelId)
        manager.showError("boom", for: panelId)

        let state = manager.state(for: panelId)
        #expect(state?.messages.last?.content == "hello")
        #expect(state?.isLoading == false)
        #expect(state?.error == "boom")
    }
}
