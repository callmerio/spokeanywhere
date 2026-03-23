import Foundation

func runSelectionActionServiceOnMain(
    _ service: SelectionActionService?,
    _ action: @escaping @MainActor (SelectionActionService) async -> Void
) {
    Task { @MainActor in
        guard let service else { return }
        await action(service)
    }
}
