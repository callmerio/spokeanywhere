import Foundation

@MainActor
extension AnswerPanelManagerDependencies {
    static let live = AnswerPanelManagerDependencies(
        historyService: .shared,
        postFollowUp: { panelId, prompt, attachments in
            NotificationCenter.default.post(
                name: .quickAskFollowUpRequested,
                object: nil,
                userInfo: [
                    "panelId": panelId,
                    "prompt": prompt,
                    "attachments": attachments
                ]
            )
        }
    )
}
