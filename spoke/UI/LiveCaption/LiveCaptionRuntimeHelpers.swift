import Foundation

func runLiveCaptionLocaleChange(
    manager: LiveCaptionManager,
    languageId: String
) {
    Task(priority: .userInitiated) {
        await manager.setLocale(languageId)
    }
}

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

func appKitScrollShouldTreatAsContentGrowth(
    previouslyAtBottom: Bool,
    atBottom: Bool,
    scrollY: CGFloat,
    lastScrollY: CGFloat,
    maxScrollY: CGFloat,
    lastMaxScrollY: CGFloat,
    contentGrowthTolerance: CGFloat = 5,
    userScrollTolerance: CGFloat = 3
) -> Bool {
    guard previouslyAtBottom, !atBottom else { return false }

    let contentGrew = maxScrollY > lastMaxScrollY + contentGrowthTolerance
    let userScrolledAway = scrollY < lastScrollY - userScrollTolerance
    return contentGrew && !userScrolledAway
}

func appKitScrollShouldCatchUp(
    gap: CGFloat,
    threshold: CGFloat,
    maxAllowedGap: CGFloat = 500
) -> Bool {
    gap > threshold && gap <= maxAllowedGap
}

func appKitScrollShouldHandleOverscroll(
    scrollY: CGFloat,
    maxScrollY: CGFloat,
    overscrollThreshold: CGFloat = 15
) -> Bool {
    scrollY > maxScrollY + overscrollThreshold
}

@MainActor
func makeLiveCaptionSelectionContext(
    text: String,
    screenPoint: CGPoint
) -> SelectionContext {
    SelectionContext(
        selectedText: text,
        selectionBounds: CGRect(
            x: screenPoint.x - 50,
            y: screenPoint.y,
            width: 100,
            height: 20
        ),
        sourceAppBundleId: Bundle.main.bundleIdentifier ?? "",
        sourceAppName: "SpokenAnyWhere"
    )
}

@MainActor
func makeLiveCaptionDictionaryData(
    from result: UnifiedDictionaryResult
) -> DictionaryData {
    let senses = result.senses.map { sense in
        DictionarySense(
            pos: sense.pos,
            chinese: sense.chinese,
            english: sense.english,
            examples: sense.examples.isEmpty ? nil : sense.examples
        )
    }

    return DictionaryData(
        word: result.word,
        phonetic: result.phonetic,
        senses: senses,
        lemma: result.lemma,
        lemmaInfo: nil
    )
}

func runLiveCaptionWordLookup(
    word: String,
    screenPoint: CGPoint,
    dependencies: LiveCaptionViewDependencies,
    finishInteraction: @escaping @MainActor () -> Void
) {
    Task(priority: .userInitiated) { @MainActor in
        defer { finishInteraction() }

        let context = makeLiveCaptionSelectionContext(
            text: word,
            screenPoint: screenPoint
        )

        if let result = await dependencies.lookupWord(word) {
            let data = makeLiveCaptionDictionaryData(from: result)
            await dependencies.showDictionaryResult(data, word, context, screenPoint)
        } else {
            await dependencies.showDictionaryError(word, context, screenPoint)
        }
    }
}
