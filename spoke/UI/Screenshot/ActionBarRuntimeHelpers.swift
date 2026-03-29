import Foundation

@MainActor
func runActionBarOCR(
    button: ActionBarButton,
    owner: ActionBarView,
    onText: @escaping @MainActor (String) -> Void,
    operation: @escaping @Sendable () async -> String
) {
    Task {
        let text = await operation()
        guard owner.window != nil else { return }
        await MainActor.run {
            if !text.isEmpty {
                onText(text)
            }
            button.stopSpinner()
            if !text.isEmpty {
                button.showFeedback()
            }
        }
    }
}

func runActionBarFeedbackReset(
    after seconds: Double,
    owner: ActionBarButton?,
    _ action: @escaping @MainActor (ActionBarButton) -> Void
) {
    runtimeRunOnMain(after: seconds, owner: owner, action)
}
