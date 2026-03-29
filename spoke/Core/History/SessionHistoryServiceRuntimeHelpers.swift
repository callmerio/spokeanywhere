import Foundation

func runSessionHistoryAsync(
    _ service: SessionHistoryService?,
    _ action: @escaping @MainActor (SessionHistoryService) async -> Void
) {
    runtimeRunOnMainAsync(owner: service, action)
}
