import Foundation

@MainActor
extension MessagePanelStateDependencies {
    static let live = MessagePanelStateDependencies(
        tagLibrary: .shared,
        attachmentStorage: .shared,
        attachmentImageCache: .shared,
        notificationCenter: .default,
        llmSettings: .shared,
        generateSummary: { @Sendable cardId in
            await runMessagePanelSummary(cardId: cardId)
        }
    )
}

