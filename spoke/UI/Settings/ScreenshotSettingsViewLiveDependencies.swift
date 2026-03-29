import Foundation

@MainActor
struct ScreenshotSettingsViewDependencies {
    let settings: ScreenshotSettings
    let modelManager: ImageUpscalerModelManager
}

@MainActor
extension ScreenshotSettingsViewDependencies {
    static let live = Self(
        settings: .shared,
        modelManager: .shared
    )
}
