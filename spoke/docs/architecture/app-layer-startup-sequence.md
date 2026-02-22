# App Layer: Startup Sequence Analysis

**Analyst**: claude-2
**Date**: 2026-02-22
**Scope**: App/ entry flow and service initialization

---

## 1. Entry Point Architecture

### 1.1 Main Entry (`SpokenlyApp.swift`)

```
@main SpokenAnyWhereApp
  ├─ @NSApplicationDelegateAdaptor(AppDelegate)
  ├─ Settings Scene
  └─ ModelContainer: AppDelegate.sharedModelContainer
```

**Characteristics**:
- Minimal SwiftUI app structure
- Delegates all lifecycle to AppDelegate
- Provides Settings-only UI (no main window)
- Shares ModelContainer across app

### 1.2 Application Delegate (`AppDelegate.swift`)

**Role**: Core lifecycle manager and service orchestrator

**Key Responsibilities**:
1. ModelContainer initialization (SwiftData)
2. Service startup sequencing
3. Menu bar setup
4. Permission management
5. Cleanup on termination

---

## 2. Startup Sequence (Instrumented)

### Phase 1: Critical Infrastructure (0-2)
```
Step 0: CrashLogger.shared.install()
  └─ Signal handler registration (SIGSEGV, SIGABRT, etc.)

Step 1: checkAccessibilityPermission()
  └─ AccessibilityHelper.requestAccessibilityPermission()
  └─ Required for: HotKeys, Input injection, Selection monitoring

Step 2: setupMenuBar()
  └─ NSStatusBar.system.statusItem
  └─ Menu items + shortcut observer
```

**Blocking**: All synchronous, must complete before services start

---

### Phase 2: Core Services (3-5)
```
Step 3: ClipboardHistoryService.shared.start()
  └─ NSPasteboard monitoring

Step 4: RecordingController.shared.start()
  └─ Dependencies (lazy init):
      ├─ FloatingHUDManager.shared
      ├─ ContextService.shared
      ├─ HotKeyService.shared
      ├─ AudioRecorderService.shared
      ├─ InputService.shared
      ├─ AppSettings.shared
      ├─ LLMPipeline.shared
      ├─ HistoryManager.shared
      ├─ QuickAskService.shared
      └─ ScreenOCRService.shared

Step 5: HistoryManager.shared.configure(modelContext)
  └─ Injects SwiftData context
```

**Blocking**: RecordingController initialization triggers cascade of singleton inits

---

### Phase 3: Data Maintenance (6-6.1)
```
Step 6: performHistoryCleanup()
  └─ Task { await HistoryManager.performCleanup(...) }
  └─ Async: keepDays / keepCount policies

Step 6.1: performOrphanCleanup()
  └─ Task {
      ├─ migrateLegacyTodayRecords()
      ├─ cleanupOrphanedAudioFiles()
      ├─ enforceNormalRecordLimit(50)
      └─ enforceAudioSizeLimit(2GB)
  }
```

**Non-blocking**: Background tasks, don't block UI

---

### Phase 4: Heavy Background Prep (6.5-6.6)
```
Step 6.5: Dictionary Precompilation (if enabled)
  └─ Task.detached(priority: .background) {
      await TranscriptionManager.prepareDictionary()
  }
  └─ Only if: TranscriptionModelManager.enablePrecompiledLM

Step 6.6: Speech Engine Warmup
  └─ Task.detached(priority: .background) {
      await warmupSpeechEngine()
  }
  └─ Eliminates ~2s first-use lag
```

**Non-blocking**: Background tasks, improve first-use experience

---

### Phase 5: Feature Services (7-11)
```
Step 7: setupTrackpadGesture()
  └─ TrackpadSwipeService.shared.start()
  └─ Callbacks: onOpenPanel, onClosePanel

Step 8: setupResourceMonitor()
  └─ ResourceMonitor.shared.start(interval: 3.0)
  └─ Thresholds: CPU 150%, Memory 800MB

Step 9: setupSelectionToolbar()
  └─ SelectionActionService.shared (init)
  └─ SelectionToolbarManager.shared.start() (if enabled)

Step 10: setupScreenshotService()
  └─ HotKeyService.onScreenshotTrigger callback
  └─ ScreenshotManager.windowFactory callback
  └─ Task(priority: .utility) {
      await ScreenshotManager.restoreAll()
  }

Step 11: setupDictionaryPanel()
  └─ DictionaryPanelManager.shared.registerShortcut()
```

