import AppKit
import Foundation

@MainActor
extension DictionaryPanelDependencies {
    static let live = DictionaryPanelDependencies(
        localDictionary: .shared,
        vocabularyService: .shared,
        openURL: { NSWorkspace.shared.open($0) }
    )
}
