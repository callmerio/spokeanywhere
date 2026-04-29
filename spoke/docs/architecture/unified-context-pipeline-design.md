# Unified Context Pipeline — Architecture Design

> Status: Draft v0.1 | 2026-04-29
> Depends on: `dependency-channel-decision-matrix.md`, `service-lifecycle-contract.md`
> Informs: Option D — Desktop Understanding Layer

## Overview

SpokenAnyWhere currently assembles AI context in three separate places:

| Consumer | Sources | File |
|----------|---------|------|
| LLMPipeline.buildAppContext() | OCR only | LLMPipeline.swift |
| QuickAskContextAssembler.collect() | OCR + Screenshot | QuickAskContextAssembler.swift |
| QuickAskPromptAssembler.build() | OCR + Clipboard + LiveCaption + Attachments | QuickAskPromptAssembler.swift |

Each consumer independently decides what to include, how to format it, and when to fetch. There is no shared abstraction, no caching, and no consistent source selection.

**Goal**: Replace ad-hoc context assembly with a single `UnifiedContextPipeline` service that any consumer can query.

---

## 1. Protocol Design

### 1.1 UnifiedContextPipelineProtocol

```swift
/// Unified access point for desktop context sources.
/// Follows ServiceContainer + @MainActor pattern per project conventions.
@MainActor
protocol UnifiedContextPipelineProtocol: AnyObject {
    
    /// Collect context from the requested sources.
    /// Returns a structured ContextPackage with metadata about what was included.
    func collect(_ request: ContextRequest) async -> ContextPackage
    
    /// Start/stop lifecycle per service-lifecycle-contract.md
    func start()
    func stop()
}
```

### 1.2 ContextRequest

```swift
struct ContextRequest {
    /// Which sources to include
    let sources: Set<ContextSource>
    
    /// Per-source limits (e.g., max clipboard items, max caption characters)
    let limits: ContextLimits
    
    /// Optional: override the target app (default: current focused app)
    let targetApp: TargetAppInfo?
    
    /// Optional: pre-captured data to use instead of live fetch
    let preCaptured: PreCapturedContext?
    
    enum ContextSource: String, CaseIterable {
        case ocr
        case screenshot
        case clipboard
        case liveCaption
        case pinnedText
        case appInfo
    }
}
```

### 1.3 ContextPackage

```swift
struct ContextPackage {
    /// Which sources actually contributed data
    let includedSources: Set<ContextSource>
    
    /// Per-source structured results
    let results: [ContextSource: ContextResult]
    
    /// Ready-to-use sections for prompt assembly
    var sections: [PromptSection] {
        results.values
            .sorted(by: { $0.priority < $1.priority })
            .compactMap { $0.section }
    }
    
    /// Metadata
    let timestamp: Date
    let fetchDurationMs: Double
    let errors: [ContextSource: Error]  // sources that failed
}

struct ContextResult {
    let source: ContextSource
    let section: PromptSection?  // nil if empty/disabled
    let rawData: Any?            // typed access (CGImage, [String], etc.)
    let priority: Int            // lower = appears first in prompt
}
```

---

## 2. Implementation Strategy

### 2.1 Service Registration

```swift
@MainActor
final class UnifiedContextPipeline: ObservableObject, UnifiedContextPipelineProtocol {
    // Follows ServiceContainer DI pattern
    // Dependencies injected via struct, not shared singleton
    
    struct Dependencies {
        let screenOCR: ScreenOCRServiceProtocol
        let contextService: ContextServiceProtocol
        let clipboardHistory: ClipboardHistoryServiceProtocol
        let liveCaptionManager: LiveCaptionManagerProtocol
        let pinnedTextManager: PinnedTextManagerProtocol
        let screenCapture: ScreenCaptureServiceProtocol
    }
    
    private let deps: Dependencies
    
    init(dependencies: Dependencies) {
        self.deps = dependencies
    }
    
    func start() { /* register observers, warm caches */ }
    func stop() { /* clean up per callback-cleanup-inventory.md */ }
    
    func collect(_ request: ContextRequest) async -> ContextPackage {
        // 1. Validate request
        // 2. Fetch each requested source in parallel (TaskGroup)
        // 3. Assemble ContextPackage
        // 4. Record metrics
    }
}
```

