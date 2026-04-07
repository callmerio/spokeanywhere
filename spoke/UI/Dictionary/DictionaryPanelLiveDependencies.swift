import AppKit
import Foundation

@MainActor
extension DictionaryPanelDependencies {
    static let live = DictionaryPanelDependencies(
        localDictionary: currentServiceContainer().localDictionaryService,
        vocabularyService: currentServiceContainer().vocabularyService,
        openURL: { NSWorkspace.shared.open($0) }
    )
}
