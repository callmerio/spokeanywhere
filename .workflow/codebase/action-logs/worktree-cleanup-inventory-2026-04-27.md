# Worktree Cleanup Inventory — 2026-04-27

## Summary

This inventory converts the prior worktree audit into concrete next actions. It is non-destructive: only `git worktree prune --dry-run` and dirty status reads were executed.

## safe-prune-candidates

These are Git admin entries reported by `git worktree prune --dry-run` because their gitdir files point to non-existent locations.

| worktree admin entry | dry-run output | next command | approval |
|----------------------|----------------|--------------|----------|
| `worktrees/spoke-main-verify-20260418-080814` | gitdir file points to non-existent location | `git worktree prune` | requires-user-approval |
| `worktrees/spoke-review-b807` | gitdir file points to non-existent location | `git worktree prune` | requires-user-approval |
| `worktrees/spoke-dirty-review-20260418-081659` | gitdir file points to non-existent location | `git worktree prune` | requires-user-approval |
| `worktrees/spoke-task3-review-iSUjtS` | gitdir file points to non-existent location | `git worktree prune` | requires-user-approval |
| `worktrees/spoke-review-b807-parent` | gitdir file points to non-existent location | `git worktree prune` | requires-user-approval |
| `worktrees/spoke-dirty-review-20260418-081631` | gitdir file points to non-existent location | `git worktree prune` | requires-user-approval |
| `worktrees/spoke-review-b5200d6.BT0VEW` | gitdir file points to non-existent location | `git worktree prune` | requires-user-approval |
| `worktrees/spokeanywhere-autoresearch` | gitdir file points to non-existent location | `git worktree prune` | requires-user-approval |

## inspect-before-prune

These worktrees/branches look likely cleanable, but still contain local untracked or modified files that must be inspected before removal.

| branch | path | dirty files | recommended action |
|--------|------|-------------|--------------------|
| `fix/screen-capture-indicator` | `/Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/.worktrees/screen-capture-indicator-fix` | `spoke/.draft.md` | Inspect `spoke/.draft.md`; branch commits are patch-equivalent by `git cherry`, so cleanup is likely after draft review. |
| `codex/nocturne-memory-governance` | `/Users/bigdan/.config/superpowers/worktrees/spokeanywhere/codex-nocturne-memory-governance` | `.gitignore`, `CLAUDE.md`, `spoke/Package.swift`, `docs/memo/2026-04-14-nocturne-memory-governance-an-v3.md`, `docs/memo/2026-04-14-nocturne-memory-governance-scorecard.md`, `docs/superpowers/plans/2026-04-14-nocturne-memory-governance-implementation.md`, `spoke/AGENTS.md` | Branch has no unique diff relative to main, but local dirty files may contain memory-governance notes; harvest docs before cleanup. |
| `spoke-swiftui-wave1` | `/Users/bigdan/.config/superpowers/worktrees/spokeanywhere/swiftui-wave1` | `spoke/App/AppDelegate.swift`, `spoke/Services/SelectionToolbarManager.swift`, `spoke/Services/SelectionToolbarRuntimeHelpers.swift`, `spoke/Tests/SelectionToolbarStartupPermissionTests.swift` | Compare SelectionToolbar startup permission changes against current main before cleanup. |
| `plan-quickask-settings-menu-polish-20260416` | `/Users/bigdan/.config/superpowers/worktrees/spokeanywhere/plan-quickask-settings-menu-polish-20260416` | `docs/superpowers/plans/2026-04-16-quickask-settings-menu-polish.md` | Harvest plan doc if it contains useful QuickAsk/settings polish decisions. |

## harvest-before-cleanup

These are stale or broad branches whose code should not be merged wholesale. Harvest documentation, tests, decisions, or patterns first.

| branch/worktree | why harvest first | what to look for |
|-----------------|------------------|------------------|
| `spoke-swiftui-wave1` | 14 unique commits, verified historically, but current main is 109 commits ahead | SwiftUI cleanup decisions, SelectionToolbar startup permission test, AppDelegate/toolbar helper patterns. |
| `plan-quickask-settings-menu-polish-20260416` | 13 unique commits, small diff, not patch-equivalent | QuickAsk settings menu polish, settings chrome decisions, answer panel opacity constants. |
| `autoresearch/control` | final queue output, dirty untracked autoresearch run folders | Final reports under `spoke/autoresearch/runs/*` and `spoke-ar/`; harvest summaries only. |
| `manual/test-010-conditional-go-review-v2` | likely final manual/autoresearch chain branch | Governance/dependency/test review outputs; avoid code merge. |
| `manual/gov-010-dependency-matrix-v2` | dependency matrix branch | Useful dependency matrix concepts; avoid code merge. |
| `manual/arch-030-quickask-injection-v2` | QuickAsk injection branch | Dependency-injection ideas already superseded or partly useful; harvest only. |
| `manual/arch-020-messagepanel-injection-v2` | MessagePanel injection branch | MessagePanel injection ideas; harvest only. |
| `manual/arch-010-screenshot-facade-v3` | screenshot facade branch | Screenshot facade ideas; harvest only. |
| `autoresearch/arch-v3-20260410-030315` | architecture input snapshot, many dirty files | Architecture v3 notes; harvest docs only. |

## keep-for-now

These should remain until current `main` is committed and Phase 1 validations are complete.

| item | reason |
|------|--------|
| main worktree at `/Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere` | Active integration surface; still dirty by design. |
| `.workflow/` Maestro docs | Current workflow state and plan artifacts. |
| `docs/superpowers/` current April 2026 docs | Feature history and handoff source for current roadmap. |
| `ROADMAP.md` / `ROADMAP.detail.md` | Product positioning source for Maestro roadmap. |

## commands-for-later

Do not run these until explicitly approved:

```bash
# Safe admin cleanup after review
git worktree prune --dry-run
git worktree prune

# Worktree removal examples after harvest/approval
git worktree remove <path>
git branch -d <branch>
```

## requires-user-approval

All destructive actions require explicit user approval:

- `git worktree prune`
- `git worktree remove <path>`
- `git branch -d <branch>`
- deleting dirty/untracked files inside old worktrees
- staging legacy `.agent` / `.workflow/.ccw-session` deletions as a cleanup commit

---
*Generated by TASK-006 from PLN-001 on 2026-04-27 using `git worktree prune --dry-run` and targeted dirty worktree status checks.*
