# Roadmap: SpokenAnyWhere Maestro Execution

## Overview

SpokenAnyWhere is converging from a collection of strong desktop capture and AI utilities into a desktop context workflow layer. The current execution focus is to stabilize overlay-like runtime surfaces, preserve the Live Caption collapsed-focus fixes already committed locally, and consolidate legacy planning materials into Maestro so future sessions can load the project state quickly.

## Phases

- [ ] **Phase 1: Stabilize Desktop Overlay Runtime** — finish and validate the current overlay/runtime engineering batch without expanding product scope.
- [ ] **Phase 2: Consolidate Workflow Documentation and Release Hygiene** — migrate useful legacy CCW/superpowers knowledge into Maestro, retire obsolete workflow artifacts safely, and prepare the tree for clean commits/release gates.

## Phase Details

### Phase 1: Stabilize Desktop Overlay Runtime

**Goal**: Make Live Caption, PinnedText, Screenshot overlays, debug simulation, and runtime helper seams reliable enough to review and commit as coherent engineering slices.

**Depends on**: Existing local worktree changes and the 11 committed Live Caption collapsed-focus commits after `origin/main`.

**Requirements**:

- Preserve the existing native macOS SwiftUI/AppKit architecture and ServiceContainer dependency pattern.
- Keep UI styling within existing design-token conventions.
- Avoid new product surface expansion while reliability and validation are still open.
- Keep debug simulation behavior isolated from normal user runtime.

**Success Criteria**:

1. Live Caption collapsed mode keeps the newest Chinese translation visible in long-translation scenarios without regressing manual history scrolling semantics.
2. Live Caption debug simulation can be triggered intentionally and does not affect normal app launches.
3. App runtime helper seams around lifecycle, pinned text, screenshot, and debug automation have focused tests.
4. PinnedText and Screenshot overlay changes preserve existing interaction contracts.
5. Narrow validation passes from `spoke/`:
   - `swift build`
   - `swift test --filter LiveCaption`
   - `swift test --filter AppLifecyclePlanTests`
   - `swift test --filter AppRuntimeHelpersTests`
   - `swift test --filter CaptionLineBufferTests`

**Candidate Workstreams**:

| Workstream | Files / Areas | Notes |
|------------|---------------|-------|
| Live Caption collapsed focus | `spoke/Core/LiveCaption/`, `spoke/UI/LiveCaption/`, `spoke/Tests/*LiveCaption*` | Highest risk; visual behavior needs manual verification. |
| Debug simulation runtime | `LiveCaptionDebugSimulationRuntimeHelpers.swift`, `spoke/scripts/debug/livecaption-mock-stream.sh` | Check release safety and normal runtime isolation. |
| App runtime helper seams | `spoke/App/App*Runtime*.swift`, `AppLifecyclePlan`, runtime tests | Keep extraction small; avoid AppDelegate expansion. |
| Overlay integration | `PinnedTextManager`, `ScreenshotManager`, related live dependencies | Preserve current overlay interactions. |

### Phase 2: Consolidate Workflow Documentation and Release Hygiene

**Goal**: Turn the current mixed worktree into clean Maestro-readable project state and reviewable commit groups.

**Depends on**: Phase 1 engineering validation or explicit decision to split documentation cleanup first.

**Requirements**:

- Treat `.agent` and CCW as retired execution framework material, not active workflow state.
- Preserve useful CCW decisions, risk notes, and plans in Maestro-readable action logs/spec/spec entries before final cleanup.
- Keep `docs/superpowers/` as feature history unless deliberately migrated elsewhere.
- Do not mix code behavior changes with workflow cleanup commits.

**Success Criteria**:

1. Maestro docs contain current project definition, codebase map, progress snapshot, initiative brief, and this roadmap.
2. Useful legacy CCW knowledge is migrated or explicitly referenced before old framework files are removed.
3. Working tree is split into reviewable groups:
   - Maestro workflow docs
   - roadmap/product docs
   - Live Caption runtime/debug/test changes
   - App lifecycle/runtime helper changes
   - legacy framework cleanup
4. Full validation passes before release/tag decisions:
   - `swift test --parallel`
   - `bash Tests/run-concurrency-check.sh`
   - `./dev.sh`
5. Cleanup commit, if made, clearly states that legacy CCW framework files were retired after migration to Maestro docs.

**Candidate Workstreams**:

| Workstream | Files / Areas | Notes |
|------------|---------------|-------|
| Maestro workflow docs | `.workflow/project.md`, `.workflow/state.json`, `.workflow/config.json`, `.workflow/codebase/`, `.workflow/specs/` | First commit candidate. |
| Product roadmap docs | `ROADMAP.md`, `ROADMAP.detail.md`, `.draft.md`, roadmap backups | Decide which backups should remain. |
| Legacy CCW cleanup | `.agent/`, `.workflow/.ccw-session/`, `.workflow/.lite-fix/`, `.tldr`, Excalidraw/demo docs | Cleanup only after migration confidence. |
| Release hygiene | changelog/version/tag discipline | Build on release discipline docs from 2026-04-20. |

## Scope Decisions

- **In scope**: Runtime stabilization, validation, Maestro documentation, legacy knowledge migration, cleanup planning, commit boundary definition.
- **Deferred**: New major UI redesign, new external API integrations, large plugin systems, broad model-provider expansion.
- **Out of scope**: Reintroducing CCW as an active workflow framework; merging PinnedText and Screenshot into a single implementation; accepting overlay behavior purely from tests without manual visual verification.

## Progress

| Phase | Status | Completed |
|-------|--------|-----------|
| 1. Stabilize Desktop Overlay Runtime | Completed | TASK-001 through TASK-006 completed; LiveCaption, CaptionLineBuffer, AppLifecyclePlan, AppRuntimeHelpers tests and swift build passed |
| 2. Consolidate Workflow Documentation and Release Hygiene | In progress | Maestro init, codebase map, harvest reports, cleanup readiness, wave1 classification, and staging plan generated |

## Loading Order for Future Sessions

1. `.workflow/project.md`
2. `.workflow/roadmap.md`
3. `.workflow/codebase/action-logs/development-progress-2026-04-27.md`
4. `.workflow/codebase/action-logs/development-initiative-2026-04-27.md`
5. `.workflow/codebase/features.md`
6. `.workflow/codebase/architecture.md`
7. `ROADMAP.md` and `ROADMAP.detail.md`

---
*Generated on 2026-04-27 from Maestro project docs, Git/worktree progress snapshot, initiative brief, and current roadmap context.*