**Blocking**: Steps 7-9, 11 are synchronous
**Non-blocking**: Step 10 screenshot restoration is async

---

## 3. Service Dependency Graph

### 3.1 Singleton Services (25 total)

**Core Infrastructure**:
- AppSettings
- AccessibilityHelper
- CrashLogger

**Audio/Recording**:
- AudioRecorderService
- RecordingController
- AudioPlayerService
- AudioDeviceManager

**UI Management**:
- FloatingHUDManager
- MessagePanelManager
- SelectionToolbarManager
- LiveCaptionWindowManager (implied)

**Input/Output**:
- HotKeyService
- InputService
- ClipboardHistoryService
- SelectionMonitorService

**Data/Storage**:
- HistoryManager
- AppSettings
- KeychainService (implied)

**Feature Services**:
- QuickAskService
- ScreenOCRService
- ContextService
- TrackpadSwipeService
- ResourceMonitor
- ScreenshotManager
- DictionaryPanelManager
- SelectionActionService
- ToolbarConfigService
- VocabularyService
- SummaryService
- ImageEnhancementService
- ScreenCaptureBlurService
- EdgeTTSService
- ClipboardPipelineService

### 3.2 RecordingController Dependencies (Critical Path)

```
RecordingController.shared (Step 4)
  ├─ FloatingHUDManager.shared
  ├─ ContextService.shared
  ├─ HotKeyService.shared
  ├─ AudioRecorderService.shared
  ├─ InputService.shared
  ├─ AppSettings.shared
  ├─ LLMPipeline.shared
  ├─ HistoryManager.shared
  ├─ QuickAskService.shared
  └─ ScreenOCRService.shared
```

**Risk**: RecordingController init triggers 10+ singleton initializations

---

## 4. Initialization Patterns

### 4.1 Singleton Pattern
```swift
@MainActor
final class ServiceName {
    static let shared = ServiceName()
    private init() { /* setup */ }
}
```

**Characteristics**:
- All services use `static let shared`
- Lazy initialization on first access
- @MainActor isolation (most services)

### 4.2 Callback-Based Coordination
```swift
// HotKeyService -> RecordingController
hotKeyService.onQuickAskStart = { [weak self] in
    self?.quickAskService.startSession()
}

// HUD -> RecordingController
hudManager.onComplete = { [weak self] in
    self?.completeRecordingSession()
}
```

**Pattern**: Services expose closure properties for coordination

### 4.3 Dependency Injection Points
```swift
// HistoryManager needs ModelContext
HistoryManager.shared.configure(with: modelContext)

// ScreenshotManager needs window factory
ScreenshotManager.shared.windowFactory = { item in
    ScreenshotWindow(item: item)
}
```

**Pattern**: Late binding for dependencies that can't be resolved at init

---

## 5. Critical Risks

### 5.1 Startup Blocking Risks

**RISK-APP-001: Screenshot Restoration Blocking**
- **Location**: `AppDelegate.swift:154`
- **Status**: MITIGATED (moved to async Task)
- **Previous Issue**: Synchronous `restoreAll()` blocked main thread
- **Current**: `Task(priority: .utility) { await restoreAll() }`
- **Residual Risk**: Large number of pinned screenshots still slow

**RISK-APP-002: RecordingController Cascade**
- **Location**: `AppDelegate.swift:71`
- **Status**: ACTIVE
- **Issue**: `RecordingController.shared.start()` triggers 10+ singleton inits
- **Impact**: Unpredictable startup time if any dependency is slow
- **Mitigation**: None currently

**RISK-APP-003: Dictionary Precompilation**
- **Location**: `AppDelegate.swift:92`
- **Status**: MITIGATED (background task)
- **Issue**: Can take several seconds
- **Current**: `Task.detached(priority: .background)`
- **Residual Risk**: None (non-blocking)

