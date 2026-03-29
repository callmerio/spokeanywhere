#if DEBUG
import Foundation

@MainActor
struct DebugAutomationTriggerServiceDependencies {
    let addObserver: (
        _ forName: Notification.Name,
        _ object: String?,
        _ queue: OperationQueue?,
        _ using: @escaping @Sendable (Notification) -> Void
    ) -> NSObjectProtocol
    let removeObserver: (NSObjectProtocol) -> Void
}

@MainActor
extension DebugAutomationTriggerServiceDependencies {
    static let live = Self(
        addObserver: { name, object, queue, handler in
            DistributedNotificationCenter.default().addObserver(
                forName: name,
                object: object,
                queue: queue,
                using: handler
            )
        },
        removeObserver: { observer in
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    )
}
#endif
