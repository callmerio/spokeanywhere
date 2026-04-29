import AppKit
import SwiftUI
import Testing
@testable import SpokenAnyWhere

@Suite("AppKitScrollView teardown 测试")
@MainActor
struct AppKitScrollViewTeardownTests {
    @Test("dismantleNSView 会取消并清空待执行滚动任务与程序滚动状态")
    func dismantleCancelsPendingWorkItemsAndResetsProgrammaticState() {
        var isAtBottom = true
        let binding = Binding<Bool>(
            get: { isAtBottom },
            set: { isAtBottom = $0 }
        )
        let coordinator = AppKitScrollView<Text>.Coordinator(
            isAtBottom: binding,
            bottomThreshold: 4
        )
        let catchUpWorkItem = DispatchWorkItem {}
        let frameChangeWorkItem = DispatchWorkItem {}
        coordinator.pendingCatchUpWorkItem = catchUpWorkItem
        coordinator.pendingFrameChangeWorkItem = frameChangeWorkItem
        coordinator.isScrollingProgrammatically = true
        coordinator.programmaticTargetY = 42

        AppKitScrollView<Text>.dismantleNSView(NSScrollView(), coordinator: coordinator)

        #expect(catchUpWorkItem.isCancelled, "pendingCatchUpWorkItem 应在 teardown 时被取消")
        #expect(frameChangeWorkItem.isCancelled, "pendingFrameChangeWorkItem 应在 teardown 时被取消")
        #expect(coordinator.pendingCatchUpWorkItem == nil, "pendingCatchUpWorkItem 应在 teardown 后清空")
        #expect(coordinator.pendingFrameChangeWorkItem == nil, "pendingFrameChangeWorkItem 应在 teardown 后清空")
        #expect(!coordinator.isScrollingProgrammatically, "teardown 后不应保留程序滚动状态")
        #expect(coordinator.programmaticTargetY == nil, "teardown 后不应保留程序滚动目标")
    }
}
