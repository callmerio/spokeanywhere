import AppKit
import Foundation

struct AppKitScrollAdjustmentRequest: Equatable {
    let id: Int
    let deltaY: CGFloat
}

func appKitScrollContentGrew(
    maxScrollY: CGFloat,
    lastMaxScrollY: CGFloat,
    tolerance: CGFloat = 5
) -> Bool {
    maxScrollY > lastMaxScrollY + tolerance
}

func appKitScrollUserScrolledAwayFromBottom(
    currentY: CGFloat,
    lastScrollY: CGFloat,
    tolerance: CGFloat = 3
) -> Bool {
    currentY < lastScrollY - tolerance
}

func appKitScrollNeedsCatchUp(
    gap: CGFloat,
    threshold: CGFloat
) -> Bool {
    gap > threshold
}

func appKitScrollTargetMetrics(
    contentHeight: CGFloat,
    clipHeight: CGFloat,
    extraOffset: CGFloat
) -> (maxScrollY: CGFloat, targetY: CGFloat)? {
    guard contentHeight.isFinite, clipHeight.isFinite, extraOffset.isFinite else {
        return nil
    }

    let maxScrollY = max(0, contentHeight - clipHeight)
    let targetY = maxScrollY + extraOffset

    guard maxScrollY.isFinite, targetY.isFinite else {
        return nil
    }

    return (maxScrollY, targetY)
}

func appKitScrollResolvedOrigin(
    currentY: CGFloat,
    deltaY: CGFloat,
    maxScrollY: CGFloat,
    extraOffset: CGFloat
) -> CGFloat {
    let maximumY = maxScrollY + extraOffset
    return min(max(0, currentY + deltaY), maximumY)
}

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
