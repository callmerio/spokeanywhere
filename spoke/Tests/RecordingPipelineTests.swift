import Foundation
import Testing
@testable import SpokenAnyWhere

@Suite("RecordingPipeline 逻辑测试", .serialized)
@MainActor
struct RecordingPipelineTests {

    @Test("录音正常流程状态切换验证")
    func normalRecordingFlow() async {
        let state = RecordingState()
        
        // 1. 开始录音
        state.startRecording(targetApp: nil)
        #expect(state.phase == .recording)
        #expect(state.isVisible)
        
        // 2. 收到中间结果
        state.updatePartialText("Hello")
        #expect(state.partialText == "Hello")
        
        // 3. 停止并开始处理
        state.startProcessing()
        #expect(state.phase == .processing)
        
        // 4. AI 思考中
        state.startThinking()
        #expect(state.phase == .thinking)
        
        // 5. 完成
        state.complete(with: "Hello world")
        #expect(state.phase == .success)
        #expect(state.finalText == "Hello world")
    }

    @Test("录音失败流程 (空语音) 验证")
    func emptySpeechFlow() async {
        let state = RecordingState()
        
        state.startRecording(targetApp: nil)
        
        // 模拟空语音失败
        let error = TranscriptionError.emptySpeech
        state.fail(with: error)
        
        if case .failure(let message, let reason, let suggestion) = state.phase {
            #expect(message == "未检测到语音")
            #expect(reason?.contains("没有检测到有效的人声") == true)
            #expect(suggestion?.contains("离麦克风更近一点") == true)
        } else {
            Issue.record("Should be in failure phase")
        }
    }

    @Test("AI 处理失败但保留原始文本验证")
    func aiFailureWithTextPreservation() async {
        let state = RecordingState()
        
        state.startRecording(targetApp: nil)
        state.updatePartialText("Raw transcribed text")
        
        state.startThinking()
        
        // 模拟 AI 网络错误
        let aiError = LLMError.networkError(NSError(domain: "test", code: -1009, userInfo: nil))
        state.fail(with: aiError)
        
        // 验证状态
        if case .failure = state.phase {
            // 在 UI 层，我们期望 partialText 仍然存在以供显示
            #expect(state.partialText == "Raw transcribed text")
        } else {
            Issue.record("Should be in failure phase")
        }
    }
}
