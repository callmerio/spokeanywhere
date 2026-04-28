# AGENTS.md — SpokenAnyWhere Agent Guidelines

> Instructions for AI agents working on this codebase.
> Read this BEFORE making any code changes.

---

## 1. Project Context

SpokenAnyWhere is a native macOS productivity app (macOS 14+, Swift 5.9+). It provides voice-to-text transcription, AI text processing, real-time captions, screenshot OCR, dictionary lookup, and a selection toolbar.

**Key docs**: `CLAUDE.md` (project overview), `docs/architecture/overview.md` (architecture), `docs/architecture/quick-reference.md` (file locator).

---

## 2. Build & Verify Commands

All commands run from `spoke/` directory:

```bash
# Build (syntax + link check)
swift build

# Run unit tests
swift test

# Full dev cycle: build, sign, run with live logs
./dev.sh

# Concurrency check
bash Tests/run-concurrency-check.sh

# Search for anti-patterns
rg -n "\.shared\." App Core Services UI
rg -n "NotificationCenter\.default\.(addObserver|post)" App Core Services UI
```

**Baseline**: 150 tests / 30 suites / 0 concurrency warnings (as of 2026-03-23).

---

## 3. Code Patterns & Conventions

### 3.1 File Naming

| Suffix | Meaning |
|--------|---------|
| `*Protocol` / `*Service` | Service protocol or concrete implementation |
| `*LiveDependencies.swift` | Factory closures for real (non-test) service wiring |
| `*RuntimeHelpers.swift` | Runtime extension helpers (extracted from main source) |
| `*LiveHelpers.swift` | Live implementation helpers |
| `*Manager.swift` | Orchestrator / lifecycle manager |
| `*State.swift` | State model / state machine |
| `*View.swift` | SwiftUI view |

### 3.2 Dependency Injection

- **ServiceContainer** (`Services/ServiceContainer.swift`): Singleton DI container with lazy resolution.
- Access: `ServiceContainer.shared.xxx` or `@Environment(\.services)` in SwiftUI.
- Test injection: `ServiceContainer.shared.register(xxx: mockInstance)`.
- Live wiring: `*LiveDependencies.swift` files define factory closures.

### 3.3 Service Pattern

Every major service follows:

```swift
// 1. Protocol (Services/ServiceContainer.swift)
@MainActor protocol FooServiceProtocol: AnyObject { ... }

// 2. Concrete type (Services/FooService.swift)
@MainActor final class FooService: ObservableObject, FooServiceProtocol { ... }

// 3. Live dependencies (Services/FooServiceLiveDependencies.swift)
extension ServiceContainerDependencies {
    static let live = ServiceContainerDependencies(
        makeFoo: { FooService() }
    )
}

// 4. Runtime helpers (Services/FooServiceRuntimeHelpers.swift)
// Extracted bridge/adapter code used in production paths
```

### 3.4 SwiftData Models

All in `Core/DataModels.swift`:
- `HistoryItem` — recordings + processed text (recordType: normal/todo/done/note)
- `AppRule` — per-app custom prompts
- `AIProviderConfig` — LLM provider credentials (API key in Keychain)

### 3.5 UI Conventions

- **NSPanel/NSWindow** for floating UIs (always-on-top, click-through)
- **DesignTokens** is the ONLY source for all styling (see Section 5)
- `os.Logger` with subsystem `com.spokeanywhere`
- No direct `.shared` access in views — use `@Environment(\.services)`

---

## 4. Agent Workflows

### 4.0 Continuous Execution

Once the user has clearly authorized ongoing execution with phrases like `继续`、`go on`、`执行所有任务`、`你来推动就行`, treat that as standing approval for the current workstream.

After that authorization:

- Do not stop just to ask for routine coding approval again
- Do not turn ordinary checkpoints into confirmation gates
- Prefer completing a meaningful batch, verifying it, then reporting

Pause only when:

- the next action is destructive or difficult to reverse
- the next action would materially change agreed direction or scope
- local facts are too incomplete for a safe assumption

Also note:

- `gsd-discuss-phase` is inherently discussion-oriented and tends to ask questions by design
- If the goal is continuous execution rather than interactive clarification, prefer execution-oriented workflows or use the auto/non-interactive path

---

### 4.1 Feature Implementation

```
1. Read CLAUDE.md + relevant architecture docs
2. Find 3+ similar existing patterns (grep / Grep tool)
3. Create task with TaskCreate
4. Implement following existing patterns
5. swift build → swift test
6. Verify no regressions in concurrency check
```

### 4.2 Bug Fix

```
1. Locate bug via quick-reference.md chain
2. Read the file with the bug + its callers
3. Fix the root cause (never suppress symptoms)
4. swift build → swift test
5. Check related hot paths still work
```

