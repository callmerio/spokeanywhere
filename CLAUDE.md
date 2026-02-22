# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**SpokenAnyWhere** is a native macOS productivity app (macOS 14+) built with SwiftUI + AppKit. It provides voice-to-text transcription followed by AI-powered text processing, featuring global hotkey support, real-time captions, screenshot OCR, and a selection toolbar.

## Build & Development Commands

All commands must be run from the `spoke/` directory:

```bash
# Development (recommended) - builds, signs, and runs with live logging
cd spoke && ./dev.sh

# Build only (syntax check)
cd spoke && swift build

# Run unit tests
cd spoke && swift test

# Lint
swiftlint

# View live logs during development
tail -f .tmp_frames/dev-*.log
grep -E 'error|Error|❌' .tmp_frames/dev-*.log
```

**Important**: The app requires special TCC permissions (microphone, screen capture, accessibility). The `dev.sh` script handles proper code signing with developer certificates - ad-hoc signing breaks TCC permissions.

## Architecture

### Directory Structure

```
spoke/                    # Main source code
├── App/                  # Entry point (SpokenlyApp.swift, AppDelegate.swift)
├── Core/                 # Business logic by feature domain
│   ├── Audio/            # Audio capture and processing
│   ├── LLM/              # LLM API integrations (Gemini, etc.)
│   ├── Transcription/    # ASR engines (Apple STT, Whisper)
│   ├── Screenshot/       # Screenshot capture and OCR
│   └── LiveCaption/      # Real-time audio captioning
├── Services/             # Global singleton services
│   ├── AppSettings.swift # User preferences (SwiftData)
│   ├── HotKeyService.swift # Global hotkey handling
│   ├── QuickAskService.swift # Quick ask panel orchestration
│   └── SelectionMonitorService.swift # Text selection detection
├── UI/                   # SwiftUI views by feature
│   ├── HUD/              # Floating capsule UI
│   ├── QuickAsk/         # AI chat panel
│   ├── LiveCaption/      # Real-time caption display
│   ├── Screenshot/       # Screenshot annotation UI
│   ├── Settings/         # Preferences windows
│   └── Theme/            # DesignTokens.swift (single source of truth)
└── Resources/            # Static assets, local models
```

### Key Patterns

- **Service-Oriented Architecture**: Global singletons in `Services/` provide cross-cutting functionality
- **SwiftData** for persistence: `HistoryItem`, `AppRule`, settings
- **NSPanel/NSWindow** for floating UIs that need to stay on top or ignore clicks
- **os.Logger** for structured logging with subsystem `com.spokeanywhere`

## Styling Requirements

**Mandatory**: All UI styling must use `DesignTokens` - no hardcoded values.

```swift
// ✅ Correct
.foregroundColor(DesignTokens.Colors.textPrimary)
.cornerRadius(DesignTokens.CornerRadius.lg)

// ❌ Forbidden
.foregroundColor(Color.white.opacity(0.9))
.cornerRadius(14)
```

Reference: `spoke/UI/Theme/DesignTokens.swift` and `docs/style/INDEX.md`

## Tech Stack

- Swift 5.9+, SwiftUI + AppKit hybrid
- SwiftData for persistence
- Swift Package Manager (see `spoke/Package.swift`)
- [Swift Bundler](https://github.com/stackotter/swift-bundler) for `.app` packaging
- Frameworks: AVFoundation, Speech, ScreenCaptureKit, Vision

## Constraints

- No private APIs - must maintain App Store compliance
- Preserve backward compatibility unless explicitly approved
- Run Swift commands from `spoke/` directory
- UI must use DesignTokens exclusively

## Documentation

- `docs/prd.md` - Product requirements
- `docs/design-*.md` - Technical design documents
- `docs/style/` - Design system specification
- `docs/memo/` - Development notes and decisions
- `AGENTS.md` - Extended agent guidelines with skills system
