import Foundation
import Speech

func makeSpeechAnalyzerOperation(
    _ operation: @escaping @Sendable () async -> Void
) -> Task<Void, Never> {
    Task {
        await operation()
    }
}

@available(macOS 26.0, iOS 26.0, *)
@MainActor
func makeSpeechAnalyzerProviderOperation(
    owner: SpeechAnalyzerProvider?,
    _ action: @escaping @MainActor (SpeechAnalyzerProvider) async -> Void
) -> Task<Void, Never> {
    makeSpeechAnalyzerOperation {
        guard let owner else { return }
        await action(owner)
    }
}

@available(macOS 26.0, iOS 26.0, *)
func makeSpeechAnalyzerCancelOperation(
    _ analyzer: SpeechAnalyzer?
) -> Task<Void, Never> {
    makeSpeechAnalyzerOperation {
        await analyzer?.cancelAndFinishNow()
    }
}
