# Unified Context Pipeline Design

**Status**: proposed design  
**Date**: 2026-04-29  
**Scope**: Desktop Understanding Layer / unified context package assembly  
**Primary consumers**: `LLMPipeline`, `QuickAskService` / `QuickAskPromptAssembler`, `ClipboardPipelineService`, `MessagePanelManager`, future workflow actions

---

## 1. Overview and Motivation

SpokenAnyWhere is moving from isolated feature pipelines toward the roadmap model:

```text
Desktop Context -> [采集] -> [理解] -> [动作] -> [回流 / 沉淀]
```

Today, desktop context is assembled independently in several places:

- `LLMPipeline.buildAppContext()` builds an app/OCR string for refinement.
- `QuickAskContextAssembler.collect()` collects OCR and an optional active-window screenshot.
- `QuickAskPromptAssembler.build()` independently adds OCR, clipboard history, live caption history, and attachments to a prompt string.
- `ClipboardPipelineService` directly reads pasteboard text and pushes it into `MessagePanelManager`.
- `RecordingSessionContextAssembler` captures only recording text, audio URL, and target app metadata.

The result is duplicated source selection, inconsistent metadata, and consumers that receive strings instead of a structured understanding of what was collected. The proposed design introduces one `UnifiedContextPipeline` service that turns requested desktop sources into a typed `ContextPackage`. Prompt rendering remains a consumer concern; context collection becomes shared infrastructure.

---

## 2. Design Principles

1. **One collection boundary, many renderers**: `UnifiedContextPipeline` collects structured context; `QuickAskPromptAssembler`, `LLMPipeline`, and future renderers decide how to format it.
2. **ServiceContainer first**: consumers resolve the pipeline through injected dependencies or `@Environment(\.services)` in SwiftUI, never by adding UI-layer `.shared` calls.
3. **Direct calls for request/response**: context assembly is ordered, result-bearing work, so consumers call `collect(_:) async` directly. No new `NotificationCenter` events for context collection.
4. **Lifecycle is explicit**: the pipeline has `start()` / `stop()` and is owned by `AppDelegate` once it becomes a top-level service.
5. **Providers are small adapters**: existing services remain the source of truth; the pipeline wraps them behind context-source provider protocols instead of duplicating OCR, clipboard, caption, or pinned-text logic.
6. **Structured first, strings last**: string prompt sections are produced only at the final consumer boundary.

---

## 3. Proposed File Placement

Recommended minimal implementation layout:

```text
spoke/Core/Context/UnifiedContextPipeline.swift
spoke/Core/Context/ContextPackage.swift
spoke/Core/Context/ContextSourceProviders.swift
spoke/Core/Context/ContextPromptRendering.swift        # optional helper, not required in M1
spoke/Services/UnifiedContextPipelineLiveDependencies.swift
```

If the first implementation is small, `UnifiedContextPipeline.swift` can contain the protocol and concrete service, while `ContextPackage.swift` contains all value models. Split only when the file becomes hard to navigate.

---

## 4. Protocol Definitions

### 4.1 Main Service Interface

```swift
@MainActor
protocol UnifiedContextPipelineProtocol: AnyObject {
    var isRunning: Bool { get }

    func start()
    func stop()

    func collect(_ request: ContextRequest) async -> ContextPackage
}
```

Concrete service:

```swift
@MainActor
final class UnifiedContextPipeline: UnifiedContextPipelineProtocol {
    static let shared = UnifiedContextPipeline(dependencies: .live)

    private(set) var isRunning = false
    private let dependencies: UnifiedContextPipelineDependencies

    init(dependencies: UnifiedContextPipelineDependencies) {
        self.dependencies = dependencies
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        // No heavy capture work here. Only start owned providers if any are introduced later.
    }

    func stop() {
        guard isRunning else { return }
        dependencies.screenOCR.clearCache()
        isRunning = false
    }

    func collect(_ request: ContextRequest) async -> ContextPackage {
        // Implementation composes source providers based on request.sources.
    }
}
```

`start()` / `stop()` must be idempotent, matching `service-lifecycle-contract.md`. Runtime side effects should remain in `start()` / `stop()`, not `init()`.

### 4.2 Dependencies

```swift
@MainActor
struct UnifiedContextPipelineDependencies {
    let contextService: ContextService
    let screenOCR: ScreenOCRService
    let clipboardHistory: ClipboardHistoryService
    let liveCaptionManager: LiveCaptionManager
    let pinnedTextManager: PinnedTextManager
    let now: () -> Date
}
```

Live wiring should mirror existing `*LiveDependencies.swift` patterns:

