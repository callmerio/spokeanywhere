import Foundation

@MainActor
extension LiveCaptionWindowManagerDependencies {
    static let live = LiveCaptionWindowManagerDependencies(
        manager: currentServiceContainer().liveCaptionManager,
        translator: currentServiceContainer().translationService,
        viewDependencies: .live(
            lookupWord: { word in
                await currentServiceContainer().unifiedDictionaryService.lookup(word)
            },
            markVocabulary: { text in
                currentServiceContainer().vocabularyService.markVocabulary(in: text)
            },
            selectionToolbarState: currentServiceContainer().selectionToolbarState,
            selectionToolbarManager: currentServiceContainer().selectionToolbarManager
        )
    )
}

@MainActor
func liveCaptionAvailabilityIsTranslationAvailable() -> Bool {
    currentServiceContainer().translationService.isAvailable
}
