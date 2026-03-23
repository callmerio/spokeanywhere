import Foundation

func runImageUpscalerModelManagerOnMain(
    _ manager: ImageUpscalerModelManager?,
    _ action: @escaping @MainActor (ImageUpscalerModelManager) -> Void
) {
    runtimeRunOnMain(owner: manager, action)
}

