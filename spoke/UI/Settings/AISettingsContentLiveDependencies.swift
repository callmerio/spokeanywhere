import Foundation

@MainActor
extension AISettingsContentDependencies {
    static let live = AISettingsContentDependencies(
        llmSettings: .shared,
        appSettings: .shared,
        runConnectionTest: runAISettingsConnectionTest
    )
}
