import AppKit
import Foundation

@MainActor
private func resolveSharedMessagePanelState() -> MessagePanelState {
    MessagePanelState.shared
}

@MainActor
extension SummaryServiceDependencies {
    static let live = SummaryServiceDependencies(
        messagePanelState: { resolveSharedMessagePanelState() },
        attachmentStorage: .shared,
        llmSettings: .shared,
        urlSession: .shared
    )
}

