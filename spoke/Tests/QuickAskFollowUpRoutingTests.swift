import AppKit
import Testing
@testable import SpokenAnyWhere

@Suite("QuickAsk Follow-up 路由测试", .serialized)
@MainActor
struct QuickAskFollowUpRoutingTests {

    @Test("AnswerPanelManager 通过 direct callback 路由追问，不再广播附件对象")
    func answerPanelManagerRoutesFollowUpViaCallback() async {
        let manager = AnswerPanelManager.makeTesting(
            dependencies: AnswerPanelManagerDependencies(historyService: SessionHistoryService.shared)
        )
        let panelId = manager.installTestingPanel()
        let image = NSImage(size: NSSize(width: 12, height: 12))
        let attachment = Attachment.image(image, nil, UUID())
        var receivedPanelId: UUID?
        var receivedPrompt: String?

        manager.onFollowUp = { panelId, prompt in
            receivedPanelId = panelId
            receivedPrompt = prompt
        }

        manager.handleFollowUpRequest(
            question: "继续解释这段代码",
            attachments: [attachment],
            for: panelId
        )
        await Task.yield()

        let state = manager.state(for: panelId)
        #expect(receivedPanelId == panelId)
        #expect(receivedPrompt == "继续解释这段代码")
        #expect(state?.messages.last?.content == "继续解释这段代码")
        #expect(state?.messages.last?.attachments.count == 1)
    }
}
