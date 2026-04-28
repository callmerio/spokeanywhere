import Foundation
import Testing

@Suite("AnswerPanelView 状态归属测试")
struct QuickAskViewStateOwnershipTests {
    @Test("workflowState 不应通过 @State 吞掉外部注入语义")
    func workflowStateIsNotStoredAsViewLocalState() throws {
        let source = try loadAnswerPanelViewSource()

        #expect(
            source.contains("private let injectedWorkflowState: WorkflowState"),
            "AnswerPanelView 应将 workflowState 作为注入属性持有，而不是 view-local @State"
        )
        #expect(
            !source.contains("@State var workflowState: WorkflowState"),
            "workflowState 不应再声明为 @State"
        )
    }

    @Test("@State 属性应显式标记为 private")
    func statePropertiesArePrivate() throws {
        let source = try loadAnswerPanelViewSource()
        #expect(
            !source.contains("@State var "),
            "AnswerPanelView 中不应出现非 private 的 @State 存储属性"
        )
    }

    private func loadAnswerPanelViewSource() throws -> String {
        let testsFileURL = URL(fileURLWithPath: #filePath)
        let projectRoot = testsFileURL.deletingLastPathComponent().deletingLastPathComponent()
        let sourceURL = projectRoot
            .appendingPathComponent("UI", isDirectory: true)
            .appendingPathComponent("QuickAsk", isDirectory: true)
            .appendingPathComponent("AnswerPanelView.swift", isDirectory: false)

        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
