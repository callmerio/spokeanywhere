import Foundation

@MainActor
struct FormattedDefinitionViewDependencies {
    let parse: (String, String) -> ParsedDefinition
}

@MainActor
extension FormattedDefinitionViewDependencies {
    static let live = Self { word, definition in
        DictionaryDefinitionParser.shared.parse(word: word, definition: definition)
    }
}
