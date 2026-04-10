import AppKit
import Testing
@testable import SpokenAnyWhere

@Suite("AnswerPanel 主试点测试")
@MainActor
struct AnswerPanelPilotTests {
    @Test("show/hide 会创建可聚焦窗口并在关闭后移除状态")
    func showHideCreatesFocusableWindowAndRemovesState() throws {
        let historyService = SessionHistoryService.makePreview()
        let manager = AnswerPanelManager.makeTesting(
            dependencies: AnswerPanelManagerDependencies(historyService: historyService)
        )

        let panelId = manager.show(question: "解释这段输出", attachments: [])

        let answerWindows = NSApp.windows.filter {
            $0.identifier?.rawValue == UITestIdentifiers.Window.answerPanel
        }
        #expect(!answerWindows.isEmpty)

        let window = try #require(answerWindows.last)
        let panel = try #require(window as? AnswerPanelWindow)

        #expect(panel.canBecomeKey)
        #expect(panel.canBecomeMain)
        #expect(window.isVisible)
        #expect(manager.state(for: panelId)?.messages.first?.content == "解释这段输出")
        #expect(manager.state(for: panelId)?.isLoading == true)

        manager.hide(panelId: panelId)
        #expect(manager.state(for: panelId) == nil)
        #expect(window.isVisible == false)
    }
}
