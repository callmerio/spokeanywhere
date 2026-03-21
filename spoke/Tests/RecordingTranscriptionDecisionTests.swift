import Foundation
import Testing
@testable import SpokenAnyWhere

@Suite("RecordingTranscriptionDecision 测试")
struct RecordingTranscriptionDecisionTests {

    @Test("LLM 成功时使用精炼文本并在空闲时完成 HUD")
    func successUsesRefinedText() {
        let decision = RecordingTranscriptionDecision.make(
            rawText: "原始转写",
            refineResult: .success("精炼结果"),
            isStillRecording: false
        )

        #expect(decision.clipboardText == "精炼结果")
        #expect(decision.processedText == "精炼结果")
        #expect(decision.hudCompletionText == "精炼结果")
        #expect(decision.hudFailure == nil)
    }

    @Test("LLM 失败时保留原始文本并回退到失败 HUD")
    func fallbackToRawTextOnLLMFailure() {
        let decision = RecordingTranscriptionDecision.make(
            rawText: "原始转写",
            refineResult: .failure(.networkError(NSError(domain: "test", code: -1009))),
            isStillRecording: false
        )

        #expect(decision.clipboardText == "原始转写")
        #expect(decision.processedText == nil)
        #expect(decision.hudCompletionText == nil)
        #expect(decision.hudFailure != nil)
    }

    @Test("新录音开始后不再更新 HUD")
    func suppressesHUDUpdateWhileRecording() {
        let decision = RecordingTranscriptionDecision.make(
            rawText: "原始转写",
            refineResult: .success("精炼结果"),
            isStillRecording: true
        )

        #expect(decision.clipboardText == "精炼结果")
        #expect(decision.processedText == "精炼结果")
        #expect(decision.hudCompletionText == nil)
        #expect(decision.hudFailure == nil)
    }
}
