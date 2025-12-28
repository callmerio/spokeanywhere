---
mode: plan
task: SwiftLint baseline convergence
created_at: "2025-12-26T22:06:31+08:00"
complexity: complex
---

# Plan: SwiftLint baseline convergence

## Goal
- Achieve zero SwiftLint warnings by refactoring large views (SettingsView, DictionarySettingsContent, LiveCaptionView, DictionarySelectableText) without behavior changes; swift build passes.

## Scope
- In: Split large views into subviews, reduce file/function length, align DesignTokens usage, fix line length and trailing closure warnings.
- Out: Feature changes, design updates, SwiftLint rule changes.

## Assumptions / Dependencies
- SwiftLint config `.swiftlint.yml` unchanged.
- DesignTokens remains the single source of UI styling.
- Manual UI smoke check required after batch.

## Phases
1. Baseline scan, map warnings to modules, define split boundaries.
2. Refactor SettingsView.
3. Refactor DictionarySettingsContent.
4. Refactor LiveCaptionView.
5. Refactor DictionarySelectableText.
6. Cross-module cleanup and consistency pass.
7. Full verification: swiftlint + swift build + manual UI checks.

## Tests & Verification
- SwiftLint: `swiftlint --config .swiftlint.yml`
- Build: `cd spoke && swift build`
- Manual UI: open Settings / Dictionary Settings / Live Caption, verify layout and controls.

## Issue CSV
- Path: issues/2025-12-26_21-54-24-swiftlint-baseline-convergence.csv
- Must share the same timestamp/slug as this plan.

## Tools / MCP
- serena:find_symbol for structure mapping
- serena:replace_content for small edits
- serena:replace_symbol_body for extracted subviews

## Acceptance Checklist
- [ ] SwiftLint warnings = 0
- [ ] swift build passes
- [ ] Manual UI smoke check passes for the target views

## Risks / Blockers
- UI regressions from view splitting or state binding changes
- Large diffs increase merge friction

## Rollback / Recovery
- Keep changes isolated per issue; revert a single issue commit if regression appears.

## Checkpoints
- Commit after: each issue complete and verified.

## References
- spoke/UI/Settings/SettingsView.swift:10
- spoke/UI/Settings/DictionarySettingsView.swift:9
- spoke/UI/LiveCaption/LiveCaptionView.swift:402
- spoke/UI/Components/DictionarySelectableText.swift:118
