# M2 spoke-swiftui-wave1 Diff Classification — 2026-04-29

## Summary

Non-destructive classification of remaining `spoke-swiftui-wave1` diffs (14 commits, 30 files, +1099/-394) against current `main`. Only the SelectionToolbar startup permission was previously harvested.

## Classification

### Already Absorbed

| Item | Notes |
|------|-------|
| SelectionToolbar startup permission | Ported in prior M2 pass. Tests pass. |

### Harvest Candidates (Grouped by Theme)

#### A. SwiftUI Accessibility Fixes — HIGH VALUE
- 7 commits converting `.onTapGesture` → `Button` for proper accessibility
- Converts views: TagBubbleView, CardAttachmentView, DictionaryPanelView, FormattedDefinitionView, DictionaryResultView, DictionarySettingsView, WorkflowPickerView, SessionHistoryListView, MessageCardView, FloatingCapsuleView
- New tests: SwiftUIButtonSemanticsTests, KeyboardShortcutHostMountingTests, DictionaryInteractionSemanticsTests
- **Effort**: Large (15+ UI files). Recommend as separate milestone harvest pass.
- **Status**: NOT absorbed. Main still uses `.onTapGesture`.

#### B. Design Tokens Alignment — MEDIUM VALUE
- 1 commit: `style(swiftui): align touched views with design tokens`
- Replaces hardcoded fonts/spacing/border with `DS.Typography`, `DS.Spacing`, `DS.BorderWidth`
- Applied to same views as Group A
- **Effort**: Medium. Requires careful comparison to avoid regressions.
- **Status**: NOT absorbed. Main has hardcoded values in many views.

#### C. LiveCaption Performance — MEDIUM VALUE
- 3 commits: preserve frame/user scroll, remove polling, scope vocabulary refresh
- Files: AppKitScrollView, LiveCaptionView, LiveCaptionRuntimeHelpers
- New tests: AppKitScrollBridgePolicyTests, LiveCaptionVocabularyRefreshTests
- **Effort**: Medium. Polling removal is the highest-value change.
- **Status**: NOT absorbed. Main still uses Timer-based polling.

#### D. HUD/Capsule Refactors — MEDIUM VALUE
- 1 commit: inject settings action, guard height updates
- Files: FloatingCapsuleView, FloatingCapsuleRuntimeHelpers, FloatingHUDManager
- New test: FloatingCapsuleViewPolishTests
- **Status**: NOT absorbed.

#### E. QuickAsk State Ownership — MEDIUM VALUE
- 2 commits: state ownership fix, attachment menu state
- Files: AnswerPanelView, AnswerPanelView+Input
- New tests: QuickAskViewStateOwnershipTests, MessageCardLayoutPolicyTests
- **Status**: NOT absorbed. Main uses `@State` for WorkflowState; wave1 uses injected.

#### F. Build Config — LOW VALUE / OBSOLETE
- 1 commit: worktree-safe excludes in Package.swift
- **Status**: Main already has its own Package.swift; this approach is different.
- **Verdict**: OBSOLETE for M2. Main's solution is sufficient.

### Obsolete / Not Worth Harvesting

| Item | Reason |
|------|--------|
| Build config (`build(package): make excludes worktree-safe`) | Main's Package.swift is already valid; worktree-safe approach is not needed for current workflow |

## Recommendation

For M2 closeout: Defer ALL wave1 harvest beyond what was already done (SelectionToolbar). The remaining 13 commits represent a significant SwiftUI modernization effort (button-based accessibility + design tokens) that should be its own milestone (M3 candidate), not squeezed into M2 release hygiene.

The wave1 worktree should remain un-deleted until:
1. A future milestone harvests Groups A-F, OR
2. An explicit decision is made that these improvements are obsolete

## Verification

- Current main swift test: all pass (SelectionToolbar, LiveCaption, CaptionLineBuffer, AppLifecyclePlan, AppRuntimeHelpers)
- wave1 has NOT been merged; this is read-only classification.

---

*Generated during M2 wave1 diff classification on 2026-04-29.*
