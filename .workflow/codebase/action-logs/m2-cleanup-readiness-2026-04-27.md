# M2 Cleanup Readiness Report - 2026-04-27

## Summary

This report converts the M2 harvest findings into cleanup readiness categories. It is non-destructive.

Commands used:

- `git worktree list --porcelain`
- `git worktree prune --dry-run`
- `git cherry main <branch>`
- `git diff --name-status main...<branch>`
- targeted dirty-status reads inside candidate worktrees

No `git worktree prune`, `git worktree remove`, `git branch -d`, reset, merge, or delete command was executed.

## Ready For Approval

These can be cleaned after explicit user approval because the remaining action is Git admin cleanup or an already-harvested branch/worktree.

| Item | Evidence | Required approval action |
|------|----------|--------------------------|
| Prunable admin entries under `.git/worktrees` | `git worktree prune --dry-run` reports 8 entries whose gitdir files point to non-existent locations. | `git worktree prune` |
| `fix/screen-capture-indicator` worktree | `git cherry main fix/screen-capture-indicator` reports branch commits as patch-equivalent (`-`); only dirty file is `spoke/.draft.md`; screen-capture attribution lesson was migrated to `.workflow/specs/debug-notes.md`. | Remove worktree and delete branch after approval. |

Prunable admin entries reported:

- `worktrees/spoke-main-verify-20260418-080814`
- `worktrees/spoke-review-b807`
- `worktrees/spoke-dirty-review-20260418-081659`
- `worktrees/spoke-task3-review-iSUjtS`
- `worktrees/spoke-review-b807-parent`
- `worktrees/spoke-dirty-review-20260418-081631`
- `worktrees/spoke-review-b5200d6.BT0VEW`
- `worktrees/spokeanywhere-autoresearch`

## Nearly Ready

These are likely cleanup candidates, but one non-destructive archival or explicit superseded decision should happen first.

| Item | Evidence | Remaining non-destructive step |
|------|----------|--------------------------------|
| `plan-quickask-settings-menu-polish-20260416` | Current main already has status menu / QuickAsk command coverage; branch has unique commits and an untracked plan doc. | Preserve or mark superseded `docs/superpowers/plans/2026-04-16-quickask-settings-menu-polish.md`. |
| `autoresearch/arch-v3-20260410-030315` | `autoresearch-lessons.md` was harvested into Maestro specs and action log. | Decide whether any user-facing docs outside `autoresearch-lessons.md` should be archived. |

## Not Ready For Destructive Cleanup

| Item | Reason |
|------|--------|
| `spoke-swiftui-wave1` | SelectionToolbar dirty patch was harvested into current main, but the branch still has 14 unique commits and many UI/test diffs. Do not delete until those diffs are either reviewed as obsolete or separately harvested. |
| `codex/nocturne-memory-governance` | Dirty content is memory-governance material, not SpokenAnyWhere app code. Cleanup should be handled through memory-governance workflow, not app cleanup. |
| `autoresearch/control` and nested manual/autoresearch worktrees | Broad stale research chain with many branches. M2 only harvested the arch-v3 lesson file; do not remove the whole chain from this pass. |
| main worktree | Active dirty integration surface. Do not cleanup or reset. |

## Newly Harvested During This Pass

The dirty SelectionToolbar startup permission patch from `spoke-swiftui-wave1` was ported into current main instead of merging the branch:

- `spoke/App/AppDelegate.swift`
- `spoke/Services/SelectionToolbarRuntimeHelpers.swift`
- `spoke/Services/SelectionToolbarManager.swift`
- `spoke/Tests/SelectionToolbarStartupPermissionTests.swift`

Validation:

- `swift test --filter SelectionToolbarStartupPermissionTests` passed with 4 tests.
- `swift test --filter SelectionToolbar` passed with 6 tests.

## Destructive Commands Held Back

These remain approval-gated:

```bash
git worktree prune
git worktree remove <path>
git branch -d <branch>
```

## Decision

M2 cleanup readiness is prepared, but destructive cleanup is not executed.

Recommended next cleanup order after explicit approval:

1. `git worktree prune` for stale admin entries.
2. Remove `fix/screen-capture-indicator` after confirming no need to keep `spoke/.draft.md`.
3. Archive or mark superseded the QuickAsk polish plan, then remove its worktree/branch.
4. Keep `spoke-swiftui-wave1` until its remaining UI/test diffs are separately reviewed.

---
*Generated during M2 non-destructive cleanup readiness pass on 2026-04-27.*
