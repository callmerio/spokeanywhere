import Foundation

@MainActor
extension ToolbarSettingsDependencies {
    static let live = ToolbarSettingsDependencies(
        configService: currentServiceContainer().toolbarConfigService,
        llmSettings: currentServiceContainer().llmSettings
    )
}
