import Foundation

@MainActor
extension ToolbarSettingsDependencies {
    static let live = ToolbarSettingsDependencies(
        configService: .shared,
        llmSettings: .shared
    )
}

