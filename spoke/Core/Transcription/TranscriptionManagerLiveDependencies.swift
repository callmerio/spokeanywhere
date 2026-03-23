import Foundation

@MainActor
extension TranscriptionManagerDependencies {
    static let live = TranscriptionManagerDependencies(
        modelManager: .shared,
        dictionaryService: .shared,
        notificationCenter: .default
    )
}

