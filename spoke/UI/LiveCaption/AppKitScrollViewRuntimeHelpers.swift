import AppKit
import Foundation

func runAppKitScrollOnMain(
    _ operation: @escaping @MainActor () -> Void
) {
    runtimeRunOnMain(operation)
}

func scheduleAppKitScrollMain(
    after seconds: Double,
    _ operation: @escaping @MainActor () -> Void
) {
    runtimeRunOnMain(after: seconds, operation)
}

func makeAppKitScrollTimer(
    interval: TimeInterval,
    repeats: Bool = true,
    _ operation: @escaping @MainActor () -> Void
) -> Timer {
    Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats) { _ in
        runAppKitScrollOnMain(operation)
    }
}

func addAppKitScrollObserver(
    _ observer: Any,
    selector: Selector,
    name: NSNotification.Name,
    object: Any? = nil,
    notificationCenter: NotificationCenter = .default
) {
    notificationCenter.addObserver(observer, selector: selector, name: name, object: object)
}

func removeAppKitScrollObserver(
    _ observer: Any,
    notificationCenter: NotificationCenter = .default
) {
    notificationCenter.removeObserver(observer)
}
