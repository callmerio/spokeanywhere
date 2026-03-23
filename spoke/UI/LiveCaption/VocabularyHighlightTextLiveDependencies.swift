import Foundation

@MainActor
extension VocabularyHighlightDependencies {
    static let live: VocabularyHighlightDependencies = {
        let vocabularyService = VocabularyService.shared
        let dictionaryService = DictionaryAPIService.shared
        let translationStore = VocabularyTranslationStore()

        return VocabularyHighlightDependencies(
            highlightRanges: { vocabularyService.highlightRanges(in: $0) },
            containsVocabulary: { vocabularyService.contains($0) },
            addVocabulary: { _ = vocabularyService.add($0) },
            removeVocabulary: { word in
                if let item = vocabularyService.items.first(where: {
                    $0.word.lowercased() == word.lowercased()
                }) {
                    vocabularyService.remove(item.id)
                }
            },
            lookupDictionary: { word in
                await dictionaryService.lookup(word)
            },
            translationStore: translationStore
        )
    }()
}
