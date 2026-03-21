# Orchestrator Hotspots Round 2 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 继续收敛 `AppDelegate`、`QuickAskService`、`RecordingController` 这三个剩余高耦合枢纽，在不改变用户可见行为的前提下，进一步降低 `.shared` 密度、回调样板和巨型流程复杂度。

**Architecture:** 本轮不做“大重写”，而是把仍然堆在 orchestrator 里的纯决策逻辑和生命周期编排逻辑抽成小而可测的 helper/type，再把 side effect 留在原服务里。优先把可单测的纯逻辑移出热路径，用 `Swift Testing` 建立新的表征测试，再用现有 `swift test`、strict concurrency 和 AX smoke 作为整仓回归门禁。

**Tech Stack:** Swift 6、SwiftPM、Swift Testing、XCTest、AppKit、SwiftUI、ApplicationServices

---

### Task 1: 提取 Quick Ask Prompt Assembler

**Files:**
- Create: `Core/QuickAsk/QuickAskPromptAssembler.swift`
- Create: `Tests/QuickAskPromptAssemblerTests.swift`
- Modify: `Services/QuickAskService.swift`

**Step 1: Write the failing test**

```swift
import Testing
@testable import SpokenAnyWhere

@Suite("QuickAskPromptAssembler 测试")
struct QuickAskPromptAssemblerTests {
    @Test("仅在启用时拼入 OCR 与剪贴板上下文")
    func contextSectionsRespectFlags() {
        let request = QuickAskPromptRequest(
            userInput: "总结一下",
            voiceText: "",
            ocrContext: "窗口文本",
            clipboardText: "剪贴板",
            liveCaptionText: nil,
            attachments: [],
            includeOCR: true,
            includeClipboard: false,
            includeLiveCaption: false
        )

        let result = QuickAskPromptAssembler.build(request)

        #expect(result.prompt.contains("窗口文本"))
        #expect(!result.prompt.contains("剪贴板"))
        #expect(result.contextSources == [.ocr])
    }
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter QuickAskPromptAssemblerTests`

Expected: FAIL with missing `QuickAskPromptRequest` / `QuickAskPromptAssembler`

**Step 3: Write minimal implementation**

```swift
struct QuickAskPromptRequest {
    let userInput: String
    let voiceText: String
    let ocrContext: String?
    let clipboardText: String?
    let liveCaptionText: String?
    let attachments: [Attachment]
    let includeOCR: Bool
    let includeClipboard: Bool
    let includeLiveCaption: Bool
}

enum QuickAskPromptAssembler {
    static func build(_ request: QuickAskPromptRequest) -> PromptBuildResult {
        var sections: [PromptSection] = []
        // 只在 flag 打开且内容非空时追加 section
        return PromptBuildResult(
            prompt: PromptRenderer.renderSections(sections),
            contextSources: []
        )
    }
}
```

**Step 4: Wire QuickAskService to use the assembler**

```swift
private func buildPromptResult(ocrContext: String? = nil) -> PromptBuildResult {
    QuickAskPromptAssembler.build(
        QuickAskPromptRequest(
            userInput: state.userInput,
            voiceText: state.voiceTranscription,
            ocrContext: ocrContext,
            clipboardText: dependencies.clipboardHistoryService.latestText,
            liveCaptionText: dependencies.liveCaptionManager.currentText,
            attachments: state.attachments,
            includeOCR: dependencies.llmSettings.quickAskIncludeOCR,
            includeClipboard: dependencies.llmSettings.quickAskIncludeClipboard,
            includeLiveCaption: dependencies.llmSettings.quickAskIncludeLiveCaption
        )
    )
}
```

**Step 5: Run tests to verify it passes**

Run:
- `swift test --filter QuickAskPromptAssemblerTests`
- `swift test --filter RecordingPipelineTests`

Expected:
- `QuickAskPromptAssemblerTests` PASS
- Existing recording tests still PASS

**Step 6: Commit**

```bash
git add Core/QuickAsk/QuickAskPromptAssembler.swift Tests/QuickAskPromptAssemblerTests.swift Services/QuickAskService.swift
git commit -m "refactor: extract quick ask prompt assembler"
```

### Task 2: 收敛 QuickAskService / QuickAskHUDManager 运行时样板

**Files:**
- Modify: `Services/QuickAskService.swift`
- Test: `Tests/AudioCallbackRouterTests.swift`
- Test: `Tests/UITests/SpokenAnyWhereUITests.swift`

**Step 1: Write the failing characterization test**

```swift
@Test("Quick Ask 会话切换不会污染 callback session")
func quickAskSessionLifecycleStaysIsolated() {
    let router = AudioCallbackRouter()
    let quickAskSession = UUID()
    let recordingSession = UUID()

    router.ensureSession(quickAskSession)
    router.ensureSession(recordingSession)
    router.setActiveSession(quickAskSession)
    router.removeSession(quickAskSession)

    #expect(router.activeSessionID != quickAskSession)
}
```

**Step 2: Run test to verify it fails or exposes missing seam**

