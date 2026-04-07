import Foundation

@MainActor
extension SelectionToolbarStateDependencies {
    static let live = SelectionToolbarStateDependencies(
        vocabularyService: .shared,
        appSettings: .shared,
        notificationCenter: .default,
        requestBuiltinAction: { action, context in
            Task {
                await SelectionActionService.shared.executeAction(action, context: context)
            }
        },
        requestToolbarAction: { action, context in
            Task {
                await SelectionActionService.shared.executeToolbarAction(action, context: context)
            }
        }
    )
}
