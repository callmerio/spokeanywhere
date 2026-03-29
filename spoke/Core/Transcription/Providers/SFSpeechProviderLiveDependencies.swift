@MainActor
extension SFSpeechProviderDependencies {
    static let live = SFSpeechProviderDependencies(
        dictionaryInjectionState: {
            let manager = transcriptionManager()
            return SFSpeechProviderDictionaryInjectionState(
                isEnabled: manager.isDictionaryInjectionEnabled,
                isPrepared: manager.isDictionaryPrepared,
                injector: manager.dictionaryInjector
            )
        }
    )

    private static func transcriptionManager() -> TranscriptionManager {
        TranscriptionManager.shared
    }
}
