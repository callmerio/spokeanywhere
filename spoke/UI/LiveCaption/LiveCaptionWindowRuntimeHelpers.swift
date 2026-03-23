import Foundation

func runLiveCaptionWindowAsync(
    _ manager: LiveCaptionWindowManager?,
    _ action: @escaping @MainActor (LiveCaptionWindowManager) async -> Void
) {
    runtimeRunOnMainAsync(owner: manager, action)
}

func postLiveCaptionWindowToggle(
    notificationCenter: NotificationCenter = .default
) {
    notificationCenter.post(name: .liveCaptionDidToggle, object: nil)
}
