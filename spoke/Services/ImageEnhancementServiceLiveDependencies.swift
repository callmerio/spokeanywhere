import Foundation

@MainActor
extension ImageEnhancementServiceDependencies {
    static let live = ImageEnhancementServiceDependencies(
        upscalingMode: { ScreenshotSettings.shared.upscalingMode },
        compiledModelURL: { ImageUpscalerModelManager.shared.getCompiledModelURL() }
    )
}

