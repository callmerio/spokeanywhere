import Foundation

@MainActor
extension SelectionToolbarStateDependencies {
    static let live = SelectionToolbarStateDependencies(
        vocabularyService: .shared,
        appSettings: .shared,
        notificationCenter: .default
    )
}
