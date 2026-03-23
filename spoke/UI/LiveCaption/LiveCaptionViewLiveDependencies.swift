import Foundation

@MainActor
extension LiveCaptionViewDependencies {
    static func live(
        lookupWord: @escaping (String) async -> UnifiedDictionaryResult?,
        markVocabulary: @escaping (String) -> String,
        selectionToolbarState: SelectionToolbarState,
        selectionToolbarManager: SelectionToolbarManager
    ) -> Self {
        LiveCaptionViewDependencies(
            lookupWord: lookupWord,
            markVocabulary: markVocabulary,
            showSelectionToolbar: { context, point in
                selectionToolbarState.show(with: context)
                selectionToolbarManager.show(at: point)
            },
            showDictionaryResult: { data, word, context, point in
                selectionToolbarState.currentContext = context
                selectionToolbarState.showDictionaryResult(data, forText: word)
                try? await Task.sleep(for: .milliseconds(16))
                selectionToolbarManager.show(at: point)
            },
            showDictionaryError: { word, context, point in
                selectionToolbarState.currentContext = context
                selectionToolbarState.showDictionaryError(.notFound, word: word)
                try? await Task.sleep(for: .milliseconds(16))
                selectionToolbarManager.show(at: point)
            },
            notificationCenter: .default
        )
    }
}
