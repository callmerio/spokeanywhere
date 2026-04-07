import Testing
@testable import SpokenAnyWhere

@Suite("LiveCaptionInteractionState 测试")
struct LiveCaptionInteractionStateTests {

    @Test("默认交互状态符合预期")
    func defaultsAreStable() {
        let state = LiveCaptionInteractionState()

        #expect(!state.isExpanded)
        #expect(!state.isUserSelecting)
        #expect(state.vocabularyRefreshTrigger == 0)
        #expect(state.highlightedWord == nil)
    }

    @Test("交互状态可独立更新")
    func updatesIndependently() {
        let state = LiveCaptionInteractionState()

        state.isExpanded = true
        state.isUserSelecting = true
        state.vocabularyRefreshTrigger += 2
        state.highlightedWord = "sustain"

        #expect(state.isExpanded)
        #expect(state.isUserSelecting)
        #expect(state.vocabularyRefreshTrigger == 2)
        #expect(state.highlightedWord == "sustain")
    }
}