### 4.3 Refactoring

```
1. Document scope in TaskCreate
2. Read all affected files
3. Change incrementally — small, compiling steps
4. swift build after each step
5. swift test after all changes
6. Verify no new .shared or NotificationCenter leaks
```

### 4.4 UI Changes

```
1. Read DesignTokens.swift FIRST
2. Check existing similar views for pattern
3. Use ONLY DesignTokens for colors, spacing, typography, corner radius, shadows
4. Access services via @Environment(\.services), never .shared
5. swift build to verify
```

---

## 5. Design Tokens (Mandatory)

**ALL UI styling MUST use `DesignTokens`**. This is non-negotiable.

```swift
// CORRECT
.foregroundColor(DesignTokens.Colors.textPrimary)
.cornerRadius(DesignTokens.CornerRadius.lg)
.font(DesignTokens.Typography.body)
.padding(DesignTokens.Spacing.md)

// FORBIDDEN
.foregroundColor(Color.white.opacity(0.9))
.cornerRadius(14)
.font(.system(size: 14))
.padding(8)
```

Available token namespaces:
- `DesignTokens.Colors` (text, background, border, interactive, accent, status, icon + `.NS` for AppKit)
- `DesignTokens.Gradients`
- `DesignTokens.CornerRadius` (xs/sm/md/lg/xl/xxl)
- `DesignTokens.Spacing` (xxs/xs/sm/md/lg/xl/xxl/xxxl)
- `DesignTokens.Typography` (titleLarge/title/body/content/button/caption/timestamp + fontSize variants)
- `DesignTokens.Animation` (fast/normal/slow/spring/springBouncy + duration variants)
- `DesignTokens.Shadow` (tight/medium/far/caption)
- `DesignTokens.Layout` (captionMaxWidth, toolbarHeight, icon sizes, blurRadius)
- `DesignTokens.BorderWidth` / `DesignTokens.LineSpacing`

Source: `spoke/UI/Theme/DesignTokens.swift`

---

## 6. Architecture Hot Paths

### 6.1 Voice Input Chain
`HotKeyService -> VoiceHandler -> RecordingController -> AudioRecorderService -> TranscriptionManager -> HistoryManager / LLMPipeline`

### 6.2 Quick Ask Chain
`HotKeyService -> QuickAskHandler -> QuickAskService -> LLMPipeline -> AnswerPanelManager`

### 6.3 Live Caption Chain
`HotKeyService -> CaptionHandler -> LiveCaptionManager -> SystemAudioCaptureService -> LiveCaptionTranscriber`

### 6.4 Screenshot Chain
`HotKeyService -> ScreenshotHandler -> ScreenshotManager -> ScreenCaptureService -> ImageEnhancementService`

### 6.5 Selection Toolbar Chain
`SelectionMonitorService -> SelectionToolbarManager -> SelectionActionService`

### 6.6 Clipboard Pipeline
`ClipboardPipelineService -> MessagePanelManager -> MessagePanelState -> SessionHistoryService`

---

## 7. Anti-Patterns to Avoid

| Anti-Pattern | Why | Do Instead |
|-------------|-----|-----------|
| Hardcoded colors/radii/fonts | Breaks design system consistency | Use `DesignTokens.*` |
| `.shared` in SwiftUI views | Prevents testability & previews | Use `@Environment(\.services)` |
| `NotificationCenter` for internal comms | Implicit coupling | Use ServiceContainer + protocols |
| `@ts-ignore` / force unwrap equivalents | Hides bugs | Handle optionals explicitly |
| Direct singleton access in new code | Initialization order fragility | Wire through ServiceContainer |
| Creating new files for trivial helpers | File bloat | Extend existing files or use `*RuntimeHelpers` |

---

## 8. Quality Gates

Before marking any task complete:

1. `swift build` — 0 errors
2. `swift test` — all pass
3. No new `.shared` in UI layer (`rg "\.shared\." UI/`)
4. No hardcoded style values in changed files
5. Backward compatibility preserved

---

## 9. Testing Conventions

- Unit tests in `Tests/*.swift` (excluded: `UITests/`, `test_edge_tts.swift`, `TextExtractionTests.swift`, `EdgeTTSTests.swift`, `AttachmentTests.swift`)
- UI tests in `Tests/UITests/SpokenAnyWhereUITests.swift`
- Test identifiers in `Core/Testing/UITestIdentifiers.swift`
- Use `ServiceContainer.shared.register()` for mock injection
- Concurrency check: `bash Tests/run-concurrency-check.sh`

---

---

## 10. Subagent Delegation System (MANDATORY)

