import Foundation

@MainActor
extension TTSSettingsContentDependencies {
    static let live = TTSSettingsContentDependencies(
        settings: currentServiceContainer().ttsSettings,
        ttsService: currentServiceContainer().ttsService
    )
}