```swift
@MainActor
extension UnifiedContextPipelineDependencies {
    static let live = UnifiedContextPipelineDependencies(
        contextService: ServiceContainer.shared.contextService,
        screenOCR: ServiceContainer.shared.screenOCR,
        clipboardHistory: ServiceContainer.shared.clipboardHistoryService,
        liveCaptionManager: ServiceContainer.shared.liveCaptionManager,
        pinnedTextManager: ServiceContainer.shared.pinnedTextManager,
        now: Date.init
    )
}
```

For final implementation, prefer injecting factories through `ServiceContainerDependencies` rather than reaching into `ServiceContainer.shared` from this dependency object if that matches the surrounding file’s style at the time of change.

### 4.3 ServiceContainer Integration

Add a protocol entry and lazy concrete service to `ServiceContainer`:

```swift
@MainActor
protocol UnifiedContextPipelineServiceProtocol: AnyObject {
    var isRunning: Bool { get }
    func start()
    func stop()
    func collect(_ request: ContextRequest) async -> ContextPackage
}
```

Then extend `ServiceContainerDependencies`:

```swift
let makeUnifiedContextPipeline: () -> UnifiedContextPipelineServiceProtocol
```

Add private storage, accessor, and test registration:

```swift
private var _unifiedContextPipeline: UnifiedContextPipelineServiceProtocol?

var unifiedContextPipeline: UnifiedContextPipelineServiceProtocol {
    resolveService(storage: &_unifiedContextPipeline, provider: dependencies.makeUnifiedContextPipeline)
}

func register(unifiedContextPipeline: UnifiedContextPipelineServiceProtocol) {
    _unifiedContextPipeline = unifiedContextPipeline
}
```

`ServiceContainerLiveDependencies.swift` wires:

```swift
makeUnifiedContextPipeline: { UnifiedContextPipeline.shared }
```

---

## 5. Request Model

```swift
struct ContextRequest: Sendable, Equatable {
    var sources: Set<DesktopContextSource>
    var limits: ContextLimits
    var purpose: ContextPurpose
    var includeImages: Bool
    var preferPrefetchedOCR: Bool

    static func quickAsk(settings: LLMSettings) -> ContextRequest
    static func llmRefinement(includeActiveApp: Bool, includeClipboard: Bool) -> ContextRequest
    static func messagePanelClipboard() -> ContextRequest
}
```

```swift
enum DesktopContextSource: String, CaseIterable, Codable, Sendable {
    case app
    case activeWindowOCR
    case activeWindowScreenshot
    case clipboardHistory
    case liveCaptionTranscript
    case pinnedText
}

enum ContextPurpose: String, Codable, Sendable {
    case quickAsk
    case llmRefinement
    case clipboardPipeline
    case messagePanel
    case recordingSession
    case workflow
}

struct ContextLimits: Sendable, Equatable {
    var ocrMaxLength: Int = 2_000
    var clipboardItemLimit: Int = 5
    var liveCaptionItemLimit: Int = 0
    var pinnedTextItemLimit: Int = 20
    var pinnedTextMaxLengthPerItem: Int = 1_000
}
```

The request should express intent, not implementation details. For example, Quick Ask asks for `.activeWindowOCR`, `.activeWindowScreenshot`, `.clipboardHistory`, and `.liveCaptionTranscript`; it should not know whether OCR came from cache, prefetch, or live capture.

---

## 6. ContextPackage Model

```swift
struct ContextPackage: Sendable {
    let id: UUID
    let purpose: ContextPurpose
    let createdAt: Date
    let sourcesRequested: Set<DesktopContextSource>
    let sourcesIncluded: Set<DesktopContextSource>
    let app: AppContextSnapshot?
    let activeWindowOCR: OCRContext?
    let activeWindowScreenshot: ScreenshotContext?
    let clipboard: ClipboardContext?
    let liveCaption: LiveCaptionContext?
    let pinnedText: PinnedTextContext?
    let metadata: ContextPackageMetadata
}
```

### 6.1 Source Models

