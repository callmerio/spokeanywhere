import Foundation

@MainActor
extension TranscriptionPostProcessorDependencies {
    static let live = TranscriptionPostProcessorDependencies(
        applyDictionary: { DictionaryService.shared.applyDictionary(to: $0) },
        recordWordUsage: { DictionaryService.shared.recordWordUsage($0) }
    )
}
