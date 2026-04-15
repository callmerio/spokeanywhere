---
status: resolved
trigger: "Investigate issue: pinned-text-hover-glow-regression. PinnedText/DesktopText hover glow still looks wrong compared with normal screenshot pin glow; use UI/Screenshot/ScreenshotContentView.swift as the reference solution."
created: 2026-04-15T14:33:11Z
updated: 2026-04-15T14:49:00Z
---

## Current Focus
<!-- OVERWRITE on each update - reflects NOW -->

hypothesis: Fixed and visually confirmed by the user in the real hover workflow.
test: User compared a hovered PinnedText/DesktopText item against a normal screenshot pin in the app.
expecting: PinnedText hover glow matches the screenshot pin style: soft rounded stroke/shadow glow, no filled block, no clipped hard edge.
next_action: none

## Symptoms
<!-- Written during gathering, then IMMUTABLE -->

expected: Text-to-image/PinnedText hover glow should visually match the normal screenshot pin glow style: soft gradient, no block-like rectangular boundary, no visible window/card frame, no harsh edge. The normal screenshot implementation in `UI/Screenshot/ScreenshotContentView.swift` is considered the correct reference.
actual: PinnedText hover glow remains visibly bounded / block-like around the card. Earlier pure shadow-only attempt removed visible gradient entirely. Current filled shadow-source attempt still does not visually match the screenshot pin glow.
errors: No runtime errors. This is a visual rendering defect.
reproduction: Launch the app, create or show a PinnedText / DesktopText item from text-to-image / clipboard text, hover it. Compare to a normal pinned screenshot item: screenshot pin has acceptable glow; PinnedText hover glow has visible block/boundary.
started: Started during attempts to optimize PinnedText card shadow/glow after user reported constant shadow/window-frame appearance. Baseline screenshot pin was already correct.

## Eliminated
<!-- APPEND only - prevents re-investigating -->

## Evidence
<!-- APPEND only - facts discovered -->

- timestamp: 2026-04-15T14:33:11Z
  checked: Mandatory initial files
  found: Fully read `UI/Screenshot/ScreenshotContentView.swift`, `UI/Screenshot/ScreenshotWindow.swift`, `UI/DesktopText/PinnedTextContentView.swift`, `UI/DesktopText/PinnedTextWindow.swift`, `UI/Theme/DesignTokens.swift`, `Tests/PinnedTextWindowStateTests.swift`, and `Package.swift`.
  implication: Investigation can compare the known-good screenshot glow path against the current PinnedText implementation without guessing.

- timestamp: 2026-04-15T14:35:05Z
  checked: Nocturne memory, `.planning/debug/knowledge-base.md`, and ace-tool semantic search
  found: No debug knowledge base exists and Nocturne memory had no direct project-specific match. Semantic search located the relevant contrast: screenshot glow uses `strokeColor`, `lineWidth`, `shadowColor`, `shadowRadius`, and transparent fill; PinnedText `applyGlow` sets `fillColor = color.withAlphaComponent(style.fillOpacity)` and clears stroke.
  implication: Known-pattern shortcut is unavailable; first concrete hypothesis should test the PinnedText-specific filled shadow source and token divergence against screenshot reference semantics.

- timestamp: 2026-04-15T14:36:30Z
  checked: Common bug patterns, debug thinking model reference, exact padding references, and git status
  found: Visual symptom maps best to a boundary/layout mismatch rather than null/async/state categories. Exact references show screenshot uses `ScreenshotContentView.paddingPerSide = 30`, while PinnedText uses `PinnedTextMarkdownRenderer.windowGlowPadding = 14`; tests currently assert tighter PinnedText glow, filled glow source, and `windowGlowPadding == 14`. Worktree is dirty with many unrelated/user changes, so edits must be surgical.
  implication: The first falsifiable hypothesis is that PinnedText's divergence from screenshot reference semantics is the defect, not a missing runtime event.

