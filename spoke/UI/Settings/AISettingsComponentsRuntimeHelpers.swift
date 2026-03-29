import Foundation

typealias ModelPickerLoadModelsRunner = @MainActor (
    _ profile: ProviderProfile,
    _ llmSettings: LLMSettings,
    _ update: @escaping @MainActor ([String]) -> Void
) -> Void

@MainActor
func runModelPickerLoadModels(
    profile: ProviderProfile,
    llmSettings: LLMSettings,
    update: @escaping @MainActor ([String]) -> Void
) {
    Task {
        let currentProfile = llmSettings.profiles.first { $0.id == profile.id } ?? profile
        let models = await llmSettings.fetchModels(for: currentProfile)
        await MainActor.run {
            update(models)
        }
    }
}
