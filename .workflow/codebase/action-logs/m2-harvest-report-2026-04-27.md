# M2 Harvest Report — 2026-04-27

## Summary

This report performs a non-destructive harvest pass over high-value old worktrees/branches identified in the worktree cleanup inventory. No branch merge, prune, remove, reset, or deletion was performed.

## Harvest Judgement

| Source | Current finding | Judgement | Next action |
|--------|-----------------|-----------|-------------|
| `plan-quickask-settings-menu-polish-20260416` | Current main already contains `AppStatusMenuLabels`, `recordingMenuItem`, `quickAskMenuItem`, `toggleRecordingFromMenu`, `triggerQuickAskFromMenu`, and related tests. | Mostly implemented in current main. | Preserve plan as historical feature doc if desired; branch can be cleanup candidate after confirming untracked plan doc is copied/kept. |
| `fix/screen-capture-indicator` | Branch commits are patch-equivalent by `git cherry`; `.draft.md` says target was achieved with tests, concurrency check, dev launch, and manual ControlCenter sensor attribution. | Implemented and validated historically; likely safe cleanup candidate after preserving `.draft.md` conclusion. | Harvest the attribution rule into Maestro/debug notes; then branch/worktree cleanup can be approved later. |
| `spoke-swiftui-wave1` | Contains unique SwiftUI cleanup work and dirty SelectionToolbar startup-permission files. Current main already has some menu/status features, but SelectionToolbar permission prompt test may still be useful. | Needs targeted harvest, not direct merge. | Compare `SelectionToolbarStartupPermissionTests.swift` and runtime helper changes against current main before cleanup. |
| `codex/nocturne-memory-governance` | Branch has no unique diff vs main, but dirty local files include Nocturne governance docs and AGENTS/Package/CLAUDE changes. | Docs are valuable for memory governance, but not directly part of SpokenAnyWhere app code. | Preserve Nocturne docs in external memory/governance system; avoid merging app files blindly. |
| `autoresearch/control` and final manual chain | Contains broad stale docs/brainstorm/design artifacts; current main is far ahead. | Historical research only. | Harvest specific summaries/lessons, do not merge branch code. |
| `autoresearch/arch-v3-20260410-030315` | Has `autoresearch-lessons.md` and broad architecture docs. | Docs-only harvest candidate. | Inspect `autoresearch-lessons.md` later; avoid wholesale merge. |

## Specific Harvested Lessons

### Quick Ask / Status Menu Polish

Old plan goal:

- Add clickable status-menu entries for Recording and Quick Ask.
- Show shortcut hints in titles.
- Keep `AppDelegate + NSStatusItem + NSMenu` architecture.
- Add small testable label/command seams instead of redesigning menu architecture.

Current main evidence:

- `spoke/App/AppStatusMenuLabels.swift` exists.
- `spoke/Tests/AppStatusMenuLabelsTests.swift` exists.
- `spoke/Tests/AppStatusMenuCommandTests.swift` exists.
- `spoke/Tests/AppDelegateStatusMenuTests.swift` exists.
- `spoke/App/AppDelegate.swift` has `recordingMenuItem`, `quickAskMenuItem`, `toggleRecordingFromMenu`, and `triggerQuickAskFromMenu`.

Decision:

- Treat this branch as conceptually absorbed for status menu commands.
- Do not cherry-pick branch wholesale.
- If keeping docs, copy/keep `docs/superpowers/plans/2026-04-16-quickask-settings-menu-polish.md` in main docs.

### Screen Capture Indicator Fix

Old `.draft.md` records this target:

- Fix the issue where SpokenAnyWhere could be attributed by macOS as using screen content before the user actively starts Live Caption.

Recorded completed chain:

- Lazy load live caption capture services.
- Cache lazy capture services.
- Defer live caption picker activation.
- Release picker state on shutdown.
- Add lifecycle and picker completion tests.

Recorded validation:

- `swift test --filter 'LiveCaptionManagerTests|AppAudioCaptureServiceTests'`
- `swift test`
- `bash Tests/run-concurrency-check.sh`
- `LOG_DIR=/tmp/spokeanywhere-manual-uat-logs ./dev.sh`
- Manual ControlCenter attribution check confirmed SpokenAnyWhere is not attributed at cold start.

Decision:

- Branch is patch-equivalent to main by `git cherry` and can become cleanup candidate after preserving `.draft.md` conclusions.
- Keep the environment rule: when `screenpipe` is running, ControlCenter generic wording can still say screen recording is in use; final acceptance should check `ControlCenter sensor-indicators` attribution, not generic wording.