- timestamp: 2026-04-15T14:38:10Z
  checked: `PinnedTextMarkdownRenderer.swift`, `Tests/PinnedTextModelTests.swift`, and tracked diff for reference/token files
  found: PinnedText preferred window sizing adds `windowGlowPadding * 2`, currently 14pt per side. `PinnedTextModelTests` explicitly asserts 14pt. Tracked diff shows current screenshot reference was already tokenized to `DesignTokens.Glow.ScreenshotCard`; PinnedText-specific tokens were added separately with filled source semantics.
  implication: The minimal fix should reuse the screenshot glow token semantics for PinnedText and adjust PinnedText padding/tests accordingly, without modifying screenshot behavior.

- timestamp: 2026-04-15T14:41:00Z
  checked: Regression tests
  found: Updated PinnedText tests to require ScreenshotCard-equivalent glow tokens, transparent fill with stroked shadow source at runtime, and `windowGlowPadding == ScreenshotContentView.paddingPerSide`.
  implication: Running the targeted test suite should now fail on the current implementation if the hypothesis is correct.

- timestamp: 2026-04-15T14:42:30Z
  checked: Targeted failing test run
  found: `swift test --filter 'PinnedText|AppPinnedTextRuntime'` failed exactly on PinnedText glow/padding assertions: current padding is 14 vs screenshot 30; PinnedText hover/mark/idle tokens differ from ScreenshotCard; runtime hover layer has fill alpha 1, nil stroke, lineWidth 0, shadowRadius 14, shadowOpacity 0.34 instead of screenshot hover style.
  implication: Root cause is confirmed with direct test evidence; proceed to minimal fix.

- timestamp: 2026-04-15T14:45:10Z
  checked: Targeted fixed test run
  found: `swift test --filter 'PinnedText|AppPinnedTextRuntime'` passed with 14 tests in 3 suites after the fix.
  implication: The direct regression checks for screenshot-reference PinnedText glow semantics now pass; proceed to full suite.

- timestamp: 2026-04-15T14:46:00Z
  checked: Full test suite
  found: `swift test` passed with 237 tests in 63 suites; the XCTest wrapper also passed with 6 AX smoke tests skipped because `ENABLE_AX_SMOKE_TESTS=1` was not set.
  implication: No broad test regression from the PinnedText glow/padding fix; proceed to concurrency check.

- timestamp: 2026-04-15T14:47:10Z
  checked: Strict concurrency build
  found: `bash Tests/run-concurrency-check.sh` passed with 0 warnings.
  implication: Automated verification is complete; visual confirmation is still needed because the reported defect is a hover rendering issue.

- timestamp: 2026-04-15T14:49:00Z
  checked: Human visual verification
  found: User confirmed the real app hover workflow passed and said this repair process is the correct one to remember.
  implication: Debug session can be marked resolved; the project-specific lesson should be retained for future PinnedText/DesktopText glow work.

## Resolution
<!-- OVERWRITE as understanding evolves -->

root_cause: PinnedText hover glow was implemented with a PinnedText-specific filled CAShapeLayer shadow source and only 14pt of window padding. The screenshot reference uses a transparent fill, visible rounded stroke as the shadow source, ScreenshotCard glow token values, and 30pt padding; PinnedText's divergence made the glow appear block-like/clipped instead of matching the screenshot pin.
fix: PinnedText glow tokens now alias the ScreenshotCard glow tokens; PinnedText runtime glow now applies transparent fill plus separate stroke/shadow colors like ScreenshotContentView; PinnedText window glow padding now follows `ScreenshotContentView.paddingPerSide`.
verification: `swift test --filter 'PinnedText|AppPinnedTextRuntime'` passed with 14 tests in 3 suites; `swift test` passed with 237 tests in 63 suites and 6 AX smoke tests skipped by configuration; `bash Tests/run-concurrency-check.sh` passed with 0 warnings. User confirmed the original hover workflow is fixed in the real app.
files_changed: ["UI/Theme/DesignTokens.swift", "UI/DesktopText/PinnedTextMarkdownRenderer.swift", "UI/DesktopText/PinnedTextContentView.swift", "Tests/PinnedTextWindowStateTests.swift", "Tests/PinnedTextModelTests.swift"]
