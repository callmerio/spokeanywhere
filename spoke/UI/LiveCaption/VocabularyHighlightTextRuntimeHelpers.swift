import Foundation

func runVocabularyHighlightMainActor(
    _ operation: @escaping @MainActor () async -> Void
) {
    Task { @MainActor in
        await operation()
    }
}
