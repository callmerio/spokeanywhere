import Foundation

@MainActor
extension LLMPipelineDependencies {
    static let live = LLMPipelineDependencies(
        settings: .shared,
        contextService: .shared,
        clipboardHistory: .shared,
        screenOCR: .shared,
        shouldUseLLMForCorrection: { UserDefaults.standard.useLLMForCorrection },
        dictionaryEntries: { DictionaryService.shared.entries }
    )
}

