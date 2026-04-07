import Foundation

@MainActor
extension ModelPickerDependencies {
    static let live = ModelPickerDependencies(
        llmSettings: currentServiceContainer().llmSettings,
        loadModels: runModelPickerLoadModels
    )
}
