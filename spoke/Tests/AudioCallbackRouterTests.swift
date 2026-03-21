import Foundation
import Testing
@testable import SpokenAnyWhere

@Suite("AudioCallbackRouter 回调隔离测试")
@MainActor
struct AudioCallbackRouterTests {

    @Test("Recording 与 QuickAsk 会话回调应隔离")
    func recordingAndQuickAskCallbacksAreIsolated() {
        let router = AudioCallbackRouter()
        let recordingSession = UUID()
        let quickAskSession = UUID()

        router.ensureSession(recordingSession)
        router.ensureSession(quickAskSession)

        var recordingLevels: [Float] = []
        var recordingPartials: [String] = []
        var quickAskLevels: [Float] = []
        var quickAskPartials: [String] = []

        router.updateCallbacks(for: recordingSession) { callbacks in
            callbacks.onAudioLevelUpdate = { recordingLevels.append($0) }
            callbacks.onPartialResult = { recordingPartials.append($0.text) }
        }

        router.updateCallbacks(for: quickAskSession) { callbacks in
            callbacks.onAudioLevelUpdate = { quickAskLevels.append($0) }
            callbacks.onPartialResult = { quickAskPartials.append($0.text) }
        }

        router.setActiveSession(recordingSession)
        router.dispatchAudioLevel(0.25)
        router.dispatchPartialResult(TranscriptionResult(text: "recording", type: .partial))

        router.setActiveSession(quickAskSession)
        router.dispatchAudioLevel(0.75)
        router.dispatchPartialResult(TranscriptionResult(text: "quick-ask", type: .partial))

        #expect(recordingLevels == [0.25])
        #expect(recordingPartials == ["recording"])
        #expect(quickAskLevels == [0.75])
        #expect(quickAskPartials == ["quick-ask"])
    }

    @Test("快速切换入口不会产生回调污染")
    func rapidEntrypointSwitchDoesNotContaminateCallbacks() {
        let router = AudioCallbackRouter()
        let recordingSession = UUID()
        let quickAskSession = UUID()

        router.ensureSession(recordingSession)
        router.ensureSession(quickAskSession)

        var recordingEvents: [Int] = []
        var quickAskEvents: [Int] = []

        router.updateCallbacks(for: recordingSession) { callbacks in
            callbacks.onAudioLevelUpdate = { level in
                recordingEvents.append(Int(level))
            }
        }

        router.updateCallbacks(for: quickAskSession) { callbacks in
            callbacks.onAudioLevelUpdate = { level in
                quickAskEvents.append(Int(level))
            }
        }

        for event in 0..<100 {
            let useRecording = event.isMultiple(of: 2)
            router.setActiveSession(useRecording ? recordingSession : quickAskSession)
            router.dispatchAudioLevel(Float(event))
        }

        #expect(recordingEvents.count == 50)
        #expect(quickAskEvents.count == 50)
        #expect(recordingEvents.first == 0)
        #expect(quickAskEvents.first == 1)
        #expect(recordingEvents.last == 98)
        #expect(quickAskEvents.last == 99)
    }

    @Test("移除当前活跃会话后不会残留脏 activeSession")
    func removingActiveSessionClearsActiveSession() {
        let router = AudioCallbackRouter()
        let recordingSession = UUID()
        let quickAskSession = UUID()

        router.ensureSession(recordingSession)
        router.ensureSession(quickAskSession)
        router.setActiveSession(quickAskSession)

        router.removeSession(quickAskSession)

        #expect(router.activeSessionID == nil)

        router.setActiveSession(recordingSession)
        #expect(router.activeSessionID == recordingSession)
    }
}
