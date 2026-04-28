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

func scheduleAppKitScrollWorkItem(
    after seconds: Double,
    _ workItem: DispatchWorkItem
) {
    runtimeRunOnMain(after: seconds) {
        guard !workItem.isCancelled else { return }
        workItem.perform()
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
