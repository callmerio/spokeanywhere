import Foundation

@MainActor
extension DictionaryPanelViewDependencies {
    static let live = DictionaryPanelViewDependencies(
        parseDefinition: { word, definition in
            DictionaryDefinitionParser.shared.parse(word: word, definition: definition)
        }
    )
}

