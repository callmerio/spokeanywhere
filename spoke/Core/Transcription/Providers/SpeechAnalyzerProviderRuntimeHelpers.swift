import Foundation

func makeSpeechAnalyzerTask(
    _ operation: @escaping @Sendable () async -> Void
) -> Task<Void, Never> {
    Task {
        await operation()
    }
}
