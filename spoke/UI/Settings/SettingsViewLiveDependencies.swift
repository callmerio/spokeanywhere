import Foundation

@MainActor
struct SettingsViewDependencies {
    let settingsSwitchToToolbarPublisher: () -> NotificationCenter.Publisher
}

@MainActor
extension SettingsViewDependencies {
    static let live = Self(
        settingsSwitchToToolbarPublisher: {
            NotificationCenter.default.publisher(for: .settingsSwitchToToolbar)
        }
    )
}
