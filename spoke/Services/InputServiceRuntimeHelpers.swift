import Foundation

func makeInputServiceStabilityTask(
    owner: InputService,
    delayMs: UInt64,
    action: @escaping @MainActor (InputService) -> Void
) -> Task<Void, Never> {
    Task { [weak owner] in
        do {
            try await Task.sleep(nanoseconds: delayMs * 1_000_000)
            guard !Task.isCancelled else { return }
            guard let owner else { return }
            await MainActor.run {
                action(owner)
            }
        } catch {
            // Task 被取消，视为正常路径
        }
    }
}
