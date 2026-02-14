import Foundation

/// 音频事件回调集合
@MainActor
struct AudioCallbacks {
    var onAudioLevelUpdate: ((Float) -> Void)?
    var onPartialResult: ((TranscriptionResult) -> Void)?
    var onFinalResult: ((String) -> Void)?
    var onError: ((Error) -> Void)?
}

/// 会话级音频回调路由器
/// 通过 active session 避免不同入口互相覆盖回调。
@MainActor
final class AudioCallbackRouter {

    private var callbacksBySession: [UUID: AudioCallbacks] = [:]
    private(set) var activeSessionID: UUID?

    func ensureSession(_ sessionID: UUID) {
        if callbacksBySession[sessionID] == nil {
            callbacksBySession[sessionID] = AudioCallbacks()
        }
    }

    func callbacks(for sessionID: UUID) -> AudioCallbacks {
        callbacksBySession[sessionID] ?? AudioCallbacks()
    }

    func updateCallbacks(for sessionID: UUID, _ update: (inout AudioCallbacks) -> Void) {
        var callbacks = callbacksBySession[sessionID] ?? AudioCallbacks()
        update(&callbacks)
        callbacksBySession[sessionID] = callbacks
    }

    func resetCallbacks(for sessionID: UUID) {
        callbacksBySession[sessionID] = AudioCallbacks()
    }

    func removeSession(_ sessionID: UUID) {
        callbacksBySession.removeValue(forKey: sessionID)
        if activeSessionID == sessionID {
            activeSessionID = nil
        }
    }

    func setActiveSession(_ sessionID: UUID?) {
        guard let sessionID else {
            activeSessionID = nil
            return
        }

        ensureSession(sessionID)
        activeSessionID = sessionID
    }

    func dispatchAudioLevel(_ level: Float) {
        guard let activeSessionID else { return }
        callbacksBySession[activeSessionID]?.onAudioLevelUpdate?(level)
    }

    func dispatchPartialResult(_ result: TranscriptionResult) {
        guard let activeSessionID else { return }
        callbacksBySession[activeSessionID]?.onPartialResult?(result)
    }

    func dispatchFinalResult(_ text: String) {
        guard let activeSessionID else { return }
        callbacksBySession[activeSessionID]?.onFinalResult?(text)
    }

    func dispatchError(_ error: Error) {
        guard let activeSessionID else { return }
        callbacksBySession[activeSessionID]?.onError?(error)
    }
}
