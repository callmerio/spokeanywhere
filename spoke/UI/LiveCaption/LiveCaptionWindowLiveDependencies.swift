import Foundation

@MainActor
extension LiveCaptionWindowManagerDependencies {
    static let live = LiveCaptionWindowManagerDependencies(
        manager: .shared,
        translator: .shared,
        viewDependencies: .live(
            lookupWord: { word in
                await UnifiedDictionaryService.shared.lookup(word)
            },
            markVocabulary: { text in
                VocabularyService.shared.markVocabulary(in: text)
            },
            selectionToolbarState: .shared,
            selectionToolbarManager: .shared
        )
    )
}

@MainActor
func liveCaptionAvailabilityIsTranslationAvailable() -> Bool {
    TranslationService.shared.isAvailable
}

