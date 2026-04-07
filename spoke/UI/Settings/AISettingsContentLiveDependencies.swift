import Foundation

@MainActor
extension AISettingsContentDependencies {
    static let live = AISettingsContentDependencies(
        llmSettings: currentServiceContainer().llmSettings,
        appSettings: currentServiceContainer().appSettingsConcrete,
        runConnectionTest: runAISettingsConnectionTest
    )
}
