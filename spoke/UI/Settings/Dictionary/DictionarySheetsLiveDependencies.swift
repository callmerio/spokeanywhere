import Foundation

@MainActor
struct AddDictionaryEntrySheetDependencies {
    let dictionaryService: DictionaryService
}

@MainActor
struct EditDictionaryEntrySheetDependencies {
    let dictionaryService: DictionaryService
}

@MainActor
struct VocabularyListSheetDependencies {
    let vocabularyService: VocabularyService
}

@MainActor
extension AddDictionaryEntrySheetDependencies {
    static let live = Self(dictionaryService: currentServiceContainer().dictionaryService)
}

@MainActor
extension EditDictionaryEntrySheetDependencies {
    static let live = Self(dictionaryService: currentServiceContainer().dictionaryService)
}

@MainActor
extension VocabularyListSheetDependencies {
    static let live = Self(vocabularyService: currentServiceContainer().vocabularyService)
}