```swift
struct AppContextSnapshot: Codable, Equatable, Sendable {
    let name: String
    let bundleIdentifier: String
}

struct OCRContext: Codable, Equatable, Sendable {
    let text: String
    let maxLength: Int
    let wasTruncated: Bool
    let source: OCRSource
}

enum OCRSource: String, Codable, Sendable {
    case prefetched
    case activeWindowCapture
    case cache
}

struct ScreenshotContext: Sendable {
    let image: CGImage
    let source: ScreenshotSource
}

enum ScreenshotSource: String, Codable, Sendable {
    case activeWindow
}

struct ClipboardContext: Codable, Equatable, Sendable {
    let items: [ClipboardContextItem]
}

struct ClipboardContextItem: Codable, Equatable, Sendable {
    let index: Int
    let text: String
    let timestamp: Date?
}

struct LiveCaptionContext: Codable, Equatable, Sendable {
    let text: String
    let itemCount: Int
    let limit: Int
}

struct PinnedTextContext: Codable, Equatable, Sendable {
    let items: [PinnedTextContextItem]
}

struct PinnedTextContextItem: Codable, Equatable, Sendable {
    let id: UUID
    let text: String
    let createdAt: Date
    let source: PinnedTextSource
    let isMarked: Bool
    let isLocked: Bool
    let screenLocalizedName: String?
}
```

`CGImage` is not `Codable`, so screenshot payloads stay runtime-only. If persistence is later required, add an image-reference model instead of forcing `ContextPackage` itself to be fully codable.

### 6.2 Metadata

```swift
struct ContextPackageMetadata: Codable, Equatable, Sendable {
    let collectionStartedAt: Date
    let collectionFinishedAt: Date
    let sourceStatuses: [DesktopContextSource: ContextSourceStatus]
    let warnings: [ContextPackageWarning]
}

enum ContextSourceStatus: Codable, Equatable, Sendable {
    case notRequested
    case included
    case unavailable(String)
    case empty
    case failed(String)
}

struct ContextPackageWarning: Codable, Equatable, Sendable {
    let source: DesktopContextSource
    let message: String
}
```

Metadata gives consumers explainability without forcing them to infer missing context from empty strings.

---

## 7. Source Provider Adapters

The pipeline should not reimplement existing features. It should call small provider adapters around current services.

```swift
@MainActor
protocol ContextSourceProvider {
    associatedtype Output
    func collect(request: ContextRequest) async -> Output
}
```

Recommended first providers:

- `AppContextProvider`: wraps `ContextService.getCurrentTargetApp()`.
- `OCRContextProvider`: wraps `ScreenOCRService.awaitPrefetch()` and `getActiveWindowText(maxLength:)`.
- `ScreenshotContextProvider`: wraps `ScreenOCRService.captureActiveWindow()`.
- `ClipboardContextProvider`: wraps `ClipboardHistoryService.getHistoryForContext(limit:)` initially; later can expose timestamps by using `ClipboardHistoryService.history` if needed.
- `LiveCaptionContextProvider`: wraps `LiveCaptionManager.getOriginalTextHistory(limit:)` and `originalTextCount`.
- `PinnedTextContextProvider`: wraps `PinnedTextManager.items.filter(\.isPinned)` and maps to immutable snapshots.

M1 can implement providers as private methods on `UnifiedContextPipeline` to minimize files. Extract protocols only when tests or provider replacement make it worthwhile.

---

## 8. Collection Behavior

Recommended collection order:

1. Capture app snapshot first, because OCR and screenshot are app-sensitive.
2. Collect OCR and screenshot next. If both are requested, avoid duplicate active-window capture only if `ScreenOCRService` exposes a safe shared capture method later; do not over-optimize in M1.
3. Collect low-cost local buffers: clipboard history, live caption history, pinned text.
4. Build metadata with requested/included/empty/failed source states.

Concurrency note: current source services are `@MainActor` or UI-adjacent, so the first implementation should stay `@MainActor` and avoid detached background reads. Parallelization can be added later only after source methods are proven actor-safe.

Failure behavior:

- Missing permission or no active window should not fail the whole package.
- Each unavailable source becomes a `ContextSourceStatus.unavailable` or `.failed` entry.
- The returned package is still valid if at least metadata is populated.

---

## 9. Prompt Rendering Boundary

`UnifiedContextPipeline` should not return final prompts. Consumers can use a thin rendering helper if useful:

```swift
enum ContextPromptRenderer {
    static func renderForQuickAsk(_ package: ContextPackage, base: QuickAskPromptRequest) -> QuickAskPromptBuildResult
    static func renderForLLMRefinement(_ package: ContextPackage, userText: String, settings: LLMSettings) -> LLMPrompt
}
```

This keeps the package reusable by non-LLM consumers such as `MessagePanelManager` and future workflow actions.

---

## 10. Integration Plan

### 10.1 Quick Ask

Current flow:

```text
QuickAskService.sendQuestion()
  -> QuickAskContextAssembler.collect(OCR + screenshot)
  -> buildPromptResult()
  -> QuickAskPromptAssembler.build(OCR + clipboard + live caption + attachments)
```

