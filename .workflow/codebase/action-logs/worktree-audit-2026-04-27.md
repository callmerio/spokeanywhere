# Worktree Audit — 2026-04-27

## Summary

当前 worktree 问题不是单个分支冲突，而是历史上多套开发框架并行留下的状态堆叠：`/private/tmp` 的临时 review worktree 已经失效可 prune；`superpowers/autoresearch` 下有一串很旧的 worktree 分支与当前 `main` 分叉很远；主 worktree 本身还有大量未提交变更；另有少数分支看起来已经 patch-equivalent 合入或没有独立差异。

本审计只读完成，没有执行 merge、delete、reset、prune。

## Current Main Worktree

| Field | Value |
|-------|-------|
| Path | `/Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere` |
| Branch | `main` |
| HEAD | `bff7fdb fix: stop collapsed captions from re-following document bottom` |
| Upstream | `origin/main` |
| Ahead | 11 commits |
| Status | dirty |

Main worktree status counts from `git status --short`:

- `D`: 47 tracked deletions
- `M`: 22 tracked modifications
- `??`: 21 untracked entries

Main worktree is currently the integration surface and should not be cleaned until code/docs are split into commit groups.

## Worktree Classes

### Class A — Prunable Broken Temporary Worktrees

These entries are already marked `prunable` by Git because their gitdir points to a non-existent location or the temp directory is gone.

| Path | HEAD | Exists | Recommendation |
|------|------|--------|----------------|
| `/private/tmp/spoke-dirty-review-20260418-081631` | `1c13c68` | no | prune admin entry |
| `/private/tmp/spoke-dirty-review-20260418-081659` | `1c13c68` | no | prune admin entry |
| `/private/tmp/spoke-main-verify-20260418-080814` | `1c13c68` | no | prune admin entry |
| `/private/tmp/spoke-review-b807` | `b807113` | no | prune admin entry |
| `/private/tmp/spoke-review-b807-parent` | `af7bc37` | no | prune admin entry |
| `/private/tmp/spokeanywhere-autoresearch` | `3e14e35` | no | prune admin entry |
| `/private/tmp/spoke-review-b5200d6.BT0VEW` | `b5200d6` | yes but prunable/error status | inspect only if needed, otherwise prune/remove carefully |
| `/private/tmp/spoke-task3-review-iSUjtS` | `9883d12` | yes but prunable/error status | inspect only if needed, otherwise prune/remove carefully |

Recommended command only after user approval:

```bash
git worktree prune --dry-run
git worktree prune
```

### Class B — Active Main Worktree, Needs Split Before Cleanup

Main contains the actual current integration work:

- Maestro docs and action logs
- product roadmap rewrite
- Live Caption collapsed/debug follow-up
- App runtime helper extraction
- old CCW/.agent deletions

Recommendation: split into semantic commits before any branch/worktree cleanup.

### Class C — Patch-Equivalent / No Unique Branch Diff

These branches/worktrees show no unique branch commits relative to current `main` or no diff:

| Branch | Worktree | Divergence vs main | Cherry | Status | Recommendation |
|--------|----------|--------------------|--------|--------|----------------|
| `codex/nocturne-memory-governance` | exists | `89/0` | `+0/-0` | dirty (`M:3,??:4`) | do not delete until local dirty files inspected; branch content itself appears already contained/no unique diff |
| `phase-999-2-nocturne-contextual-exception-governance` | exists | `89/0` | `+0/-0` | clean | candidate for removal after confirming no external dependency |
| `design/hig-unify` | no listed worktree | `260/0` | `+0/-0` | branch only | likely obsolete or merged-equivalent; candidate branch cleanup after confirmation |
| `fix/screen-capture-indicator` | exists | `87/9` | `+0/-9` | untracked `??:1` | patch-equivalent to main by `git cherry`; inspect untracked file, then likely safe to remove worktree/branch |

Interpretation: `git cherry` `-9` means those 9 commits appear patch-equivalent to changes already reachable from main. That branch likely finished, but its worktree still has one untracked file.

### Class D — Stale Superpowers / Autoresearch Chain

These worktrees contain unique branch commits, but they are hundreds of commits behind current `main` and have huge diffs. They should not be merged wholesale.

