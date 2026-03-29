import Foundation

func runSessionHistoryCopyFeedback(
    _ hideCopied: @escaping @MainActor () -> Void
) {
    Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(300))
        hideCopied()
    }
}
