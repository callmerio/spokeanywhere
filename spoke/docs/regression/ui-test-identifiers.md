# UI Test Identifiers (T002)

This document defines stable identifiers for UI automation.

## Naming Rules

- Prefix: `ui.`
- Segment style: `kebab-case`
- Structure: `ui.<feature>.<component>.<role>`
- Keep names stable across refactors; do not encode runtime state in the id.

## Identifier Source of Truth

All constants are centralized in:

- `spoke/Core/Testing/UITestIdentifiers.swift`

## Current Baseline

- `ui.hud.floating-capsule.window`
- `ui.hud.floating-capsule.root`
- `ui.live-caption.window`
- `ui.live-caption.root`
- `ui.screenshot.window`
- `ui.screenshot.content`

## Debug Automation Toggle

Debug automation listener startup is controlled by:

- `SPOKE_DEBUG_AUTOMATION`

Allowed values:

- Enabled: `1`, `true`, `yes`, `on`
- Disabled: `0`, `false`, `no`, `off`, or unset (default)

## Smoke Test

Minimal smoke test target:

- `Tests/UITests/SpokenAnyWhereUITests.swift`

Recommended command:

```bash
ENABLE_AX_SMOKE_TESTS=1 \
swift test --filter SpokenAnyWhereUITests/testLiveCaptionAccessibilityIdentifierSmoke
```

Preconditions:

- App bundle exists at `.build/bundler/SpokenAnyWhere.app`
  or provide `APP_BUNDLE_PATH=/abs/path/to/SpokenAnyWhere.app`
- The test launches the app with:
  - `SPOKE_DEBUG_AUTOMATION=1`
  - `SPOKE_SKIP_ACCESSIBILITY_ALERTS=1`
  - `SPOKE_AUDIO_WARMUP=0`
- The smoke path uses debug automation action `caption.toggle`
  to verify:
  - `ui.live-caption.window`
  - `ui.live-caption.root`

Implementation note:

- The current SwiftPM UITest target runs as a regular XCTest bundle.
- The smoke test therefore launches the app directly and verifies `AXIdentifier`
  through the macOS Accessibility tree instead of relying on `XCUIApplication`.
- To avoid permission prompts during every default `swift test`, the smoke test is
  opt-in and only runs when `ENABLE_AX_SMOKE_TESTS=1`.
