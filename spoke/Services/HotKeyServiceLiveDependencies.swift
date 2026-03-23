import Foundation

@MainActor
extension HotKeyServiceDependencies {
    static let live = HotKeyServiceDependencies(
        appSettings: .shared,
        notificationCenter: .default
    )
}
