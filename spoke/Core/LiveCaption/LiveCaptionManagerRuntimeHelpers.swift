import Foundation

typealias LiveCaptionAsyncTask = Task<Void, Never>

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

func runLiveCaptionTranslationRetry(
    text: String,
    translator: TranslationService,
    onTranslated: @escaping @MainActor (String) -> Void
) async -> String? {
    for attempt in 1...3 {
        guard !Task.isCancelled else { return nil }

        if let translated = await translator.translate(text) {
            await MainActor.run {
                onTranslated(translated)
            }
            return translated
        }

        if attempt < 3 {
            do {
                try await Task.sleep(for: .milliseconds(200 * attempt))
            } catch {
                return nil
            }
        }
    }

    return nil
}
