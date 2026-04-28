# Project: SpokenAnyWhere

## What This Is

SpokenAnyWhere is a native macOS productivity application for creators and knowledge workers. It provides voice-to-text transcription, AI-powered text processing, real-time captions, screenshot OCR, and selection-based workflows in a SwiftUI/AppKit hybrid app.

## Core Value

A reliable local-first capture-to-text pipeline that lets users turn speech, screen content, and selected text into useful processed text anywhere on macOS.

## Requirements

### Validated

- [x] Native macOS app shell with service-oriented runtime wiring
- [x] Voice recording and transcription workflow baseline
- [x] Quick Ask, live captions, screenshot OCR, and selection toolbar feature areas

### Active

- [ ] Reach Swift strict-concurrency readiness with no high-priority warnings
- [ ] Harden local and CI verification workflows
- [ ] Preserve reliability across recording, caption, screenshot, and panel lifecycles

### Out of Scope

- Major UI redesigns — current phase focuses on reliability and structural quality
- New public API/product features — avoid scope expansion while quality gates are being hardened

## Context

The codebase is an existing native macOS app using Swift Package Manager and Swift Bundler. Current project notes emphasize M2 convergence: concurrency safety, sanitizer paths, and stable verification.

Current development progress is tracked in `.workflow/codebase/action-logs/development-progress-2026-04-27.md`. As of 2026-04-27, local `main` is 11 commits ahead of `origin/main` with committed Live Caption collapsed-focus stabilization work, plus a large uncommitted batch spanning runtime helpers, Live Caption debug simulation, pinned text/screenshot integration, tests, roadmap updates, and Maestro workflow docs.

Current initiative framing is tracked in `.workflow/codebase/action-logs/development-initiative-2026-04-27.md`. It treats legacy `.agent` / CCW files as retired execution framework material, while preserving their reusable decisions, risk notes, and implementation plans by migrating them into Maestro-readable action logs/specs.

## Constraints

- **Platform**: macOS 14.0+ native SwiftUI/AppKit app — App Store compliance and TCC permissions matter
- **Language**: Swift 5.9+ targeting Swift strict-concurrency readiness — concurrency warnings are quality blockers
- **Privacy**: Local-first processing with explicit consent for remote AI — user content may include audio, screen, and selected text
- **Quality**: Build, tests, and concurrency checks are required before shipping meaningful changes

## Tech Stack

- **Language**: Swift 5.9+
- **Framework**: SwiftUI + AppKit hybrid
- **Database**: SwiftData

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Use native macOS SwiftUI/AppKit architecture | Required for global hotkeys, floating panels, TCC-protected capture, and menu-bar behavior | Active |
| Keep DesignTokens as UI styling source of truth | Prevents styling drift across SwiftUI surfaces | Active |
| Verify sanitizers in CI when local macOS policy blocks them | Local SIP/Hardened Runtime can block sanitizer loading | Active |

## Stakeholders

- Product owner/developer
- macOS creators and knowledge workers

---
*Last updated: 2026-04-27 after initialization*
