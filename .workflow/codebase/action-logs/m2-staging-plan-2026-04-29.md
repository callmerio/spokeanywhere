# M2 Split-Commit Staging Plan — 2026-04-29

## Pre-Flight

| Gate | Status |
|------|--------|
| `swift build` | ✅ Passed |
| `swift test` (356 tests) | ✅ Passed |
| `concurrency check` | ✅ 0 warnings |
| `.workflow/state.json` JSON | ✅ Valid |
| `.workflow/config.json` JSON | ✅ Valid |

## Commit Plan

### Commit 1: `chore(maestro): initialize workflow docs and codebase map`
**Group**: `maestro-workflow-docs`
**Files**: `.workflow/config.json`, `.workflow/state.json`, `.workflow/project.md`, `.workflow/roadmap.md`, `.workflow/codebase/**`, `.workflow/specs/**`, `.workflow/scratch/**`
**Validation**: `python3 -m json.tool` for JSON files; file existence checks
**Adds**: QuickAsk plan doc copied to `docs/superpowers/plans/`

### Commit 2: `docs: refresh product roadmap around desktop context workflows`
**Group**: `product-roadmap-docs`
**Files**: `ROADMAP.md`, `ROADMAP.detail.md`, `docs/superpowers/plans/*.md`, `docs/superpowers/specs/*.md`
**Validation**: Markdown file existence and source-priority review

### Commit 3: `fix(selection-toolbar): request accessibility permission at startup`
**Group**: `app-runtime-helper-seams` (SelectionToolbar subset)
**Files**: `AppDelegate.swift`, `SelectionToolbarRuntimeHelpers.swift`, `SelectionToolbarManager.swift`, `SelectionToolbarStartupPermissionTests.swift`
**Validation**: ✅ `swift test --filter SelectionToolbar` (6 passed)

### Commit 4: `feat(debug): add live caption debug simulation runtime`
**Group**: `live-caption-runtime-debug-tests` (debug subset)
**Files**: `LiveCaptionDebugSimulationRuntimeHelpers.swift`, `LiveCaptionDebugSimulationRuntimeHelpersTests.swift`, `spoke/scripts/debug/livecaption-mock-stream.sh`, `spoke/scripts/dev-run.sh`
**Validation**: `swift test --filter LiveCaptionDebugSimulationRuntimeHelpersTests` (passed as part of LiveCaption suite)

### Commit 5: `fix(live-caption): stabilize collapsed focus debug runtime`
**Group**: `live-caption-runtime-debug-tests` (runtime subset)
**Files**: `CaptionLineBuffer.swift`, `LiveCaptionManager.swift`, `LiveCaptionTranscriber.swift`, `LiveCaptionCollapsedFocusRuntimeHelpers.swift`, `LiveCaptionView.swift`, `LiveCaptionViewState.swift`, `LiveCaptionWindow.swift`, `CaptionLineBufferTests.swift`, `LiveCaptionCollapsedFocusRuntimeHelpersTests.swift`
**Validation**: ✅ `swift test --filter LiveCaption` (42 passed); `swift test --filter CaptionLineBufferTests` (3 passed)

### Commit 6: `refactor(app): extract runtime helper seams`
**Group**: `app-runtime-helper-seams`
**Files**: `AppDelegate.swift`, `AppDelegateLiveDependencies.swift`, `AppLifecyclePlan.swift`, `AppPinnedTextRuntime.swift`, `AppRuntimeHelpers.swift`, `AppScreenshotRuntime.swift`, `DebugAutomationTriggerService.swift`, `PinnedTextManager.swift`, `PinnedTextManagerLiveDependencies.swift`, `ScreenshotManager.swift`, `AppLifecyclePlanTests.swift`, `AppRuntimeHelpersTests.swift`
**Validation**: ✅ `swift test --filter AppLifecyclePlanTests` (6 passed); `swift test --filter AppRuntimeHelpersTests` (3 passed)

### Commit 7: `chore: retire legacy CCW agent framework`
**Group**: `legacy-ccw-cleanup`
**Files**: `.agent/**` deletions, `.workflow/.ccw-session/**` deletions, `.workflow/.lite-fix/**` deletion, `spoke/.planning/debug/pinned-text-hover-glow-regression.md` deletion
**Validation**: Maestro migration docs confirmed present; no Swift code affected

## Hold / Do Not Stage

| Path | Reason |
|------|--------|
| `.draft.md` | Undetermined purpose |
| `ROADMAP.md.bak-*` | Backup files; compare before discard |
| `New Document.tldr` | Deleted; value unknown |
| `RoadMap.tldr` | Deleted; value unknown |
| `mindmap.excalidraw` | Visual artifact; may contain context |
| `ttsdemo.md` | Deleted demo note |

## Cleanup Approval Items (Gated)

Require explicit user approval:

1. `git worktree prune` — 8 stale admin entries, safe to prune
2. `fix/screen-capture-indicator` worktree/branch removal — after `.draft.md` migrated; branch is patch-equivalent
3. `plan-quickask-settings-menu-polish-20260416` worktree/branch removal — plan doc preserved in main
4. `spoke-swiftui-wave1` — **KEEP**; 13 unharvested commits for future milestone
5. `autoresearch/arch-v3-20260410-030315` — **KEEP**; only partial harvest

---

*Generated during M2 staging plan pass on 2026-04-29.*
