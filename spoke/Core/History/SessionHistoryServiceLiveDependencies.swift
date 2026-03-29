@MainActor
extension SessionHistoryServiceDependencies {
    static let live = SessionHistoryServiceDependencies(
        generateAITitle: { content in
            await llmSettings().generateTitle(from: content)
        }
    )

    private static func llmSettings() -> LLMSettings {
        LLMSettings.shared
    }
}
