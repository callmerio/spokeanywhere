import Foundation

@MainActor
extension ModelPickerDependencies {
    static let live = ModelPickerDependencies(
        llmSettings: .shared,
        loadModels: runModelPickerLoadModels
    )
}