Run: `swift test --filter AudioCallbackRouterTests`

Expected: FAIL or require minimal router seam exposure before refactor

**Step 3: Write minimal implementation**

```swift
@MainActor
extension QuickAskHUDManagerDependencies {
    static func makeLive(
        hotKeyService: HotKeyService = .shared,
        workflowState: WorkflowState = .shared,
        attachmentManager: AttachmentManager = .shared,
        answerPanelManager: AnswerPanelManager = .shared
    ) -> Self {
        .init(
            hotKeyService: hotKeyService,
            workflowState: workflowState,
            attachmentManager: attachmentManager,
            notificationCenter: .default,
            clipboardText: { NSPasteboard.general.string(forType: .string) },
            showAnswerPanel: { answerPanelManager.show(question: $0, attachments: $1) },
            updateAnswer: { answerPanelManager.updateAnswer($0, for: $1) },
            showAnswerError: { answerPanelManager.showError($0, for: $1) },
            executeWorkflow: { workflow, context in
                await WorkflowExecutor.shared.execute(workflow, context: context)
            },
            openSettings: { _ = NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil) }
        )
    }
}
```

**Step 4: Refactor the runtime helpers**

```swift
private func startRecordingTimer() {
    let updateDuration = makeQuickAskAction { service in
        service.updateRecordingDuration()
    }
    recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
        updateDuration()
    }
}

private func stopSessionRuntime() {
    recordingTimer?.invalidate()
    recordingTimer = nil
    recordingStartTime = nil
    unregisterAudioCallbacks()
}
```

**Step 5: Run tests to verify it passes**

Run:
- `swift test --filter AudioCallbackRouterTests`
- `swift test --filter SpokenAnyWhereUITests/testLiveCaptionAccessibilityIdentifierSmoke`

Expected:
- Callback isolation tests PASS
- UI smoke still PASS when explicitly enabled

**Step 6: Commit**

```bash
git add Services/QuickAskService.swift Tests/AudioCallbackRouterTests.swift Tests/UITests/SpokenAnyWhereUITests.swift
git commit -m "refactor: reduce quick ask runtime coupling"
```

### Task 3: 提取 RecordingController 转写决策层

**Files:**
- Create: `Services/RecordingTranscriptionDecision.swift`
- Create: `Tests/RecordingTranscriptionDecisionTests.swift`
- Modify: `Services/RecordingController.swift`
- Test: `Tests/RecordingPipelineTests.swift`

**Step 1: Write the failing test**

```swift
import Testing
@testable import SpokenAnyWhere

@Suite("RecordingTranscriptionDecision 测试")
struct RecordingTranscriptionDecisionTests {
    @Test("LLM 失败时保留原始文本并回退到原始剪贴板内容")
    func fallbackToRawTextOnLLMFailure() {
        let decision = RecordingTranscriptionDecision.make(
            rawText: "原始转写",
            refineResult: .failure(.cancelled),
            isStillRecording: false
        )

        #expect(decision.clipboardText == "原始转写")
        #expect(decision.processedText == nil)
        #expect(decision.shouldCompleteHUD)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter RecordingTranscriptionDecisionTests`

Expected: FAIL with missing `RecordingTranscriptionDecision`

**Step 3: Write minimal implementation**

```swift
struct RecordingTranscriptionDecision {
    let clipboardText: String
    let processedText: String?
    let shouldCompleteHUD: Bool

    static func make(
        rawText: String,
        refineResult: Result<String, LLMError>,
        isStillRecording: Bool
    ) -> Self {
        switch refineResult {
        case .success(let refined):
            return .init(
                clipboardText: refined,
                processedText: refined,
                shouldCompleteHUD: !isStillRecording
            )
        case .failure:
            return .init(
                clipboardText: rawText,
                processedText: nil,
                shouldCompleteHUD: !isStillRecording
            )
        }
    }
}
```

**Step 4: Refactor RecordingController to consume the decision**

```swift
let decision = RecordingTranscriptionDecision.make(
    rawText: transcribedText,
    refineResult: result,
    isStillRecording: dependencies.hotKeyService.isRecording
)

dependencies.copyToClipboard(decision.clipboardText)
if decision.shouldCompleteHUD {
    dependencies.hudManager.complete(with: decision.clipboardText)
}
await persistRecording(
    rawText: transcribedText,
    processedText: decision.processedText,
    audioURL: tempAudioURL,
    appBundleId: sourceApp?.bundleId
)
```

**Step 5: Run tests to verify it passes**

Run:
- `swift test --filter RecordingTranscriptionDecisionTests`
- `swift test --filter RecordingPipelineTests`

Expected:
- Both suites PASS

**Step 6: Commit**

```bash
git add Services/RecordingTranscriptionDecision.swift Tests/RecordingTranscriptionDecisionTests.swift Services/RecordingController.swift Tests/RecordingPipelineTests.swift
git commit -m "refactor: extract recording transcription decisions"
```

### Task 4: 提取 App 生命周期计划对象

