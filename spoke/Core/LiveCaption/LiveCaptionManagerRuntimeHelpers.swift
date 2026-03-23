import Foundation

func runLiveCaptionManagerOnMain(
    _ manager: LiveCaptionManager?,
    _ action: @escaping @MainActor (LiveCaptionManager) -> Void
) {
    runtimeRunOnMain(owner: manager, action)
}

func runLiveCaptionManagerAsync(
    _ manager: LiveCaptionManager?,
    _ action: @escaping @MainActor (LiveCaptionManager) async -> Void
) {
    runtimeRunOnMainAsync(owner: manager, action)
}

func makeLiveCaptionVolatileTranslationTask(
    text: String,
    translator: TranslationService,
    currentVersion: Int,
    update: @escaping @MainActor (String, Int) -> Void
) -> Task<Void, Never> {
    Task {
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }

        if let translated = await translator.translate(text) {
            guard !Task.isCancelled else { return }
            await MainActor.run {
                update(translated, currentVersion)
            }
        }
    }
}
