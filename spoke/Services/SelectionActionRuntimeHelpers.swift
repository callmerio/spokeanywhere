import Foundation

func runSelectionActionServiceOnMain(
    _ service: SelectionActionService?,
    _ action: @escaping @MainActor (SelectionActionService) async -> Void
) {
    runtimeRunOnMainAsync(owner: service, action)
}
