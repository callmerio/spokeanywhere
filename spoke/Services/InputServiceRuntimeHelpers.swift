import Foundation

func makeInputServiceStabilityTask(
    owner: InputService,
    delayMs: UInt64,
    action: @escaping @MainActor (InputService) -> Void
) -> Task<Void, Never> {
    runtimeMakeDelayedTask(
        delayNs: delayMs * 1_000_000,
        owner: owner,
        action
    )
}
