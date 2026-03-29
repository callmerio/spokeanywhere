import Foundation

@MainActor
struct QuickAskStateDependencies {
    let notificationCenter: NotificationCenter
}

@MainActor
extension QuickAskStateDependencies {
    static let live = Self(
        notificationCenter: .default
    )
}
