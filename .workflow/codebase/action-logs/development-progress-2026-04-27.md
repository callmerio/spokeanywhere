# Development Progress Snapshot — 2026-04-27

## Summary

Current branch is `main`. Local `HEAD` is 11 commits ahead of `origin/main`, centered on Live Caption collapsed-focus anchoring and probe diagnostics. The working tree also contains a large uncommitted batch: runtime wiring changes, Live Caption and pinned text follow-up changes, debug simulation helpers/tests, roadmap/documentation cleanup, and the new Maestro workflow initialization artifacts.

## Git Position

- Branch: `main`
- Upstream baseline: `origin/main` at `822aca6 feat: establish release discipline`
- Local ahead count: 11 commits
- Latest local commit: `bff7fdb fix: stop collapsed captions from re-following document bottom`
- Working tree: dirty, with tracked modifications/deletions and new untracked workflow/docs/test/debug files

## Recently Committed Work Since `origin/main`

The 11 committed changes form a coherent Live Caption collapsed-focus stabilization slice:

1. `b5200d6` — lock collapsed focus anchor semantics with tests
2. `427a34f` — inject probe bootstrap path in red test
3. `31994c2` — add collapsed focus anchor helpers
4. `d779134` — clamp collapsed focus scroll delta
5. `8621631` — anchor collapsed captions to latest Chinese block
6. `675a7d3` — enable collapsed focus probes in production path
7. `54b3f2d` — tighten collapsed focus pin state updates
8. `a45f7f7` — expose collapsed probe diagnostics in open flow
9. `6811fee` — align probe bootstrap lifecycle with open flow
10. `2b6c71e` — clean bootstrap files on exit
11. `bff7fdb` — stop collapsed captions from re-following document bottom

Committed files are concentrated in:

- `spoke/UI/LiveCaption/AppKitScrollView.swift`
- `spoke/UI/LiveCaption/LiveCaptionView.swift`
- `spoke/UI/LiveCaption/*RuntimeHelpers.swift`
- `spoke/Tests/*LiveCaption*Tests.swift`
- `spoke/scripts/dev-run.sh`

## Current Uncommitted Development Batch

### Runtime and App Lifecycle

- `spoke/App/AppDelegate.swift`
- `spoke/App/AppDelegateLiveDependencies.swift`
- `spoke/App/AppLifecyclePlan.swift`
- `spoke/App/AppRuntimeHelpers.swift`
- `spoke/App/AppPinnedTextRuntime.swift`
- `spoke/App/AppScreenshotRuntime.swift`

Likely theme: lifecycle/runtime helper extraction and debug automation wiring around app startup, screenshots, pinned text, and live caption flows.

### Live Caption Follow-up

- `spoke/Core/LiveCaption/CaptionLineBuffer.swift`
- `spoke/Core/LiveCaption/LiveCaptionManager.swift`
- `spoke/Core/LiveCaption/LiveCaptionTranscriber.swift`
- `spoke/UI/LiveCaption/LiveCaptionCollapsedFocusRuntimeHelpers.swift`
- `spoke/UI/LiveCaption/LiveCaptionView.swift`
- `spoke/UI/LiveCaption/LiveCaptionViewState.swift`
- `spoke/UI/LiveCaption/LiveCaptionWindow.swift`
- `spoke/Core/LiveCaption/LiveCaptionDebugSimulationRuntimeHelpers.swift` (new)

Likely theme: collapsed caption focus/visibility behavior, line-buffer state, transcriber hooks, debug simulation, and window behavior.

### Desktop Text / Screenshot / Debug

- `spoke/Core/DesktopText/PinnedTextManager.swift`
- `spoke/Core/DesktopText/PinnedTextManagerLiveDependencies.swift`
- `spoke/Core/Screenshot/ScreenshotManager.swift`
- `spoke/Core/Debug/DebugAutomationTriggerService.swift`
- `spoke/scripts/debug/livecaption-mock-stream.sh` (new)

Likely theme: pinned text and screenshot runtime integration plus debug automation support.

### Tests Added or Updated

- `spoke/Tests/AppLifecyclePlanTests.swift`
- `spoke/Tests/AppRuntimeHelpersTests.swift` (new)
- `spoke/Tests/CaptionLineBufferTests.swift`
- `spoke/Tests/LiveCaptionCollapsedFocusRuntimeHelpersTests.swift`
- `spoke/Tests/LiveCaptionDebugSimulationRuntimeHelpersTests.swift` (new)

Likely theme: locking lifecycle/runtime helper behavior, caption buffer behavior, collapsed focus behavior, and debug simulation runtime semantics.

### Documentation and Workflow Changes

- `.workflow/` was initialized for Maestro and codebase docs were generated.
- `ROADMAP.md` was rewritten toward a product-axis roadmap: desktop context layer + workflow layer, with `看屏即问` as breakout path and `跨应用流转` as long-term axis.
- `ROADMAP.detail.md`, roadmap backups, and `docs/superpowers/*` plans/specs are new/untracked.
- Old `.agent/`, `.workflow/.ccw-session/`, `.workflow/.lite-fix/`, `.tldr`, Excalidraw, and demo docs are deleted in the working tree.

## Product Progress Interpretation

The project has moved beyond baseline voice transcription into a broader desktop-context workflow product:

- Capture layer is strong: screenshot, OCR, selection, clipboard, pinned text, live caption, voice input.
- Understanding/action layer is converging: Quick Ask, Answer Panel, Message Panel, workflow actions, dictionary, translation.
- Return/persistence layer is the current strategic frontier: PinnedText, History, desktop objects, and cross-app flow.
- Current engineering focus is reliability and behavior polish for overlay-like surfaces, especially Live Caption collapsed focus and pinned text/window runtime interactions.

## Known Validation Context

Latest remembered verified state from 2026-04-09:

- `swift test` passed with 208 tests / 62 suites / 0 failures.
- `bash Tests/run-concurrency-check.sh` passed with 0 warnings.
- `./dev.sh` bundled, signed, and launched the dev app.

No fresh build/test validation was run for this 2026-04-27 snapshot. The current working tree needs validation before any commit or release decision.

## Risks and Cleanup Needs

1. Large working tree mixes product docs, Maestro workflow setup, runtime code, tests, debug tooling, and deletions. Split review/commit boundaries before shipping.
2. Deletions under `.agent/`, old `.workflow/.ccw-session/`, `.workflow/.lite-fix/`, `.tldr`, and Excalidraw files may be intentional cleanup, but should be confirmed before staging.
3. Live Caption changes touch UI state, window behavior, runtime helpers, manager/transcriber code, and tests; run focused tests plus `swift build`.
4. New debug scripts/helpers should be checked for shipping safety and App Store compliance impact.
5. Roadmap rewrite and Maestro docs are useful for loading context but should remain separate from app behavior commits if possible.

## Recommended Next Actions

1. Run narrow validation from `spoke/`:
   - `swift build`
   - `swift test --filter LiveCaption`
   - `swift test --filter AppLifecyclePlanTests`
   - `swift test --filter AppRuntimeHelpersTests`
   - `swift test --filter CaptionLineBufferTests`
2. Run full validation before commit:
   - `swift test --parallel`
   - `bash Tests/run-concurrency-check.sh`
3. Split changes into reviewable groups:
   - Maestro/workflow docs
   - roadmap/product docs
   - Live Caption runtime/debug/test changes
   - App lifecycle/runtime helper changes
   - cleanup/deletions
4. Confirm whether `.agent/` and legacy workflow scratch deletions are intended.

---
*Generated from git status/log/diff, Serena memories, `.workflow/project.md`, and codebase docs on 2026-04-27.*
