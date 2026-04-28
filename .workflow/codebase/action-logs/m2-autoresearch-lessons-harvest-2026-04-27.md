# M2 Autoresearch Lessons Harvest - 2026-04-27

## Summary

This is a non-destructive harvest of:

- `/Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere-ar-v3-20260410-030315/autoresearch-lessons.md`

No branch merge, reset, delete, prune, or worktree removal was performed.

## Source Shape

The source file contains 11 kept lessons from `arch-v3-full-20260410-030315`, covering architecture governance, quality gates, lifecycle ownership, UI interaction proof, runtime-helper extraction, and dependency-channel decisions.

The lessons are useful as workflow/governance inputs, not as code to merge wholesale into current `main`.

## Harvested Lessons

| Lesson | Source label | Keep as | Current M2 action |
|--------|--------------|---------|-------------------|
| `L-1` | `AG-300` fact source and historical boundary docs | Documentation governance | Preserve as a Maestro rule: current fact source must be explicit before cleanup. |
| `L-2` | `QG-300` provider-neutral architecture quality gate | Quality gate pattern | Preserve as a quality-rule entry for architecture gate/failure-class reporting. |
| `L-3` | `LIFE-310` owner/register/cleanup inventory | Lifecycle governance | Preserve as an architecture constraint: managers need owner/register/cleanup ownership. |
| `L-4` | `.shared`, `NotificationCenter`, state storage rule pack | Code review standard | Preserve as a rule: new coupling must have an allowed channel and owner. |
| `L-5` | Foreground interaction coverage matrix | UI proof map | Preserve as a testing lesson: interaction work needs explicit smoke/proof coverage. |
| `L-6` | AnswerPanel pilot smoke test | UI smoke pattern | Treat as already represented in current tests; no code merge needed. |
| `L-7` | Screenshot content actions through injected dependencies | Dependency injection pattern | Preserve as an architecture reminder for content-action surfaces. |
| `L-8` | RecordingController callback wiring into runtime helpers | Runtime helper extraction | Preserve as a reusable pattern for hot-path callback assembly. |
| `L-9` | Quick Ask context assembly and callback wiring extraction | Runtime helper extraction | Preserve as a reusable pattern for testable orchestration seams. |
| `L-10` | Dependency channel matrix, state sink crosswalk, NotificationCenter allowlist | Governance matrix | Preserve as a review rule; do not reintroduce hidden channels. |
| `L-11` | Conditional Go with lifecycle-governance blocker | Release readiness framing | Preserve as a release hygiene note: green tests do not replace lifecycle ownership proof. |

## Migrated To Specs

The following spec files were updated with condensed durable rules:

- `.workflow/specs/architecture-constraints.md`
- `.workflow/specs/quality-rules.md`
- `.workflow/specs/learnings.md`

## Decision

`ISSUE-M2-004` is complete for this pass.

Do not merge the `autoresearch/arch-v3-20260410-030315` worktree code or docs wholesale. The reusable value is now represented as concise Maestro specs and this action log. Any future cleanup should still confirm whether separate user-facing docs under that worktree need archival outside the app repository.

## Validation

- Source file exists and was inspected.
- Lessons `L-1` through `L-11` were classified.
- Durable rules were migrated into `.workflow/specs/`.
- No destructive Git operations were executed.

---
*Generated during M2 non-destructive harvest on 2026-04-27.*