### SelectionToolbar Startup Permission

Old dirty file from `spoke-swiftui-wave1`:

- `spoke/Tests/SelectionToolbarStartupPermissionTests.swift`

Potentially valuable checks:

- Startup should call `selectionToolbarManager.start(requestPermissionIfNeeded: true)` when toolbar is enabled by default.
- Accessibility permission message should use runtime app name, e.g. `SpokenAnyWhere Dev`, not hardcoded old app name.
- Dev app path should derive display name from `SpokenAnyWhere Dev.app`.

Decision:

- This may still be useful because current main has `SelectionToolbarManager.shared.start(requestPermissionIfNeeded: true)` in `AppSettingsLiveDependencies.swift`.
- Do not merge branch wholesale.
- Add a future issue/task to compare and possibly port the test if current main lacks equivalent coverage.

### Nocturne Memory Governance

The Nocturne governance branch is not an app feature branch. Its useful content is governance policy:

- grouped canonical paths should be primary
- flat leaves are migration compatibility, not long-term dual truth
- Dream prune must not delete grouped canonical while preserving flat duplicates
- summaries are navigation layers, not sole fact sources
- destructive memory graph changes require snapshot/diff/audit

Decision:

- Valuable for memory governance, but not a SpokenAnyWhere app code merge.
- Preserve outside app workflow or in memory governance docs, not in app commit unless explicitly needed.

## Candidate Follow-Up Issues

1. `ISSUE-M2-001`: Preserve screen-capture indicator attribution lesson in Maestro debug notes.
   - Source: `.worktrees/screen-capture-indicator-fix/spoke/.draft.md`
   - Acceptance: `.workflow/specs/debug-notes.md` contains `ControlCenter sensor-indicators` and `screenpipe` attribution caveat.

2. `ISSUE-M2-002`: Compare and possibly port SelectionToolbar startup permission coverage.
   - Source: `spoke-swiftui-wave1/spoke/Tests/SelectionToolbarStartupPermissionTests.swift`
   - Acceptance: current main has a test or documented reason not to test `selectionToolbarManager.start(requestPermissionIfNeeded: true)` and runtime app name text.

3. `ISSUE-M2-003`: Preserve QuickAsk status menu polish plan as feature history or cleanup branch.
   - Source: `plan-quickask-settings-menu-polish-20260416/docs/superpowers/plans/2026-04-16-quickask-settings-menu-polish.md`
   - Acceptance: plan doc copied/kept in main docs or explicitly marked superseded in cleanup report.

4. `ISSUE-M2-004`: Inspect `autoresearch-lessons.md` from arch-v3 worktree for reusable architecture lessons.
   - Source: `/Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere-ar-v3-20260410-030315/autoresearch-lessons.md`
   - Acceptance: useful lessons migrated into Maestro action log/specs, or marked obsolete.

## Follow-Up Execution

After the initial M2 harvest report, the requested order was `2 -> 3 -> 1`:

1. Harvest `autoresearch-lessons.md`.
2. Generate cleanup readiness.
3. Compare and possibly port SelectionToolbar startup permission coverage.

Results:

- `ISSUE-M2-004` completed in `.workflow/codebase/action-logs/m2-autoresearch-lessons-harvest-2026-04-27.md`.
- Cleanup readiness completed in `.workflow/codebase/action-logs/m2-cleanup-readiness-2026-04-27.md`.
- `ISSUE-M2-002` was ported into current main:
  - `spoke/App/AppDelegate.swift`
  - `spoke/Services/SelectionToolbarRuntimeHelpers.swift`
  - `spoke/Services/SelectionToolbarManager.swift`
  - `spoke/Tests/SelectionToolbarStartupPermissionTests.swift`

SelectionToolbar validation:

- `swift test --filter SelectionToolbarStartupPermissionTests` passed.
- `swift test --filter SelectionToolbar` passed.

## Cleanup Eligibility After Harvest

| Branch/worktree | Cleanup readiness |
|-----------------|------------------|
| `fix/screen-capture-indicator` | High, after `.draft.md` lesson is migrated. |
| `plan-quickask-settings-menu-polish-20260416` | Medium-high, after untracked plan doc is preserved or marked superseded. |
| `spoke-swiftui-wave1` | Medium-low, pending SelectionToolbar startup permission comparison. |
| `codex/nocturne-memory-governance` | Medium, but should be handled as memory governance cleanup, not app cleanup. |
| `autoresearch/control` / manual chain | Medium, after final docs/lessons are harvested. |

---
*Generated during M2 non-destructive harvest on 2026-04-27.*
