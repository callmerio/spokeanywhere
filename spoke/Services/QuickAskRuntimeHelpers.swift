import AppKit
import Foundation

func runQuickAskServiceOnMain(
    _ service: QuickAskService?,
    _ action: @escaping @MainActor (QuickAskService) async -> Void
) {
    runtimeRunOnMainAsync(owner: service, action)
}

func runQuickAskHUDManagerOnMain(
    _ manager: QuickAskHUDManager?,
    _ action: @escaping @MainActor (QuickAskHUDManager) -> Void
) {
    runtimeRunOnMain(owner: manager, action)
}

func runQuickAskHUDManagerAfterDelay(
    _ manager: QuickAskHUDManager?,
    seconds: Double,
    _ action: @escaping @MainActor (QuickAskHUDManager) -> Void
) {
    runtimeRunOnMain(after: seconds, owner: manager, action)
}

func runQuickAskServiceAfterDelay(
    _ service: QuickAskService?,
    seconds: Double,
    _ action: @escaping @MainActor (QuickAskService) -> Void
) {
    runtimeRunOnMain(after: seconds, owner: service, action)
}

func makeQuickAskTimer(
    interval: TimeInterval,
    repeats: Bool = false,
    owner: QuickAskService,
    action: @escaping @MainActor (QuickAskService) -> Void
) -> Timer {
    runtimeMakeOwnedTimer(interval: interval, repeats: repeats, owner: owner, action: action)
}

@MainActor
func triggerQuickAskOpenSettings() {
    _ = NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil)
}

@MainActor
func wireQuickAskHUDCallbacks(
    hudManager: QuickAskHUDManager,
    answerPanelManager: AnswerPanelManager,
    onSend: @escaping () -> Void,
    onCancel: @escaping () -> Void,
    onFollowUp: @escaping (UUID, String) async -> Void
) {
    hudManager.onSend = onSend
    hudManager.onCancel = onCancel
    answerPanelManager.onFollowUp = onFollowUp
}

@MainActor
func clearQuickAskHUDCallbacks(
    hudManager: QuickAskHUDManager,
    answerPanelManager: AnswerPanelManager
) {
    hudManager.onSend = nil
    hudManager.onCancel = nil
    answerPanelManager.onFollowUp = nil
}

@MainActor
func wireQuickAskAudioCallbacks(
    audioService: AudioRecorderService,
    existingSessionID: UUID?,
    onAudioLevelUpdate: ((Float) -> Void)?,
    onPartialResult: ((TranscriptionResult) -> Void)?,
    onError: ((Error) -> Void)?
) -> UUID {
    let sessionID = existingSessionID ?? audioService.createCallbackSession()
    audioService.updateCallbackSession(sessionID) { callbacks in
        callbacks.onAudioLevelUpdate = onAudioLevelUpdate
        callbacks.onPartialResult = onPartialResult
        callbacks.onFinalResult = nil
        callbacks.onError = onError
    }
    audioService.activateCallbackSession(sessionID)
    return sessionID
}

@MainActor
func clearQuickAskAudioCallbacks(
    audioService: AudioRecorderService,
    sessionID: UUID?
) {
    guard let sessionID else { return }
    audioService.removeCallbackSession(sessionID)
}
