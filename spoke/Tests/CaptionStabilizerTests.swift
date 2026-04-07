import Testing
@testable import SpokenAnyWhere

@Suite("CaptionStabilizer 测试")
@MainActor
struct CaptionStabilizerTests {

    @Test("重复 volatile 输入后会产出稳定前缀")
    func returnsStablePrefixAfterRepeatedHypothesis() {
        let stabilizer = CaptionStabilizer()

        let first = stabilizer.process(finalizedText: "", volatileText: "hello world")
        let second = stabilizer.process(finalizedText: "", volatileText: "hello world")

        #expect(first.translationText == nil)
        #expect(second.translationText == "hello")
        #expect(second.displayText == "hello world")
    }

    @Test("reset 会清空确认与待确认文本")
    func resetClearsState() {
        let stabilizer = CaptionStabilizer()
        _ = stabilizer.process(finalizedText: "done", volatileText: "pending")

        stabilizer.reset()

        #expect(stabilizer.confirmedText.isEmpty)
        #expect(stabilizer.pendingText.isEmpty)
    }
}
