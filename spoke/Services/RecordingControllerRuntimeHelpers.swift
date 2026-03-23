import AppKit
import Foundation

func runRecordingControllerOnMain(
    _ controller: RecordingController?,
    _ action: @escaping @MainActor (RecordingController) -> Void
) {
    Task { @MainActor in
        guard let controller else { return }
        action(controller)
    }
}

func runRecordingControllerDependenciesOnMain(
    _ dependencies: RecordingControllerDependencies,
    _ action: @escaping @MainActor (RecordingControllerDependencies) -> Void
) {
    Task { @MainActor in
        action(dependencies)
    }
}

func runRecordingPostprocess(
    _ operation: @escaping @Sendable () async -> Void
) {
    Task {
        await operation()
    }
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
    Task { @MainActor in
        guard let controller else { return }
        await action(controller)
    }
}

func makeRecordingDurationTimer(
    interval: TimeInterval = 0.1,
    owner: RecordingController?,
    action: @escaping @MainActor (RecordingController) -> Void
) -> Timer {
    Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
        runRecordingControllerOnMain(owner, action)
    }
}
