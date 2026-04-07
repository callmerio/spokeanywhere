import Foundation
import Testing
@testable import SpokenAnyWhere

@Suite("LiveCaptionScrollState 测试")
struct LiveCaptionScrollStateTests {

    @Test("默认滚动状态符合预期")
    func defaultsAreStable() {
        let state = LiveCaptionScrollState()

        #expect(state.isAtBottom)
        #expect(state.scrollTrigger == 0)
        #expect(state.appearedItemIDs.isEmpty)
    }

    @Test("滚动状态可独立跟踪触发器和已出现项")
    func tracksTriggerAndAppearedItems() {
        let state = LiveCaptionScrollState()
        let id = UUID()

        state.isAtBottom = false
        state.scrollTrigger += 1
        state.appearedItemIDs.insert(id)

        #expect(!state.isAtBottom)
        #expect(state.scrollTrigger == 1)
        #expect(state.appearedItemIDs.contains(id))
    }
}
