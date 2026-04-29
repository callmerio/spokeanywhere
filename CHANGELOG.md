# SpokenAnyWhere Changelog

Repository-maintained release history for the SpokenAnyWhere macOS app.

## Unreleased

- Changes that are not yet assigned to a release live here first.

## v0.3.0 — Wave1 Harvest (2026-04-29)

- refactor(swiftui): `.onTapGesture` → `Button` in 15+ views for accessibility
- refactor(swiftui): align text/spacing/border with `DesignTokens`
- refactor(livecaption): remove `Timer` polling, use `DispatchWorkItem`
- fix(livecaption): cancel pending work items on `NSView` teardown
- refactor(hud): inject settings action, guard height updates
- refactor(quickask): inject `WorkflowState` instead of `@State`
- fix(accessibility): render non-interactive label when filter action is nil
- docs: add subagent delegation system to `AGENTS.md`
- chore: retire legacy CCW agent framework
- 360 tests, 85 suites, 0 concurrency warnings

## v0.2.0 — Runtime Stabilization (2026-04-27)

- feat: LiveCaption collapsed focus anchor and probe diagnostics
- feat: debug simulation runtime for LiveCaption
- fix: collapsed captions scroll behavior (no re-follow)
- refactor(app): extract runtime helper seams
- fix(selection-toolbar): request accessibility permission at startup

## v0.1.0 — Initial Consolidation (pre-2026-04-27)

- Initial voice-to-text, AI processing, real-time captions
- Screenshot OCR and dictionary lookup
- Selection toolbar and clipboard pipeline
