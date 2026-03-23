import Foundation

@MainActor
extension DictionarySettingsDependencies {
    static let live = DictionarySettingsDependencies(
        dictionaryService: .shared,
        transcriptionManager: .shared,
        vocabularyService: .shared
    )
}