| Branch | Divergence vs main | Unique commits | Diff size | Status | Recommendation |
|--------|--------------------|----------------|-----------|--------|----------------|
| `autoresearch/ag-010-fact-baseline` | `238/3` | 3 | 66 files, +6986/-958 | dirty | harvest docs/ideas only; do not merge wholesale |
| `autoresearch/app-010-lifecycle-contract` | `238/5` | 5 | 72 files, +7194/-958 | dirty | harvest lifecycle contract ideas only |
| `manual/app-020-callback-cleanup` | `238/5` | 5 | 72 files, +7194/-958 | clean | likely duplicate of lifecycle-contract state; cleanup candidate after harvesting |
| `manual/app-020-callback-cleanup-v2` | `238/6` | 6 | 76 files, +7430/-988 | dirty | harvest only |
| `manual/arch-010-screenshot-facade-v2` | `238/6` | 6 | 76 files, +7430/-988 | clean | harvest only |
| `manual/arch-010-screenshot-facade-v3` | `238/7` | 7 | 77 files, +7545/-988 | dirty | harvest only |
| `manual/arch-020-messagepanel-injection-v2` | `238/8` | 8 | 80 files, +7627/-1043 | dirty | harvest only |
| `manual/arch-030-quickask-injection-v2` | `238/9` | 9 | 82 files, +7725/-1058 | dirty | harvest only |
| `manual/gov-010-dependency-matrix-v2` | `238/10` | 10 | 84 files, +7824/-1090 | dirty | harvest governance matrix ideas only |
| `manual/test-010-conditional-go-review-v2` | `238/11` | 11 | 87 files, +8016/-1092 | clean | likely final chain output; harvest first, cleanup later |
| `autoresearch/control` | `238/13` | 13 | 89 files, +8133/-1092 | dirty | queue says completed; harvest final reports only |

Interpretation: these look like a generated/autoresearch chain where each later branch integrates prior outputs. Because current `main` has 238 commits not present in those branches, merging directly would be high-risk and probably reintroduce obsolete architecture/docs/code. Treat as historical research artifacts.

### Class E — Older Feature/Polish Branches With Unique Work

These are not obviously merged and need explicit diff review before deletion.

| Branch | Divergence vs main | Unique commits | Diff size | Status | Recommendation |
|--------|--------------------|----------------|-----------|--------|----------------|
| `plan-quickask-settings-menu-polish-20260416` | `88/13` | 13 | 20 files, +821/-76 | untracked `??:1` | review diff; possibly already conceptually superseded, but not patch-equivalent |
| `spoke-swiftui-wave1` | `109/14` | 14 | 32 files, +1472/-394 | dirty (`M:3,??:1`) | important historical branch; Serena memory says it had verified cleanup state on 2026-04-09, but current main has moved on; harvest/compare before cleanup |
| `autoresearch/arch-v3-20260410-030315` | `109/1` | 1 | 5 files, +1209 | dirty (`M:12,??:31`) | likely architecture input snapshot; harvest docs only |

## Plan Completion Judgement

| Area | Evidence | Completion judgement |
|------|----------|----------------------|
| `/private/tmp` review worktrees | Git marks prunable; most paths missing | Completed/abandoned temp verification; clean with `git worktree prune` after approval |
| `fix/screen-capture-indicator` | `git cherry main branch` reports `+0/-9` | Work appears patch-equivalent to main; inspect one untracked file, then likely cleanup |
| `spoke-swiftui-wave1` | Serena memory says build/test/concurrency passed on 2026-04-09; branch still has unique commits and dirty files | Completed at the time, but not safely deletable until diff is harvested or confirmed superseded |
| autoresearch/manual chain | `autoresearch/control` commit says queue completed; final branch clean; huge stale diffs | Research chain likely completed, but outputs should be harvested, not merged wholesale |
| `plan-quickask-settings-menu-polish-20260416` | 13 unique commits, small diff, not patch-equivalent | Unknown completion; requires targeted diff review |
| nocturne governance branches | no unique branch diff; one dirty worktree | Branch content likely obsolete/contained; dirty files need inspection before cleanup |

## Recommended Cleanup Order

1. **No destructive cleanup yet**: first finish committing or shelving current `main` worktree state.
2. **Dry-run prune broken temp entries**:
   - `git worktree prune --dry-run`
   - then `git worktree prune` only after approval.
3. **Inspect dirty non-main worktrees**:
   - especially `codex/nocturne-memory-governance`, `spoke-swiftui-wave1`, `autoresearch/control`, and the dirty manual/autoresearch worktrees.
4. **Harvest before merge**:
   - for superpowers/autoresearch branches, extract docs/decisions/tests ideas into Maestro docs/specs; avoid branch merge.
5. **Review small/possibly relevant branches**:
   - `plan-quickask-settings-menu-polish-20260416`
   - `fix/screen-capture-indicator`
   - `spoke-swiftui-wave1`
6. **Remove worktrees/branches in separate cleanup commit or operator step** after the above is recorded.

## High-Risk Merge Warnings

- Do not merge the `manual/*` or `autoresearch/*` chain directly into `main`; they are too stale and too broad.
- Do not delete dirty worktrees without inspecting untracked/modified files.
- Do not combine worktree cleanup with current code changes; it will make review impossible.
- Do not rely only on branch names for completion; use `git cherry`, diff stats, and plan docs.

## Next Recommended Audit Slices

1. Generate per-worktree dirty-file inventory for dirty worktrees.
2. For `fix/screen-capture-indicator`, inspect the untracked file and confirm branch can be removed.
3. For `spoke-swiftui-wave1`, compare changed files against current main and decide whether anything remains valuable.
4. For `autoresearch/control` and final manual branches, harvest final reports/decision files into Maestro action logs or specs.

---
*Generated from `git worktree list --porcelain`, `git branch -vv --all`, `git rev-list --left-right --count`, `git cherry`, diff stats, and local plan discovery on 2026-04-27.*
