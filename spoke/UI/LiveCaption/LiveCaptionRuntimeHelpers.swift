import Foundation

@MainActor
func liveCaptionShouldAutoScroll(
    isAtBottom: Bool,
    isUserSelecting: Bool
) -> Bool {
    isAtBottom && !isUserSelecting
}

@MainActor
func liveCaptionBumpScrollIfNeeded(
    isAtBottom: Bool,
    isUserSelecting: Bool,
    bump: () -> Void
) {
    guard liveCaptionShouldAutoScroll(
        isAtBottom: isAtBottom,
        isUserSelecting: isUserSelecting
    ) else {
        return
    }
    bump()
}

func liveCaptionScheduleMain(
    after seconds: Double,
    _ operation: @escaping @MainActor () -> Void
) {
    runtimeRunOnMain(after: seconds, operation)
}

@MainActor
func liveCaptionResyncScrollAfterTranslation(
    shouldScroll: @escaping @MainActor () -> Bool,
    bump: @escaping @MainActor () -> Void
) {
    guard shouldScroll() else { return }
    bump()
    liveCaptionScheduleMain(after: 0.1) {
        guard shouldScroll() else { return }
        bump()
    }
}

func liveCaptionMarkAppeared(
    itemID: UUID,
    insert: @escaping @MainActor (UUID) -> Void
) {
    liveCaptionScheduleMain(after: 0.05) {
        insert(itemID)
    }
}

func liveCaptionResetCopiedIndicator(
    _ reset: @escaping @MainActor () -> Void
) {
    liveCaptionScheduleMain(after: 1.5, reset)
}
