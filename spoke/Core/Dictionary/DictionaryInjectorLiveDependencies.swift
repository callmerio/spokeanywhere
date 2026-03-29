import Foundation

@MainActor
func currentDictionaryEntriesHash() -> Int {
    DictionaryService.shared.entries.hashValue
}