Target flow:

```text
QuickAskService.sendQuestion()
  -> unifiedContextPipeline.collect(.quickAsk(settings: llmSettings))
  -> QuickAskPromptAssembler.build(request, contextPackage)
  -> AnswerPanelManager.show(... contextSources, screenshotImage)
  -> LLMPipeline.chat(prompt)
```

Migration details:

- Keep `QuickAskPromptAssembler` as the prompt formatter.
- Replace `QuickAskPromptRequest.ocrContext`, `clipboardHistory`, and `liveCaptionText` with either `contextPackage` or a nested `QuickAskContextSnapshot` derived from it.
- Keep `attachments` in `QuickAskState`; attachments are user-session payloads, not global desktop context.
- Map `ContextPackage.sourcesIncluded` to the existing `ContextSource` enum for Answer Panel UI until the UI can accept `DesktopContextSource` directly.
- Deprecate `QuickAskContextAssembler` after tests cover equivalent package collection.

### 10.2 LLMPipeline

Current flow:

```text
LLMPipeline.buildPrompt()
  -> buildAppContext()
  -> ContextService + ScreenOCRService string assembly
  -> clipboardHistory.formatForPrompt(limit: 10)
```

Target flow:

```text
LLMPipeline.buildPrompt()
  -> unifiedContextPipeline.collect(.llmRefinement(...))
  -> ContextPromptRenderer.renderForLLMRefinement(package, ...)
```

Migration details:

- `buildAppContext()` becomes a compatibility wrapper around the new pipeline during migration, then can be removed.
- Preserve the existing instruction wording: “应用上下文仅用于理解用户意图，不要将无关内容混入转录”.
- Preserve OCR prefetch behavior by setting `preferPrefetchedOCR = true` for refinement requests.
- Preserve clipboard limit `10` for LLM refinement unless settings specify otherwise.

### 10.3 ClipboardPipelineService

Current flow:

```text
ClipboardPipelineService.trigger()
  -> pasteboardText()
  -> currentSourceApp()
  -> MessagePanelManager.addClipboardContent(...)
```

Target role:

`ClipboardPipelineService` remains the action entry for “send clipboard to Message Panel”, but pasteboard / clipboard context becomes a source provider surface used by `UnifiedContextPipeline`.

M1 migration should be conservative:

- Do not remove `trigger()`.
- Add a `ClipboardContextProvider` around existing `ClipboardHistoryService` first.
- Later, if direct current-pasteboard capture must join the unified model, add `DesktopContextSource.currentClipboard` rather than overloading `.clipboardHistory`.
- `ClipboardPipelineService.trigger()` may optionally request `ContextRequest.messagePanelClipboard()` once the pipeline supports current clipboard payloads.

### 10.4 Recording Session

Current flow:

```text
RecordingSessionContextAssembler.capture(transcription, audioURL, targetApp)
```

Target flow:

- Keep `RecordingSessionContextAssembler` for recording-specific result packaging.
- Add optional `ContextPackage` attachment only if recording output needs desktop sources beyond app metadata.
- Do not force recording sessions through the unified pipeline in M1; recording has a separate audio lifecycle and should not be coupled to screen capture unless settings require it.

### 10.5 Message Panel and Workflows

- `MessagePanelManager` should receive context snapshots or rendered cards from action services, not pull context itself.
- Workflow actions can accept `ContextPackage` as an input object once workflow profile routing needs unified context.

---

## 11. Migration Path

### M1 — Introduce the Package Without Behavior Change

1. Add `ContextPackage`, `ContextRequest`, and `UnifiedContextPipelineProtocol`.
2. Add `UnifiedContextPipeline` with app, OCR, screenshot, clipboard history, live caption, and pinned text collection.
3. Register it in `ServiceContainer` and live dependencies.
4. Add focused unit tests with mock pipeline/provider dependencies.
5. Do not delete existing assemblers yet.

### M2 — Quick Ask Uses the Pipeline

1. Inject `UnifiedContextPipelineServiceProtocol` into `QuickAskServiceDependencies`.
2. Replace `QuickAskContextAssembler.collect()` and direct clipboard/live-caption reads with `collect(.quickAsk(...))`.
3. Update `QuickAskPromptAssembler` to render from `ContextPackage`.
4. Keep existing UI context-source display through a compatibility mapping.
5. Remove or deprecate `QuickAskContextAssembler` after test parity.

### M3 — LLMPipeline Uses the Pipeline

