import Foundation

func runMessagePanelAfterDelay(
    seconds: Double,
    _ operation: @escaping @MainActor () -> Void
) {
    runtimeRunOnMain(after: seconds, operation)
}

func runMessagePanelOnMain(
    _ operation: @escaping @MainActor () -> Void
) {
    runtimeRunOnMain(operation)
}

func runMessagePanelAsync(
    _ operation: @escaping @MainActor () async -> Void
) {
    runtimeRunOnMainAsync(operation)
}

func runMessagePanelDetached(
    _ operation: @escaping @Sendable () async -> Void
) {
    runtimeRunAsync(operation)
}

func runMessagePanelSummary(
    cardId: UUID
) async {
    await currentServiceContainer().summaryService.generateSummary(for: cardId)
}
