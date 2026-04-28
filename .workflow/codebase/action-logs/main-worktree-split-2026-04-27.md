# Main Worktree Split — 2026-04-27

## Purpose

Classify every current dirty `main` worktree path into exactly one execution/commit group or an explicit hold list before validation, staging, cleanup, merge, or worktree pruning.

## Recommended Group Order

1. `maestro-workflow-docs` — safe documentation/state foundation for the new Maestro workflow.
2. `product-roadmap-docs` — product roadmap and superpowers history references.
3. `live-caption-runtime-debug-tests` — highest-risk runtime behavior slice.
4. `app-runtime-helper-seams` — AppDelegate/lifecycle/runtime helper extraction slice.
5. `legacy-ccw-cleanup` — old CCW/.agent framework retirement, only after migration confidence.
6. `Hold / Do Not Stage Yet` — ambiguous backups, drafts, demos, binary-ish diagrams, and deletions that still need explicit retention decision.

## Classification Table

| path | git_status | group | reason | commit_candidate | validation_required |
|------|------------|-------|--------|------------------|---------------------|
| `.workflow/codebase/action-logs/development-initiative-2026-04-27.md` | ?? | maestro-workflow-docs | Initiative context generated for Maestro loading | `chore(maestro): initialize workflow docs and codebase map` | `test -f` |
| `.workflow/codebase/action-logs/development-progress-2026-04-27.md` | ?? | maestro-workflow-docs | Git-derived progress snapshot | `chore(maestro): initialize workflow docs and codebase map` | `test -f` |
| `.workflow/codebase/action-logs/worktree-audit-2026-04-27.md` | ?? | maestro-workflow-docs | Worktree audit artifact | `chore(maestro): initialize workflow docs and codebase map` | `test -f` |
| `.workflow/codebase/architecture.md` | ?? | maestro-workflow-docs | Codebase map output | `chore(maestro): initialize workflow docs and codebase map` | `test -f` |
| `.workflow/codebase/concerns.md` | ?? | maestro-workflow-docs | Codebase map output | `chore(maestro): initialize workflow docs and codebase map` | `test -f` |
| `.workflow/codebase/doc-index.json` | ?? | maestro-workflow-docs | Codebase map index | `chore(maestro): initialize workflow docs and codebase map` | `python3 -m json.tool` |
| `.workflow/codebase/feature-maps/_index.md` | ?? | maestro-workflow-docs | Feature map index | `chore(maestro): initialize workflow docs and codebase map` | `test -f` |
| `.workflow/codebase/features.md` | ?? | maestro-workflow-docs | Feature map output | `chore(maestro): initialize workflow docs and codebase map` | `test -f` |
| `.workflow/codebase/tech-registry/_index.md` | ?? | maestro-workflow-docs | Tech registry index | `chore(maestro): initialize workflow docs and codebase map` | `test -f` |
| `.workflow/codebase/tech-stack.md` | ?? | maestro-workflow-docs | Tech stack map output | `chore(maestro): initialize workflow docs and codebase map` | `test -f` |
| `.workflow/config.json` | ?? | maestro-workflow-docs | Maestro workflow config | `chore(maestro): initialize workflow docs and codebase map` | `python3 -m json.tool` |
| `.workflow/project.md` | ?? | maestro-workflow-docs | Maestro project definition | `chore(maestro): initialize workflow docs and codebase map` | `test -f` |
| `.workflow/roadmap.md` | ?? | maestro-workflow-docs | Maestro roadmap | `chore(maestro): initialize workflow docs and codebase map` | `test -f` |
| `.workflow/scratch/20260427-plan-P1-stabilize-desktop-overlay-runtime/plan.json` | ?? | maestro-workflow-docs | Phase 1 plan output | `chore(maestro): initialize workflow docs and codebase map` | `python3 -m json.tool` |
| `.workflow/scratch/20260427-plan-P1-stabilize-desktop-overlay-runtime/.task/TASK-001.json` | ?? | maestro-workflow-docs | Phase 1 task output | `chore(maestro): initialize workflow docs and codebase map` | `python3 -m json.tool` |
| `.workflow/scratch/20260427-plan-P1-stabilize-desktop-overlay-runtime/.task/TASK-002.json` | ?? | maestro-workflow-docs | Phase 1 task output | `chore(maestro): initialize workflow docs and codebase map` | `python3 -m json.tool` |
| `.workflow/scratch/20260427-plan-P1-stabilize-desktop-overlay-runtime/.task/TASK-003.json` | ?? | maestro-workflow-docs | Phase 1 task output | `chore(maestro): initialize workflow docs and codebase map` | `python3 -m json.tool` |
| `.workflow/scratch/20260427-plan-P1-stabilize-desktop-overlay-runtime/.task/TASK-004.json` | ?? | maestro-workflow-docs | Phase 1 task output | `chore(maestro): initialize workflow docs and codebase map` | `python3 -m json.tool` |
| `.workflow/scratch/20260427-plan-P1-stabilize-desktop-overlay-runtime/.task/TASK-005.json` | ?? | maestro-workflow-docs | Phase 1 task output | `chore(maestro): initialize workflow docs and codebase map` | `python3 -m json.tool` |
| `.workflow/scratch/20260427-plan-P1-stabilize-desktop-overlay-runtime/.task/TASK-006.json` | ?? | maestro-workflow-docs | Phase 1 task output | `chore(maestro): initialize workflow docs and codebase map` | `python3 -m json.tool` |
| `.workflow/specs/architecture-constraints.md` | ?? | maestro-workflow-docs | Maestro spec seed | `chore(maestro): initialize workflow docs and codebase map` | `test -f` |
| `.workflow/specs/coding-conventions.md` | ?? | maestro-workflow-docs | Maestro spec seed | `chore(maestro): initialize workflow docs and codebase map` | `test -f` |
| `.workflow/specs/debug-notes.md` | ?? | maestro-workflow-docs | Maestro spec seed | `chore(maestro): initialize workflow docs and codebase map` | `test -f` |
| `.workflow/specs/learnings.md` | ?? | maestro-workflow-docs | Maestro spec seed | `chore(maestro): initialize workflow docs and codebase map` | `test -f` |
| `.workflow/specs/quality-rules.md` | ?? | maestro-workflow-docs | Maestro spec seed | `chore(maestro): initialize workflow docs and codebase map` | `test -f` |
| `.workflow/specs/review-standards.md` | ?? | maestro-workflow-docs | Maestro spec seed | `chore(maestro): initialize workflow docs and codebase map` | `test -f` |
| `.workflow/specs/test-conventions.md` | ?? | maestro-workflow-docs | Maestro spec seed | `chore(maestro): initialize workflow docs and codebase map` | `test -f` |
| `.workflow/state.json` | ?? | maestro-workflow-docs | Maestro state with roadmap/audit/plan artifacts | `chore(maestro): initialize workflow docs and codebase map` | `python3 -m json.tool` |
| `ROADMAP.md` | M | product-roadmap-docs | Product-axis roadmap rewrite | `docs: refresh product roadmap around desktop context workflows` | `test -f` |
| `ROADMAP.detail.md` | ?? | product-roadmap-docs | Expanded product roadmap migrated from long draft | `docs: refresh product roadmap around desktop context workflows` | `test -f` |
| `docs/superpowers/plans/2026-04-19-pinned-text-hover-zoom-implementation.md` | ?? | product-roadmap-docs | Feature history reference for PinnedText | `docs: preserve superpowers feature history` | `test -f` |
| `docs/superpowers/plans/2026-04-20-overlay-unified-contract-implementation.md` | ?? | product-roadmap-docs | Feature history reference for overlay contract | `docs: preserve superpowers feature history` | `test -f` |
| `docs/superpowers/plans/2026-04-20-pinned-text-zoom-polish-implementation.md` | ?? | product-roadmap-docs | Feature history reference for PinnedText zoom polish | `docs: preserve superpowers feature history` | `test -f` |
| `docs/superpowers/plans/2026-04-21-live-caption-collapsed-visibility-anchor-implementation.md` | ?? | product-roadmap-docs | Feature history reference for Live Caption current stream | `docs: preserve superpowers feature history` | `test -f` |
| `docs/superpowers/specs/2026-04-19-pinned-text-hover-zoom-design.md` | ?? | product-roadmap-docs | Feature history reference for PinnedText | `docs: preserve superpowers feature history` | `test -f` |
| `docs/superpowers/specs/2026-04-20-overlay-unified-contract-design.md` | ?? | product-roadmap-docs | Feature history reference for overlay contract | `docs: preserve superpowers feature history` | `test -f` |
| `docs/superpowers/specs/2026-04-21-live-caption-handoff.md` | ?? | product-roadmap-docs | Handoff source for Live Caption current stream | `docs: preserve superpowers feature history` | `test -f` |
| `spoke/Core/LiveCaption/CaptionLineBuffer.swift` | M | live-caption-runtime-debug-tests | Live Caption runtime slice | `fix(live-caption): stabilize collapsed focus debug runtime` | `swift test --filter LiveCaption && swift test --filter CaptionLineBufferTests` |
| `spoke/Core/LiveCaption/LiveCaptionManager.swift` | M | live-caption-runtime-debug-tests | Live Caption manager changes | `fix(live-caption): stabilize collapsed focus debug runtime` | `swift test --filter LiveCaption` |
| `spoke/Core/LiveCaption/LiveCaptionTranscriber.swift` | M | live-caption-runtime-debug-tests | Transcriber hook changes | `fix(live-caption): stabilize collapsed focus debug runtime` | `swift test --filter LiveCaption` |
| `spoke/Core/LiveCaption/LiveCaptionDebugSimulationRuntimeHelpers.swift` | ?? | live-caption-runtime-debug-tests | New debug simulation helper | `feat(debug): add live caption debug simulation runtime` | `swift test --filter LiveCaptionDebugSimulationRuntimeHelpersTests` |
| `spoke/UI/LiveCaption/LiveCaptionCollapsedFocusRuntimeHelpers.swift` | M | live-caption-runtime-debug-tests | Collapsed focus helper changes | `fix(live-caption): stabilize collapsed focus debug runtime` | `swift test --filter LiveCaptionCollapsedFocusRuntimeHelpersTests` |
| `spoke/UI/LiveCaption/LiveCaptionView.swift` | M | live-caption-runtime-debug-tests | Live Caption view behavior | `fix(live-caption): stabilize collapsed focus debug runtime` | `swift test --filter LiveCaption` |
| `spoke/UI/LiveCaption/LiveCaptionViewState.swift` | M | live-caption-runtime-debug-tests | Live Caption view state | `fix(live-caption): stabilize collapsed focus debug runtime` | `swift test --filter LiveCaption` |
| `spoke/UI/LiveCaption/LiveCaptionWindow.swift` | M | live-caption-runtime-debug-tests | Window behavior | `fix(live-caption): stabilize collapsed focus debug runtime` | `swift test --filter LiveCaption` |
| `spoke/Tests/CaptionLineBufferTests.swift` | M | live-caption-runtime-debug-tests | Caption line buffer coverage | `fix(live-caption): stabilize collapsed focus debug runtime` | `swift test --filter CaptionLineBufferTests` |
| `spoke/Tests/LiveCaptionCollapsedFocusRuntimeHelpersTests.swift` | M | live-caption-runtime-debug-tests | Collapsed focus helper coverage | `fix(live-caption): stabilize collapsed focus debug runtime` | `swift test --filter LiveCaptionCollapsedFocusRuntimeHelpersTests` |
| `spoke/Tests/LiveCaptionDebugSimulationRuntimeHelpersTests.swift` | ?? | live-caption-runtime-debug-tests | Debug simulation coverage | `feat(debug): add live caption debug simulation runtime` | `swift test --filter LiveCaptionDebugSimulationRuntimeHelpersTests` |
| `spoke/scripts/debug/livecaption-mock-stream.sh` | ?? | live-caption-runtime-debug-tests | Debug simulation script | `feat(debug): add live caption debug simulation runtime` | `bash -n spoke/scripts/debug/livecaption-mock-stream.sh` |
| `spoke/scripts/dev-run.sh` | M | live-caption-runtime-debug-tests | Debug/bootstrap dev-run changes | `feat(debug): add live caption debug simulation runtime` | `swift test --filter LiveCaption` |
| `spoke/App/AppDelegate.swift` | M | app-runtime-helper-seams | App runtime/lifecycle wiring | `refactor(app): extract runtime helper seams` | `swift test --filter AppLifecyclePlanTests && swift test --filter AppRuntimeHelpersTests` |
| `spoke/App/AppDelegateLiveDependencies.swift` | M | app-runtime-helper-seams | Live dependency seam | `refactor(app): extract runtime helper seams` | `swift test --filter AppRuntimeHelpersTests` |
| `spoke/App/AppLifecyclePlan.swift` | M | app-runtime-helper-seams | Lifecycle plan changes | `refactor(app): extract runtime helper seams` | `swift test --filter AppLifecyclePlanTests` |
| `spoke/App/AppPinnedTextRuntime.swift` | M | app-runtime-helper-seams | PinnedText runtime seam | `refactor(app): extract runtime helper seams` | `swift test --filter AppRuntimeHelpersTests` |
| `spoke/App/AppRuntimeHelpers.swift` | M | app-runtime-helper-seams | Runtime helpers | `refactor(app): extract runtime helper seams` | `swift test --filter AppRuntimeHelpersTests` |
| `spoke/App/AppScreenshotRuntime.swift` | M | app-runtime-helper-seams | Screenshot runtime seam | `refactor(app): extract runtime helper seams` | `swift test --filter AppRuntimeHelpersTests` |
| `spoke/Core/Debug/DebugAutomationTriggerService.swift` | M | app-runtime-helper-seams | Debug automation seam used by app runtime | `refactor(app): extract runtime helper seams` | `swift test --filter AppRuntimeHelpersTests` |
| `spoke/Tests/AppLifecyclePlanTests.swift` | M | app-runtime-helper-seams | Lifecycle test coverage | `refactor(app): extract runtime helper seams` | `swift test --filter AppLifecyclePlanTests` |
| `spoke/Tests/AppRuntimeHelpersTests.swift` | ?? | app-runtime-helper-seams | Runtime helper test coverage | `refactor(app): extract runtime helper seams` | `swift test --filter AppRuntimeHelpersTests` |
| `spoke/Core/DesktopText/PinnedTextManager.swift` | M | app-runtime-helper-seams | Runtime integration for PinnedText; validate with app/overlay slice | `refactor(app): extract runtime helper seams` | `swift build` |
| `spoke/Core/DesktopText/PinnedTextManagerLiveDependencies.swift` | M | app-runtime-helper-seams | PinnedText live dependency seam | `refactor(app): extract runtime helper seams` | `swift build` |
| `spoke/Core/Screenshot/ScreenshotManager.swift` | M | app-runtime-helper-seams | Screenshot runtime integration | `refactor(app): extract runtime helper seams` | `swift build` |
| `.agent/README.md` | D | legacy-ccw-cleanup | Old CCW framework retired after migration | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/rules/ccw-dispatcher.md` | D | legacy-ccw-cleanup | Old CCW dispatcher retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/rules/conductor-architect.md` | D | legacy-ccw-cleanup | Old role rule retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/rules/conductor-auditor.md` | D | legacy-ccw-cleanup | Old role rule retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/rules/conductor-coder.md` | D | legacy-ccw-cleanup | Old role rule retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/rules/conductor-workflow-rules.md` | D | legacy-ccw-cleanup | Old workflow rules retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/rules/role-data-architect.md` | D | legacy-ccw-cleanup | Old generated role retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/rules/role-model-codex.md` | D | legacy-ccw-cleanup | Old generated role retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/rules/role-model-gemini.md` | D | legacy-ccw-cleanup | Old generated role retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/rules/role-model-qwen.md` | D | legacy-ccw-cleanup | Old generated role retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/rules/role-product-manager.md` | D | legacy-ccw-cleanup | Old generated role retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/rules/role-scrum-master.md` | D | legacy-ccw-cleanup | Old generated role retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/rules/role-system-architect.md` | D | legacy-ccw-cleanup | Old generated role retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/rules/role-test-strategist.md` | D | legacy-ccw-cleanup | Old generated role retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/rules/role-ui-designer.md` | D | legacy-ccw-cleanup | Old generated role retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/rules/role-ux-expert.md` | D | legacy-ccw-cleanup | Old generated role retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/schemas/context-package.json` | D | legacy-ccw-cleanup | Old CCW schema retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/schemas/plan.json` | D | legacy-ccw-cleanup | Old CCW schema retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/templates/tech-stacks/go-dev.md` | D | legacy-ccw-cleanup | Generic old template retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/templates/tech-stacks/python-dev.md` | D | legacy-ccw-cleanup | Generic old template retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/templates/tech-stacks/react-dev.md` | D | legacy-ccw-cleanup | Generic old template retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/templates/tech-stacks/typescript-dev.md` | D | legacy-ccw-cleanup | Generic old template retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/workflows/ccw-brainstorm.md` | D | legacy-ccw-cleanup | Old CCW workflow retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/workflows/ccw-lifecycle.md` | D | legacy-ccw-cleanup | Old CCW workflow retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/workflows/ccw-lite-fix.md` | D | legacy-ccw-cleanup | Old CCW workflow retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/workflows/ccw-lite-plan.md` | D | legacy-ccw-cleanup | Old CCW workflow retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/workflows/ccw-memory.md` | D | legacy-ccw-cleanup | Old CCW workflow retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/workflows/ccw-review.md` | D | legacy-ccw-cleanup | Old CCW workflow retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/workflows/ccw-session.md` | D | legacy-ccw-cleanup | Old CCW workflow retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/workflows/ccw-tdd.md` | D | legacy-ccw-cleanup | Old CCW workflow retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/workflows/ccw.md` | D | legacy-ccw-cleanup | Old CCW workflow retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/workflows/conductor-implement.md` | D | legacy-ccw-cleanup | Old conductor workflow retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/workflows/conductor-new.md` | D | legacy-ccw-cleanup | Old conductor workflow retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/workflows/conductor-revert.md` | D | legacy-ccw-cleanup | Old conductor workflow retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/workflows/conductor-setup.md` | D | legacy-ccw-cleanup | Old conductor workflow retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/workflows/conductor-status.md` | D | legacy-ccw-cleanup | Old conductor workflow retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.agent/workflows/swift-macos.md` | D | legacy-ccw-cleanup | Old workflow retired | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.workflow/.ccw-session/IMPL_PLAN.md` | D | legacy-ccw-cleanup | CCW plan migrated into initiative brief | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.workflow/.ccw-session/context-package.json` | D | legacy-ccw-cleanup | CCW context migrated into Maestro context | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.workflow/.ccw-session/mac-app-store-risk-review.md` | D | legacy-ccw-cleanup | Risk review should be referenced before final cleanup | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.workflow/.ccw-session/review-report.md` | D | legacy-ccw-cleanup | Review findings migrated into initiative brief | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `.workflow/.lite-fix/diagnosis.md` | D | legacy-ccw-cleanup | Old diagnostic scratch migrated as historical source | `chore: retire legacy CCW agent framework` | confirm migration docs exist |
| `spoke/.planning/debug/pinned-text-hover-glow-regression.md` | D | legacy-ccw-cleanup | Old planning scratch; should be checked against superpowers docs before final cleanup | `chore: retire legacy CCW agent framework` | confirm migration docs exist |

