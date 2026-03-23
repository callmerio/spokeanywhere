import Foundation

@MainActor
extension UnifiedDictionaryServiceDependencies {
    static let live = UnifiedDictionaryServiceDependencies(
        localService: .shared,
        remoteService: .shared,
        parseDefinition: { word, definition in
            DictionaryDefinitionParser.shared.parse(word: word, definition: definition)
        }
    )
}