> **Sisyphus is an ORCHESTRATOR, not an implementer.**  
> Your value is decomposition, delegation, and quality control. Delegating with crystal-clear prompts IS your work.

### 10.1 Delegation Decision Table

| You Want To | Delegate To | How |
|-------------|-------------|-----|
| Search code / find patterns / read files | `subagent_type="explore"` | `run_in_background=true` |
| Multi-step research / dependency analysis | `subagent_type="librarian"` or `@general` | `run_in_background=true` |
| Architecture advice / hard debugging | `subagent_type="oracle"` | `run_in_background=true` |
| Pre-planning analysis (ambiguous scope) | `subagent_type="metis"` | `run_in_background=false` |
| Plan review (quality gate) | `subagent_type="momus"` | `run_in_background=false` |
| UI / styling / animation / design | `category="visual-engineering"` | `load_skills=["frontend-ui-ux"]` |
| Hard logic / algorithm / architecture | `category="ultrabrain"` | `load_skills=["karpathy-guidelines"]` |
| Autonomous deep research + implementation | `category="deep"` | `load_skills=["karpathy-guidelines"]` |
| Single-file typo / trivial config | `category="quick"` | `load_skills=[]` |
| Documentation / prose | `category="writing"` | `load_skills=[]` |
| Image / screenshot analysis | `subagent_type="multimodal-looker"` | `run_in_background=false` |
| Swift/SwiftUI implementation | `category="deep"` or `category="ultrabrain"` | `load_skills=["moai-lang-swift","build-macos-apps"]` |
| Post-implementation review | `/review-work` skill | 5 parallel agents |

### 10.2 Trigger Phrases — Fire IMMEDIATELY

| Trigger | Agent | Background? |
|---------|-------|-------------|
| "Find where X is" / "Which file has Y" | `explore` | YES, always |
| "How does [library] work?" / "Find examples of" | `librarian` | YES, always |
| "What's the best practice for" / external lib docs | `librarian` | YES, always |
| "Design architecture for" / "How should I structure" | `oracle` | YES, for direction |
| 2+ modules involved / cross-layer pattern | `explore` (×2-3) | YES, parallel |
| Complex or ambiguous request | `metis` first, then `oracle` | Sequential |
| Debugging after 2+ failed attempts | `oracle` | YES |

### 10.3 Anti-Patterns (BLOCKING)

| Anti-Pattern | Why Wrong | Do Instead |
|-------------|-----------|------------|
| Implementing code yourself when delegation possible | Subagents produce better results with domain-tuned models | Decompose, delegate, verify |
| Sequential delegation of independent work | Wastes time | Spawn 3-5 agents in parallel |
| Vague delegation prompt (<5 lines) | Agent won't know what to do | Use 6-section prompt template |
| Polling `background_output` on running tasks | Wastes tokens, blocks process | End response, wait for `<system-reminder>` |
| Duplicating explore/librarian search yourself | Wastes tokens, may conflict | Trust delegated results |
| One commit from 3+ files | Not atomic | Split by concern/directory |
| `background_cancel(all=true)` | May cancel Oracle mid-analysis | Cancel individually by taskId |
| Delivering answer before Oracle result | May ship wrong decisions | Wait for `<system-reminder>` |

### 10.4 Delegation Prompt Template (6 Sections)

```
1. TASK: Atomic, specific goal (one action per delegation)
2. EXPECTED OUTCOME: Concrete deliverables with success criteria
3. REQUIRED TOOLS: Explicit tool whitelist
4. MUST DO: Exhaustive requirements — leave NOTHING implicit
5. MUST NOT DO: Forbidden actions — anticipate rogue behavior
6. CONTEXT: File paths, existing patterns, constraints
```

### 10.5 Available Agent Catalog (Condensed)

**Core OMO** (by `subagent_type`): `explore` (code search), `librarian` (docs/repos), `oracle` (architecture/debug), `metis` (pre-planning), `momus` (review), `multimodal-looker` (images)

**Categories** (by `category`): `visual-engineering` (UI), `ultrabrain` (hard logic), `deep` (autonomous), `artistry` (creative), `quick` (trivial), `unspecified-high`, `unspecified-low`, `writing` (docs)

**Skills** (by `load_skills`): `moai-lang-swift`, `build-macos-apps` (Swift/macOS), `karpathy-guidelines` (code quality), `git-master` (commits), `frontend-ui-ux` (design), `review-work` (5-agent QA), `agency-agent-roster` (team selection), `codex-autoresearch` (autonomous loop), `release-discipline` (versioning)

---

*Last updated: 2026-04-29 | Generated by ccg:init + Sisyphus delegation optimization*