## Hold / Do Not Stage Yet

| path | git_status | reason | next check |
|------|------------|--------|------------|
| `.draft.md` | ?? | Large draft mirror; unclear whether it should be committed or treated as scratch | inspect content purpose and decide keep/ignore/archive |
| `ROADMAP.md.bak-20260419-120926` | ?? | Backup file; usually not a source artifact | compare to ROADMAP.md before discard/archive |
| `ROADMAP.md.bak-20260419-122050` | ?? | Backup file; usually not a source artifact | compare to ROADMAP.md before discard/archive |
| `New Document.tldr` | D | Old TLDR doc deletion; value unknown | inspect git history before cleanup commit |
| `RoadMap.tldr` | D | Old TLDR doc deletion; value unknown | inspect git history before cleanup commit |
| `mindmap.excalidraw` | D | Visual planning artifact; may contain product context | inspect/export before cleanup commit |
| `ttsdemo.md` | D | Demo note deletion; may be obsolete | inspect git history before cleanup commit |

## Commit Candidate Summary

| candidate | include groups | validation |
|-----------|----------------|------------|
| `chore(maestro): initialize workflow docs and codebase map` | `maestro-workflow-docs` | JSON validation for `.workflow/**/*.json`; file existence checks |
| `docs: refresh product roadmap around desktop context workflows` | `product-roadmap-docs` excluding backups/hold | Markdown file existence and source priority review |
| `feat/debug: add live caption debug simulation runtime` | debug subset of `live-caption-runtime-debug-tests` | `swift test --filter LiveCaptionDebugSimulationRuntimeHelpersTests`; `bash -n` debug script |
| `fix(live-caption): stabilize collapsed focus debug runtime` | Live Caption runtime/test subset | `swift test --filter LiveCaption`; `swift test --filter CaptionLineBufferTests` |
| `refactor(app): extract runtime helper seams` | `app-runtime-helper-seams` | `swift test --filter AppLifecyclePlanTests`; `swift test --filter AppRuntimeHelpersTests`; `swift build` |
| `chore: retire legacy CCW agent framework` | `legacy-ccw-cleanup` after migration confidence | confirm Maestro migration docs exist; no Swift validation expected unless staged with app files |

## Next Step

Execute TASK-002 to validate and protect the Maestro planning artifacts before moving to Swift runtime validation.
