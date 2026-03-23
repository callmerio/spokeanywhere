import Foundation

func runTranscriptionManagerOnMain(
    _ manager: TranscriptionManager?,
    _ action: @escaping @MainActor (TranscriptionManager) -> Void
) {
    runtimeRunOnMain(owner: manager, action)
}

func runTranscriptionManagerAsync(
    _ manager: TranscriptionManager?,
    _ action: @escaping @MainActor (TranscriptionManager) async -> Void
) {
    runtimeRunOnMainAsync(owner: manager, action)
}