### 5.2 Callback Override Risks

**RISK-APP-004: Audio Callback Conflicts**
- **Location**: `RecordingController.swift:47`
- **Issue**: `audioService.createCallbackSession()` creates session ID
- **Risk**: Multiple services setting audio callbacks could conflict
- **Context Note**: See N002 - "回调串线" mentioned in project notes
- **Mitigation**: Session-based callback management

### 5.3 Circular Dependency Risks

**RISK-APP-005: Potential Circular Init**
- **Status**: NEEDS VERIFICATION
- **Issue**: 25 singletons with complex dependencies
- **Example**: RecordingController → HotKeyService → (back to RecordingController?)
- **Mitigation**: Lazy initialization breaks most cycles

### 5.4 Resource Cleanup Risks

**RISK-APP-006: Incomplete Termination Cleanup**
- **Location**: `AppDelegate.swift:281`
- **Issue**: Only 4 services explicitly stopped:
  - RecordingController
  - TrackpadSwipeService
  - SelectionToolbarManager
  - ResourceMonitor
- **Missing**: 20+ other services not explicitly cleaned up
- **Impact**: Potential resource leaks, incomplete state saves

---

## 6. Performance Characteristics

### 6.1 Startup Time Budget (from logs)
```
Step 0-2:   ~50ms   (Critical infrastructure)
Step 3-5:   ~100ms  (Core services + cascade)
Step 6-6.1: ~10ms   (Task spawn, actual work async)
Step 6.5:   ~5ms    (Task spawn, actual work async)
Step 6.6:   ~5ms    (Task spawn, actual work async)
Step 7-11:  ~50ms   (Feature services)
---
Total:      ~220ms  (synchronous path)
```

**Background Work** (parallel):
- History cleanup: ~100-500ms
- Dictionary precompilation: ~1-3s
- Speech engine warmup: ~1.8s
- Screenshot restoration: ~50-500ms (depends on count)

### 6.2 Performance Instrumentation
```swift
// AppDelegate.swift:44-53
let launchStart = CFAbsoluteTimeGetCurrent()
func logStep(_ name: String) {
    #if DEBUG
    let totalTime = (CFAbsoluteTimeGetCurrent() - launchStart) * 1000
    logger.debug("\(name) [\(String(format: "%.0f", totalTime))ms]")
    #endif
}
```

**Environment Variable**: `SPOKE_PERF_LOG=1` enables perf logging

---

## 7. Architectural Observations

### 7.1 Strengths
1. **Clear Sequencing**: Numbered steps make order explicit
2. **Instrumentation**: Built-in timing logs for debugging
3. **Async Optimization**: Heavy work moved to background
4. **Weak References**: Callbacks use `[weak self]` to avoid cycles

### 7.2 Weaknesses
1. **Tight Coupling**: RecordingController depends on 10+ services
2. **Implicit Dependencies**: Singleton init order not enforced
3. **Limited Cleanup**: Most services don't implement explicit teardown
4. **Callback Complexity**: Multiple callback chains hard to trace

### 7.3 Improvement Opportunities
1. **Dependency Injection**: Replace singletons with DI container
2. **Service Lifecycle**: Explicit start/stop protocol for all services
3. **Init Order Validation**: Assert expected init order in debug builds
4. **Callback Registry**: Centralized callback management

---

## 8. Next Steps for Full Analysis

### 8.1 Remaining Work (T+60)
- [ ] Map Core/ layer service implementations
- [ ] Trace callback chains across services
- [ ] Verify no circular dependencies
- [ ] Document service protocols (ServiceContainer.swift)

### 8.2 Final Deliverable (T+90)
- [ ] Complete dependency graph (visual)
- [ ] Cross-layer interaction patterns
- [ ] Risk mitigation recommendations
- [ ] Refactoring suggestions (if requested)

---

**Status**: T+30 Module Boundary Draft Complete ✅
**Next**: Service implementation deep-dive for T+60 deliverable
