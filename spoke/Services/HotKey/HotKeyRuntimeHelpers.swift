import Foundation

func makeHotKeyDelayedTask<Owner: AnyObject>(
    after seconds: TimeInterval,
    owner: Owner?,
    _ action: @escaping @MainActor (Owner) -> Void
) -> Task<Void, Never> {
    Task { @MainActor [weak owner] in
        try? await Task.sleep(for: .seconds(seconds))
        guard let owner else { return }
        action(owner)
    }
}

func scheduleHotKeyWorkItem(
    after seconds: Double,
    _ workItem: DispatchWorkItem
) {
    runtimeRunOnMain(after: seconds) {
        guard !workItem.isCancelled else { return }
        workItem.perform()
    }
}
