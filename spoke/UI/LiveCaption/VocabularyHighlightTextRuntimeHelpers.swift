import Foundation

func runVocabularyHighlightMainActor(
    _ operation: @escaping @MainActor () async -> Void
) {
    runtimeRunOnMainAsync(operation)
}

@MainActor
func makeVocabularySelectionDebounceTask(
    _ coordinator: VocabularyHighlightText.Coordinator
) -> Task<Void, Never> {
    runtimeMakeDelayedTask(delayNs: 300_000_000, owner: coordinator) { owner in
        guard let textView = owner.lastTextView else { return }
        owner.handleSelectionCompleted(in: textView)
    }
}
