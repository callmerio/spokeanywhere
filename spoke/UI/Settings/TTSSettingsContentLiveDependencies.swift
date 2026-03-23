import Foundation

@MainActor
extension TTSSettingsContentDependencies {
    static let live = TTSSettingsContentDependencies(
        settings: .shared,
        ttsService: .shared
    )
}

