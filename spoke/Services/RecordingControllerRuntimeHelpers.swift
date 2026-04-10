import AppKit
import Foundation
import os

func runRecordingControllerOnMain(
    _ controller: RecordingController?,
    _ action: @escaping @MainActor (RecordingController) -> Void
) {
    runtimeRunOnMain(owner: controller, action)
}

func runRecordingControllerDependenciesOnMain(
    _ dependencies: RecordingControllerDependencies,
    _ action: @escaping @MainActor (RecordingControllerDependencies) -> Void
) {
    runtimeRunOnMainValue(dependencies, action)
}

func runRecordingPostprocess(
    _ operation: @escaping @Sendable () async -> Void
) {
    runtimeRunAsync(operation)
}

@MainActor
func triggerRecordingControllerOpenSettings() {
    if !NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil) {
        assertionFailure("AppDelegate should handle openSettings via responder chain")
    }
}

func runRecordingControllerAsync(
    _ controller: RecordingController?,
    _ action: @escaping @MainActor (RecordingController) async -> Void
) {
    runtimeRunOnMainAsync(owner: controller, action)
}

func makeRecordingDurationTimer(
    interval: TimeInterval = 0.1,
    owner: RecordingController?,
    action: @escaping @MainActor (RecordingController) -> Void
) -> Timer {
    runtimeMakeOwnedTimer(interval: interval, repeats: true, owner: owner, action: action)
}

@MainActor
func wireRecordingHUDCallbacks(
    hudManager: FloatingHUDManager,
    onComplete: @escaping () -> Void,
    onCancel: @escaping () -> Void
) {
    hudManager.onComplete = onComplete
    hudManager.onCancel = onCancel
}

@MainActor
func clearRecordingHUDCallbacks(
    hudManager: FloatingHUDManager
) {
    hudManager.onComplete = nil
    hudManager.onCancel = nil
}

@MainActor
func wireRecordingFeatureHotKeyCallbacks(
    hotKeyService: HotKeyService,
    onQuickAskStart: @escaping () -> Void,
    onQuickAskSend: @escaping () -> Void,
    onOpenSettings: @escaping () -> Void,
    onMessagePanelToggle: @escaping () -> Void,
    onLiveCaptionToggle: @escaping () -> Void,
    onClipboardPipelineTrigger: @escaping () -> Void
) {
    hotKeyService.onQuickAskStart = onQuickAskStart
    hotKeyService.onQuickAskSend = onQuickAskSend
    hotKeyService.onOpenSettings = onOpenSettings
    hotKeyService.onMessagePanelToggle = onMessagePanelToggle
    hotKeyService.onLiveCaptionToggle = onLiveCaptionToggle
    hotKeyService.onClipboardPipelineTrigger = onClipboardPipelineTrigger
}

@MainActor
func clearRecordingFeatureHotKeyCallbacks(
    hotKeyService: HotKeyService
) {
    hotKeyService.onQuickAskStart = nil
    hotKeyService.onQuickAskSend = nil
    hotKeyService.onOpenSettings = nil
    hotKeyService.onMessagePanelToggle = nil
    hotKeyService.onLiveCaptionToggle = nil
    hotKeyService.onClipboardPipelineTrigger = nil
}

@MainActor
func wireRecordingCaptureHotKeyCallbacks(
    hotKeyService: HotKeyService,
    onRecordingStart: @escaping () -> Void,
    onRecordingStop: @escaping () -> Void
) {
    hotKeyService.onRecordingStart = onRecordingStart
    hotKeyService.onRecordingStop = onRecordingStop
}

@MainActor
func clearRecordingCaptureHotKeyCallbacks(
    hotKeyService: HotKeyService
) {
    hotKeyService.onRecordingStart = nil
    hotKeyService.onRecordingStop = nil
}

@MainActor
func wireRecordingAudioCallbacks(
    audioService: AudioRecorderService,
    sessionID: UUID,
    onAudioLevelUpdate: ((Float) -> Void)?,
    onPartialResult: ((TranscriptionResult) -> Void)?,
    onFinalResult: ((String) -> Void)?,
    onError: ((Error) -> Void)?
) {
    audioService.updateCallbackSession(sessionID) { callbacks in
        callbacks.onAudioLevelUpdate = onAudioLevelUpdate
        callbacks.onPartialResult = onPartialResult
        callbacks.onFinalResult = onFinalResult
        callbacks.onError = onError
    }
}
