import Foundation

func makeResourceMonitorTimer(
    interval: TimeInterval,
    owner: ResourceMonitor,
    action: @escaping @MainActor (ResourceMonitor) -> Void
) -> Timer {
    runtimeMakeOwnedTimer(interval: interval, repeats: true, owner: owner, action: action)
}

func invalidateResourceMonitorTimer(
    _ timer: inout Timer?
) {
    runtimeInvalidateTimer(&timer)
}
