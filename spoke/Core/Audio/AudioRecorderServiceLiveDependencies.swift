import Foundation

@MainActor
extension AudioRecorderServiceDependencies {
    static let live = AudioRecorderServiceDependencies(
        transcriptionManager: .shared,
        postProcess: { TranscriptionPostProcessor.shared.process($0) }
    )
}

