import AppKit
import Foundation

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