### 2.2 Parallel Source Collection

Each source fetcher is independent — they can run in parallel using `TaskGroup`:

```swift
func collect(_ request: ContextRequest) async -> ContextPackage {
    var results: [ContextSource: ContextResult] = [:]
    var errors: [ContextSource: Error] = [:]
    let startTime = CFAbsoluteTimeGetCurrent()
    
    await withTaskGroup(of: (ContextSource, Result<ContextResult, Error>).self) { group in
        for source in request.sources {
            group.addTask { await self.fetchSource(source, request: request) }
        }
        for await (source, result) in group {
            switch result {
            case .success(let ctx): results[source] = ctx
            case .failure(let err): errors[source] = err
            }
        }
    }
    
    return ContextPackage(
        includedSources: Set(results.keys),
        results: results,
        timestamp: Date(),
        fetchDurationMs: (CFAbsoluteTimeGetCurrent() - startTime) * 1000,
        errors: errors
    )
}
```

---

## 3. Communication Channel Decision

Per `dependency-channel-decision-matrix.md`:

| Scenario | Channel | Reason |
|----------|---------|--------|
| Context pipeline → consumers (LLMPipeline, QuickAsk) | **Direct injection** via ServiceContainer | One-to-one, MainActor-bound, testable |
| Context pipeline → UI (context status indicator) | **@Published property** | SwiftUI native, no NotificationCenter needed |
| External systems → context pipeline (clipboard change, new caption) | **Direct call** from coordinator | Avoid NotificationCenter broadcast coupling |
| Source providers (OCR, clipboard) → pipeline | **Protocol dependency injection** | Already established pattern in project |

**Forbidden**: NotificationCenter for context events. The dependency matrix explicitly warns against implicit coupling via notifications.

---

## 4. Migration Path

### Phase 1: Create pipeline service (no consumer changes)
- Implement `UnifiedContextPipeline` with parallel source fetching
- Register in `ServiceContainer`
- Add tests verifying correct assembly from each source type
- **Zero consumer impact** — purely additive

### Phase 2: Migrate QuickAskPromptAssembler
- Replace manual section assembly with `pipeline.collect(request).sections`
- QuickAskPromptAssembler becomes a thin formatter, not a fetcher
- Remove duplicate source-fetching code

### Phase 3: Migrate LLMPipeline.buildAppContext
- Replace `buildAppContext()` with `pipeline.collect(request)`
- LLMPipeline no longer needs to know about OCR or clipboard details

### Phase 4: Deprecate standalone assemblers
- `QuickAskContextAssembler` → marked deprecated
- `RecordingSessionContextAssembler` → folded into pipeline
- `ClipboardPipelineService` → becomes a source provider, not a consumer

---

## 5. Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Performance regression (parallel fetch slower than direct) | Low | Parallel TaskGroup should be faster; measure with metrics |
| Source provider unavailable (no active app for OCR) | Medium | ContextPackage.errors tracks failures per source; consumer decides fallback |
| Breaking existing prompt format | Medium | Output ContextPackage.sections mirrors existing PromptSection format |
| Service lifecycle ordering (pipeline starts before providers) | Low | Follow service-lifecycle-contract.md; pipeline depends on providers being ready |
| Memory pressure from screenshot images in pipeline | Medium | Screenshot optional; preCaptured allows consumer to pass already-loaded image |

---

## 6. Non-Goals (Explicitly Out of Scope)

- AI-driven context priority ranking (future feature)
- Distributed context sources (network/cloud)
- Persistence of context packages (Future: Workflow/Persistence Layer)
- Real-time context streaming (current: snapshot-based)

---

## References

- `spoke/docs/architecture/dependency-channel-decision-matrix.md` — Channel selection governance
- `spoke/docs/architecture/service-lifecycle-contract.md` — Service start/stop patterns
- `spoke/docs/architecture/callback-cleanup-inventory.md` — Callback hygiene reference
- `ROADMAP.detail.md` — Product vision: Desktop Context → [采集] → [理解] → [动作]
- `AGENTS.md` — Project conventions (DesignTokens, ServiceContainer, anti-patterns)