**Files:**
- Create: `App/AppLifecyclePlan.swift`
- Create: `Tests/AppLifecyclePlanTests.swift`
- Modify: `App/AppDelegate.swift`

**Step 1: Write the failing test**

```swift
import Testing
@testable import SpokenAnyWhere

@Suite("AppLifecyclePlan 测试")
struct AppLifecyclePlanTests {
    @Test("startup plan 保持现有步骤顺序")
    func startupStepOrderIsStable() {
        let plan = AppLifecyclePlan.startup(includeDebugAutomation: false)

        #expect(plan.map(\\.id) == [
            "install-crash-logger",
            "check-accessibility",
            "setup-menu-bar",
            "start-clipboard-service",
            "start-recording-controller",
            "configure-history-manager",
            "perform-history-cleanup",
            "perform-orphan-cleanup",
            "prepare-dictionary",
            "warmup-speech-engine",
            "setup-trackpad-gesture",
            "setup-resource-monitor",
            "setup-selection-toolbar",
            "setup-screenshot-service",
            "setup-dictionary-panel"
        ])
    }
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter AppLifecyclePlanTests`

Expected: FAIL with missing `AppLifecyclePlan`

**Step 3: Write minimal implementation**

```swift
struct AppLifecycleStepSpec: Equatable {
    let id: String
    let name: String
}

enum AppLifecyclePlan {
    static func startup(includeDebugAutomation: Bool) -> [AppLifecycleStepSpec] { ... }
    static func shutdown(includeDebugAutomation: Bool) -> [AppLifecycleStepSpec] { ... }
}
```

**Step 4: Wire AppDelegate to map plan specs to effects**

```swift
private func buildStartupSteps() -> [LifecycleStep] {
    AppLifecyclePlan.startup(includeDebugAutomation: isDebugAutomationAvailable)
        .map { spec in
            (spec.name, effect(for: spec.id))
        }
}
```

**Step 5: Run tests to verify it passes**

Run:
- `swift test --filter AppLifecyclePlanTests`
- `swift test --filter AppSettingsTests`

Expected:
- Lifecycle plan tests PASS
- Existing settings-related tests still PASS

**Step 6: Commit**

```bash
git add App/AppLifecyclePlan.swift Tests/AppLifecyclePlanTests.swift App/AppDelegate.swift
git commit -m "refactor: extract app lifecycle plan"
```

### Task 5: 整仓验证与文档同步

**Files:**
- Modify: `docs/architecture/overview.md`
- Modify: `docs/architecture/risks-and-recommendations.md`
- Modify: `issues/2026-03-20_18-43-37-taste-remediation-backlog.csv`

**Step 1: Update architecture notes**

```md
- Quick Ask prompt assembly 已抽到独立 helper，可单测
- Recording 转写决策已从 orchestrator 剥离
- App lifecycle step order 已变为显式 plan 对象
```

**Step 2: Update the backlog snapshot**

```csv
id,project_progress,notes
TASTE-APP-020,待Review,AppLifecyclePlan extracted
TASTE-QA-020,待Review,QuickAsk prompt/runtime helpers extracted
TASTE-REC-020,待Review,Recording transcription decision extracted
```

**Step 3: Run full verification**

Run:
- `swift build`
- `swift test`
- `bash Tests/run-concurrency-check.sh`
- `ENABLE_AX_SMOKE_TESTS=1 swift test --filter SpokenAnyWhereUITests/testLiveCaptionAccessibilityIdentifierSmoke`

Expected:
- build PASS
- `129 tests / 22 suites` PASS or higher if new tests added
- strict concurrency PASS with `0 warnings`
- AX smoke PASS

**Step 4: Commit**

```bash
git add docs/architecture/overview.md docs/architecture/risks-and-recommendations.md issues/2026-03-20_18-43-37-taste-remediation-backlog.csv
git commit -m "docs: sync orchestrator round 2 progress"
```

### Task 6: Final review pass

**Files:**
- Review: `App/AppDelegate.swift`
- Review: `Services/QuickAskService.swift`
- Review: `Services/RecordingController.swift`
- Review: `Core/QuickAsk/QuickAskPromptAssembler.swift`
- Review: `Services/RecordingTranscriptionDecision.swift`
- Review: `App/AppLifecyclePlan.swift`

**Step 1: Review for taste regressions**

Check:
- 是否又把纯决策逻辑塞回 orchestrator
- 是否新增了 `.shared` 直连
- 是否新增 `Task { @MainActor ... }` 样板而不是复用 helper
- 是否为了“兼容”保留了死代码

**Step 2: Run final verification**

Run:
- `swift build`
- `swift test`
- `bash Tests/run-concurrency-check.sh`

Expected:
- All PASS

**Step 3: Commit**

```bash
git add App/AppDelegate.swift Services/QuickAskService.swift Services/RecordingController.swift Core/QuickAsk/QuickAskPromptAssembler.swift Services/RecordingTranscriptionDecision.swift App/AppLifecyclePlan.swift
git commit -m "refactor: finish orchestrator hotspots round 2"
```
