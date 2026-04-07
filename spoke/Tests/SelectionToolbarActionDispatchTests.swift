import AppKit
import Foundation
import Testing
@testable import SpokenAnyWhere

@Suite("SelectionToolbar 动作派发测试", .serialized)
@MainActor
struct SelectionToolbarActionDispatchTests {

    @Test("executeAction 通过 direct closure 派发内置动作")
    func builtinActionUsesDirectClosure() {
        var capturedAction: SelectionToolbarActionType?
        var capturedContext: SelectionContext?
        let state = makeState(
            requestBuiltinAction: { action, context in
                capturedAction = action
                capturedContext = context
            },
            requestToolbarAction: { _, _ in }
        )
        let context = makeContext(text: "lookup this text")

        state.show(with: context)
        state.executeAction(.lookup)

        #expect(capturedAction == .lookup)
        #expect(capturedContext?.selectedText == context.selectedText)
        #expect(state.phase == .executing(.lookup))
        #expect(state.actionPhase == .preparing)
    }

    @Test("executeToolbarAction 通过 direct closure 派发自定义动作")
    func toolbarActionUsesDirectClosure() {
        var capturedAction: ToolbarAction?
        var capturedContext: SelectionContext?
        let state = makeState(
            requestBuiltinAction: { _, _ in },
            requestToolbarAction: { action, context in
                capturedAction = action
                capturedContext = context
            }
        )
        let context = makeContext(text: "summarize this text")
        let action = ToolbarAction.custom(
            name: "自定义总结",
            icon: "sparkles",
            iconColorHex: "#ffffff",
            prompt: "请总结 {{selection}}"
        )

        state.show(with: context)
        state.executeToolbarAction(action)

        #expect(capturedAction?.id == action.id)
        #expect(capturedContext?.selectedText == context.selectedText)
        #expect(state.executingActionId == action.id)
        #expect(state.actionPhase == .preparing)
    }

    private func makeState(
        requestBuiltinAction: @escaping (_ action: SelectionToolbarActionType, _ context: SelectionContext) -> Void,
        requestToolbarAction: @escaping (_ action: ToolbarAction, _ context: SelectionContext) -> Void
    ) -> SelectionToolbarState {
        SelectionToolbarState.makeTesting(
            dependencies: SelectionToolbarStateDependencies(
                vocabularyService: VocabularyService(loadPersistedItems: false),
                appSettings: AppSettings.shared,
                notificationCenter: NotificationCenter(),
                requestBuiltinAction: requestBuiltinAction,
                requestToolbarAction: requestToolbarAction
            )
        )
    }

    private func makeContext(text: String) -> SelectionContext {
        SelectionContext(
            selectedText: text,
            selectionBounds: CGRect(x: 0, y: 0, width: 120, height: 24),
            sourceAppBundleId: "com.spoke.tests",
            sourceAppName: "Tests"
        )
    }
}