1. Inject the pipeline into `LLMPipelineDependencies`.
2. Reimplement `buildAppContext()` as package rendering.
3. Move clipboard prompt formatting from direct `ClipboardHistoryService.formatForPrompt` to package rendering.
4. Preserve current prompt text and limits.

### M4 — Clipboard and Message Panel Alignment

1. Add `currentClipboard` source only if needed for exact `ClipboardPipelineService.trigger()` semantics.
2. Convert `ClipboardPipelineService` from direct source reader to action consumer of package/current-clipboard payload.
3. Allow `MessagePanelManager` cards to store `ContextPackage` metadata for explainability if useful.

---

## 12. Communication Channel Rules

Based on `dependency-channel-decision-matrix.md`:

- **Consumer -> UnifiedContextPipeline**: direct async call through injected service. This is ordered request/response work.
- **SwiftUI view -> context action**: `@Environment(\.services)` or a feature façade. No new view-level `.shared` access.
- **Pipeline -> source services**: direct calls to typed dependencies injected through `UnifiedContextPipelineDependencies`.
- **Context collection events**: no `NotificationCenter`. The package metadata is the trace.
- **Existing system/app activation notifications**: stay inside existing owners such as `ContextService`; do not add parallel context notifications.

Do not introduce `NotificationCenter` for “context updated”, “OCR collected”, or “clipboard included”. If a future UI needs live status, expose typed observable state on a dedicated view model or façade.

---

## 13. Callback and Lifecycle Hygiene

Based on `callback-cleanup-inventory.md` and `service-lifecycle-contract.md`:

- `UnifiedContextPipeline` should not register callbacks in `init()`.
- If a future provider adds callbacks, timers, observers, or monitors, the provider must own its token/session ID and release it in `stop()` and `deinit` fallback.
- Closure callbacks must capture owners weakly when crossing service boundaries.
- The pipeline should prefer pull-based `collect(_:)` over long-lived callback subscriptions.
- AppDelegate should call `unifiedContextPipeline.start()` during managed service startup only after ServiceContainer wiring exists, and `stop()` during termination.

Current M1 providers can be callback-free because they read from existing services (`ScreenOCRService`, `ClipboardHistoryService`, `LiveCaptionManager`, `PinnedTextManager`).

---

## 14. Testing Strategy

Add unit tests around the model and service behavior:

1. `ContextRequest.quickAsk(settings:)` includes the expected sources from settings.
2. Empty OCR / clipboard / caption sources are marked `.empty`, not silently included.
3. Screenshot source can be absent without failing the full package.
4. Pinned text snapshots are immutable and do not expose `PinnedTextItem` references.
5. Quick Ask prompt rendering produces the same prompt sections as the current assembler for existing fixtures.
6. `start()` / `stop()` are idempotent.

Verification commands remain:

```bash
swift build
swift test
bash Tests/run-concurrency-check.sh
```

---

## 15. Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Pipeline becomes a god service | High | Keep it as orchestration only; source ownership remains in existing services. |
| Prompt output changes accidentally | High | Migrate Quick Ask and LLM rendering with golden/string parity tests. |
| UI starts pulling context directly | Medium | Expose actions through ServiceContainer/facades; enforce no new UI `.shared`. |
| Screenshot/OCR duplicate capture costs | Medium | Accept in M1; optimize only after measuring. |
| Actor/concurrency warnings from `CGImage` or UI services | Medium | Keep pipeline `@MainActor`; avoid detached tasks in first implementation. |
| Clipboard sensitive data exposure expands | Medium | Reuse `ClipboardHistoryService` filtering; do not add raw current clipboard to shared package until explicitly needed. |
| PinnedText mutable model leaks | Medium | Return snapshot structs, never `PinnedTextItem` references. |

---

## 16. Non-Goals

- Do not redesign `LLMPipeline` provider execution.
- Do not replace `MessagePanelManager` or Answer Panel UI.
- Do not make `ContextPackage` a persistence format in M1.
- Do not remove existing singleton services in the same migration.
- Do not introduce a new event bus or NotificationCenter layer for context changes.

---

## 17. Recommended First Implementation

Start with the smallest useful slice:

1. Add model/protocol files under `Core/Context`.
2. Implement `UnifiedContextPipeline.collect(_:)` as a pull-based `@MainActor` service.
3. Register it in `ServiceContainer` with test injection.
4. Add tests for package assembly and metadata.
5. Migrate Quick Ask first because it already exercises OCR, screenshot, clipboard, and live caption in one flow.

This gives the Desktop Understanding Layer a stable typed boundary while preserving current behavior and minimizing architectural churn.
