# SpokenAnyWhere — New Contributor Guide

**Version**: 1.0
**Updated**: 2026-04-07
**Purpose**: The one document a new contributor reads to become productive.

---

## 1. What is This App?

SpokenAnyWhere is a **faceless macOS menu-bar app** (LSUIElement=true) that sits in the background and activates via global hotkeys. It does NOT have a main window — only:

- A **Settings** window (System Preferences-style multi-tab)
- Floating **panels** (HUD, Quick Ask answer panel, Message Panel)
- Floating **captions** (live transcription overlay)
- A **screenshot** annotation window
- A **selection toolbar** (appears near selected text)

---

## 2. Quick Start

```bash
# From spoke/ directory
cd spoke

# Build + sign + run with live logs
./dev.sh

# Build only (check for errors)
swift build

# Run tests
swift test
```

The first `dev.sh` run will request TCC permissions (microphone, screen capture, accessibility). Grant them.

---

## 3. Reading Order

Read these in order. Stop when you have enough context for your task.

| # | Doc | What You'll Learn |
|---|-----|-------------------|
| 1 | `AGENTS.md` (repo root) | Code conventions, patterns, quality gates |
| 2 | `CLAUDE.md` (repo root) | Full project overview, directory map |
| 3 | `docs/architecture/overview.md` | Architecture layers and main chains |
| 4 | `docs/architecture/quick-reference.md` | "I need to change X, where is the code?" |
| 5 | `docs/architecture/capability-graph.md` | How features connect to each other |
| 6 | `docs/architecture/core-modules.md` | Core/ module inventory |
| 7 | `docs/architecture/ui-components.md` | UI/ component inventory |

---

## 4. The Four Source Directories

```
spoke/
├── App/       → Entry point, lifecycle, menu bar (10 files)
├── Core/      → Business logic, models, providers (109 files)
├── Services/  → Global singletons, DI container (79 files)
└── UI/        → SwiftUI views, theme (65 files)
```

**Rule of thumb**:
- Adding a new feature? → `Core/` (logic) + `Services/` (singleton) + `UI/` (view)
- Fixing a bug? → Start with `quick-reference.md` to find the file
- Changing visuals? → `UI/` but ALWAYS use `DesignTokens`

---

## 5. How Things Connect

### 5.1 The Hotkey Chain

Most features activate through global hotkeys:

```
User presses hotkey
  → HotKeyService (Services/HotKeyService.swift)
    → Handler (Services/HotKey/Handlers/VoiceHandler.swift, etc.)
      → Service (RecordingController, QuickAskService, etc.)
        → Core logic (AudioRecorderService, LLMPipeline, etc.)
          → UI update (FloatingHUDManager, AnswerPanelManager, etc.)
```

### 5.2 ServiceContainer

All services are registered in `ServiceContainer` (`Services/ServiceContainer.swift`). This is a singleton DI container with lazy resolution.

**In code**: `ServiceContainer.shared.recordingController`
**In SwiftUI**: `@Environment(\.services) var services`
**In tests**: `ServiceContainer.shared.register(recordingController: mockInstance)`

### 5.3 Data Flow

```
Voice input:
  AudioRecorderService → TranscriptionManager → rawText
    → LLMPipeline (refine) → processedText
      → HistoryManager (persist)
      → ClipboardPipeline (copy to clipboard)
      → FloatingHUDManager (show result)

Quick Ask:
  QuickAskService → LLMPipeline → chat response
    → AnswerPanelManager (display)
    → TTSService (optional voice output)

Live Caption:
  LiveCaptionManager → SystemAudioCaptureService → LiveCaptionTranscriber
    → CaptionLineBuffer → CaptionStabilizer
      → TranslationService (optional translation)
      → LiveCaptionView (render)
```

---

## 6. Common Tasks

### 6.1 Add a New Hotkey Handler

1. Create handler in `Services/HotKey/Handlers/`
2. Register in `Services/HotKey/HotKeyRegistry.swift`
3. Wire callback in `Services/HotKeyService.swift`
4. Add to menu bar in `App/AppDelegate.swift`

### 6.2 Add a New UI View

1. Create view in appropriate `UI/` subdirectory
2. Use `DesignTokens.*` for ALL styling
3. Access services via `@Environment(\.services)`
4. If it's a floating panel, use `NSPanel` / `NSWindow`

### 6.3 Add a New Core Module

1. Create directory under `Core/`
2. Define state model (`*State.swift`)
3. Define service if needed (`Services/*Service.swift`)
4. Add protocol + factory in `ServiceContainer`
5. Wire live dependencies in `*LiveDependencies.swift`

### 6.4 Change a Design Token

1. Edit `UI/Theme/DesignTokens.swift`
2. That's it — all views reference tokens, not raw values

---

## 7. Key Files to Know

| File | Why It Matters |
|------|---------------|
| `App/SpokenlyApp.swift` | `@main` entry — just Settings scene |
| `App/AppDelegate.swift` | Lifecycle, startup sequence, menu bar |
| `App/AppLifecyclePlan.swift` | Explicit startup/shutdown plan |
| `Services/ServiceContainer.swift` | DI container + all service protocols |
| `Core/DataModels.swift` | SwiftData models (HistoryItem, AppRule, AIProviderConfig) |
| `UI/Theme/DesignTokens.swift` | All style tokens — colors, spacing, typography, animations |
| `Core/LLM/LLMPipeline.swift` | LLM integration (OpenAI-compatible) |
| `Core/Transcription/TranscriptionManager.swift` | ASR engine management |

---

## 8. Testing

```bash
# Run all unit tests
swift test

# Run concurrency check
bash Tests/run-concurrency-check.sh

# Check for anti-patterns
rg "\.shared\." UI/          # No direct singleton access in views
rg "NotificationCenter" App/  # Check notification usage
```

### Test Files

- Unit: `Tests/*.swift` (20 test files)
- UI: `Tests/UITests/SpokenAnyWhereUITests.swift`
- Identifiers: `Core/Testing/UITestIdentifiers.swift`

### Mocking Pattern

```swift
// In test setup:
ServiceContainer.shared.register(audioCapture: MockAudioService())

// In test body:
let result = await service.doSomething()
XCTAssertEqual(result, expected)
```

---

## 9. Things That Will Bite You

| Pitfall | What Happens | How to Avoid |
|---------|-------------|-------------|
| Hardcoded colors | Visual inconsistency, breaks dark mode | Always use `DesignTokens.Colors.*` |
| `.shared` in views | Can't test or preview in isolation | Use `@Environment(\.services)` |
| Missing TCC permission | Feature silently fails | Check Accessibility, Microphone, Screen Capture in System Settings |
| Ad-hoc signing | TCC permissions reset | Use `dev.sh` which handles dev certificate signing |
| SwiftData model changes | Crash if schema changes without migration | Test with clean data after model changes |

---

## 10. Project Data Locations

| Data | Location |
|------|----------|
| App data | `~/Library/Application Support/Spoke/Data/` |
| Audio files | `~/Library/Application Support/Spoke/Audio/` |
| Screenshots | `~/Library/Application Support/Spoke/Screenshots/` |
| API keys | Keychain (via `Core/LLM/KeychainService.swift`) |
| Settings | `AppSettings` (SwiftData + UserDefaults) |

---

*Last updated: 2026-04-07 | Generated by ccg:init*
