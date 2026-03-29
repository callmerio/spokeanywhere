import AppKit
import Foundation

func parseLocalDictionaryBriefDefinition(word: String, definition: String) -> ParsedDefinition {
    DictionaryDefinitionParser.shared.parse(word: word, definition: definition)
}

func localDictionaryCompletions(for partialWord: String) -> [String] {
    let spellChecker = NSSpellChecker.shared
    return spellChecker.completions(
        forPartialWordRange: NSRange(location: 0, length: partialWord.count),
        in: partialWord,
        language: "en",
        inSpellDocumentWithTag: 0
    ) ?? []
}
