@available(macOS 26.0, iOS 26.0, *)
@MainActor
extension SpeechAnalyzerProviderDependencies {
    static let live = SpeechAnalyzerProviderDependencies(
        dictionaryInjectionState: {
            let manager = transcriptionManager()
            return SpeechAnalyzerProviderDictionaryInjectionState(
                isEnabled: manager.isDictionaryInjectionEnabled,
                isPrepared: manager.isDictionaryPrepared,
                injector: manager.dictionaryInjector
            )
        },
        dictionaryLexicon: {
            let dictionaryService = currentDictionaryService()
            return SpeechAnalyzerProviderDictionaryLexicon(
                words: Set(dictionaryService.getAllWords()),
                trainingPhrases: dictionaryService.getAllTrainingPhrases()
            )
        }
    )

    private static func transcriptionManager() -> TranscriptionManager {
        TranscriptionManager.shared
    }

    private static func currentDictionaryService() -> DictionaryService {
        DictionaryService.shared
    }
}
