import Foundation

func makeClipboardHistoryTimer(
    interval: TimeInterval,
    owner: ClipboardHistoryService,
    action: @escaping @MainActor (ClipboardHistoryService) -> Void
) -> Timer {
    runtimeMakeOwnedTimer(interval: interval, repeats: true, owner: owner, action: action)
}
