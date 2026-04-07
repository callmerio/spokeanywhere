import Foundation

@MainActor
extension DictionarySettingsDependencies {
    static let live = DictionarySettingsDependencies(
        dictionaryService: currentServiceContainer().dictionaryService,
        transcriptionManager: currentServiceContainer().transcriptionManagerConcrete,
        vocabularyService: currentServiceContainer().vocabularyService
    )
}
