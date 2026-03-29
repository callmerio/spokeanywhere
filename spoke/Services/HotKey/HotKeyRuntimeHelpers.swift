import Foundation

func runHotKeyServiceOnMain(
    _ owner: HotKeyService?,
    _ action: @escaping @MainActor (HotKeyService) -> Void
) {
    runtimeRunOnMain(owner: owner, action)
}

func invokeHotKeyServiceCallback(
    _ owner: HotKeyService?,
    _ callback: @escaping @MainActor (HotKeyService) -> (() -> Void)?
) {
    runHotKeyServiceOnMain(owner) { service in
        callback(service)?()
    }
}

func makeHotKeyServiceObserver(
    notificationCenter: NotificationCenter,
    name: Notification.Name,
    owner: HotKeyService,
    action: @escaping @MainActor @Sendable (HotKeyService) -> Void
) -> NSObjectProtocol {
    notificationCenter.addObserver(
        forName: name,
        object: nil,
        queue: .main
    ) { [weak owner] _ in
        runHotKeyServiceOnMain(owner, action)
    }
}

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
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
        guard !workItem.isCancelled else { return }
        workItem.perform()
    }
}
