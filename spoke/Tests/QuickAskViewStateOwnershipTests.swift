import Foundation
import Testing
@testable import SpokenAnyWhere

@Suite("AnswerPanelView 状态归属测试")
@MainActor
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

        let workflowState = WorkflowState.makePreview()
        let dependencies = makeDependencies(workflowState: workflowState)
        let state = AnswerPanelState()
        let view = AnswerPanelView(state: state, dependencies: dependencies)

        #expect(view.workflowState === workflowState, "AnswerPanelView 应读取调用方注入的 WorkflowState 实例")

        workflowState.showPicker()
        workflowState.filterKeyword = "sum"

        let refreshedView = AnswerPanelView(state: state, dependencies: dependencies)
        #expect(refreshedView.workflowState === workflowState, "刷新 view value 不应重建 WorkflowState")
        #expect(refreshedView.workflowState.isPickerVisible, "刷新后的 view 应继续读取外部 WorkflowState 的最新 picker 状态")
        #expect(refreshedView.workflowState.filterKeyword == "sum", "刷新后的 view 应保留外部 WorkflowState 的过滤关键字")
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

    private func makeDependencies(workflowState: WorkflowState) -> AnswerPanelViewDependencies {
        AnswerPanelViewDependencies(
            workflowState: workflowState,
            ttsService: .shared,
            ttsSettings: .shared,
            messageBubbleDependencies: MessageBubbleViewDependencies(ttsService: .shared),
            inputDependencies: AnswerPanelInputDependencies(
                addImage: { _, _ in },
                handleDrop: { _, _ in }
            ),
            openSettings: {}
        )
    }
}
