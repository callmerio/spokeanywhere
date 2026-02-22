import Foundation
import Testing
@testable import SpokenAnyWhere

@Suite("RecordingState 状态机与错误处理测试")
struct RecordingStateTests {

    @Test("状态重置功能验证")
    @MainActor
    func resetState() {
        let state = RecordingState()
        state.startRecording(targetApp: nil)
        state.updatePartialText("Hello")
        state.updateAudioLevel(0.5)
        
        state.reset()
        
        #expect(state.phase == .idle)
        #expect(state.partialText == "")
        #expect(state.audioLevel == 0)
        #expect(!state.isVisible)
    }

    @Test("错误信息提取验证 (LocalizedError)")
    @MainActor
    func errorExtraction() {
        let state = RecordingState()
        let testError = MockDetailedError.permissionDenied
        
        state.fail(with: testError)
        
        if case .failure(let message, let reason, let suggestion) = state.phase {
            #expect(message == "权限不足")
            #expect(reason == "应用未获得麦克风权限")
            #expect(suggestion == "请在系统设置中开启权限")
        } else {
            Issue.record("Should be in failure phase")
        }
    }

    @Test("普通 Error 提取验证")
    @MainActor
    func simpleErrorExtraction() {
        let state = RecordingState()
        let testError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Simple error"])
        
        state.fail(with: testError)
        
        if case .failure(let message, let reason, let suggestion) = state.phase {
            #expect(message == "Simple error")
            #expect(reason == nil)
            #expect(suggestion == nil)
        } else {
            Issue.record("Should be in failure phase")
        }
    }

    @Test("字符串消息失败验证")
    @MainActor
    func stringMessageFailure() {
        let state = RecordingState()
        state.fail(with: "Something went wrong")
        
        if case .failure(let message, let reason, let suggestion) = state.phase {
            #expect(message == "Something went wrong")
            #expect(reason == nil)
            #expect(suggestion == nil)
        } else {
            Issue.record("Should be in failure phase")
        }
    }
}

// MARK: - Mock Error

enum MockDetailedError: LocalizedError {
    case permissionDenied
    
    var errorDescription: String? { "权限不足" }
    var failureReason: String? { "应用未获得麦克风权限" }
    var recoverySuggestion: String? { "请在系统设置中开启权限" }
}
