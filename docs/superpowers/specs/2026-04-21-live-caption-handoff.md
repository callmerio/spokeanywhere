# Live Caption Handoff

Date: 2026-04-21
Scope: SpokenAnyWhere live caption rendering, mock verification chain, collapsed-mode behavior
Repo: `/Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere`

## 1. Goal

This handoff captures the current state of the SpokenAnyWhere live caption workstream so a new session can resume without re-debugging old environment issues.

The original bug was:

- after an extremely long previous sentence, the next sentence could already exist in the accessibility tree
- but the newest translated Chinese line was not visible in the collapsed live caption window

That bug was fixed. The current remaining problem is narrower:

- collapsed mode should allow manual history scrolling
- while still keeping the newest Chinese translation fully visible

## 2. Current Status

### 2.1 Resolved

The following layers are already solved and should not be re-investigated from scratch:

1. The original `visual_scroll_mismatch` bug
   - A retained fix path exists and brought the metric to `0`
   - The root cause was not simply missing scroll execution; it was the collapsed-mode rendering contract

2. Fresh installed-app visual verification
   - Verification no longer depends on a fragile `exec + env` path
   - `./dev.sh` in default `open` mode can now launch the correct installed app and bootstrap the live caption mock scenario

3. Installed-app provenance drift
   - The session identified and bypassed prior issues where validation could accidentally observe a wrong worktree app or stale bundled app

4. Overlay pollution
   - Screenshot / pinned-text restore pollution was explicitly handled for live caption mock verification

5. Strict concurrency gate
   - The concrete warning on `AppDebugLaunchContext.liveCaptionMockScenarioActive` was fixed
   - `bash Tests/run-concurrency-check.sh` returned to `0 warnings`

### 2.2 Partially Resolved / Current Focus

Collapsed mode behavior is currently in transition.

There were three stages:

1. `collapsed-latest-only`
   - Only the latest finalized item was rendered in collapsed mode
   - This fixed newest Chinese visibility
   - But collapsed mode no longer allowed meaningful history scrolling

2. `collapsed recent full history`
   - Restored recent history into collapsed mode
   - This brought back scrolling
   - But reintroduced the problem where older content pushed the newest Chinese line out of view

3. `collapsed recent history + latest full item`
   - Current in-progress contract
   - Recent collapsed items are kept
   - Older collapsed items are rendered as reduced original-text-only summaries
   - The latest collapsed item still renders full English + full Chinese
   - This is the current candidate contract, but it has not yet been accepted as final

## 3. Latest Verified Behavior

### 3.1 Mock verification chain

The mock path is now:

```text
SPOKE_DEBUG_LIVECAPTION_SCENARIO=long_translation ./dev.sh
    -> dev-run.sh writes /tmp/spoke-livecaption-mock-scenario.txt
    -> open-mode launches /Users/bigdan/Applications/SpokenAnyWhere Dev.app
    -> app launch reads bootstrap file
    -> app self-bootstraps live caption mock scenario
    -> real ui.live-caption.window appears
```

### 3.2 Verified window identity

The live caption test surface was explicitly verified as:

- `AXIdentifier = ui.live-caption.window`
- one live caption window exists in System Events

### 3.3 Current runtime observations

At the latest inspection point, the real collapsed window showed:

- a live `scroll area`
- a `scroll bar`
- older collapsed entries as shortened original-text summaries
- the latest entry still rendered with full English and Chinese

This means collapsed mode has regained scrollable history.

However, user review still judged the result insufficient because the newest Chinese line was not yet clearly "complete enough" in the current visual balance.

Therefore the workstream should still be considered **open**, not complete.

## 4. Key Root Cause Timeline

### 4.1 Original bug root cause

The investigation established:

- `scrollSyncKey`, `translationRevision`, `translationUpdated` resync, `isAtBottom`, and AppKit catch-up scrolling could all be firing correctly
- the deeper issue was the collapsed surface's rendering contract
- extremely long finalized history in a very small viewport prevented the newest translated line from becoming the visible focus

### 4.2 Why collapsed mode initially stopped scrolling

That was not a broken `AppKitScrollView`.

It was because collapsed mode had been changed to render only the latest finalized item:

- helper returned just the latest item
- the view also only rendered the latest item

So there was often no real history height to scroll.

### 4.3 Why the first "restore history" fix was insufficient

The first attempt restored recent collapsed history but kept rendering old items in the same stacked flow above the newest Chinese.

That gave back scroll height, but it also reintroduced the visibility conflict:

- old content consumed vertical space
- newest Chinese no longer had a guaranteed complete viewport region

### 4.4 Current design direction

The strongest current direction is:

- collapsed mode should still expose some manual history
- but old history should not consume the same visual weight as the newest sentence
- the newest sentence must remain the primary focus region

The current implementation approximates this by:

- keeping the last three finalized collapsed items
- rendering only the newest one with full English + full Chinese
- rendering older collapsed items as reduced original-only summaries

## 5. Files Changed In This Workstream

### 5.1 Core live caption rendering

- `spoke/UI/LiveCaption/LiveCaptionView.swift`
- `spoke/UI/LiveCaption/LiveCaptionRuntimeHelpers.swift`
- `spoke/UI/LiveCaption/CaptionItemView.swift`
- `spoke/UI/LiveCaption/AppKitScrollView.swift`
- `spoke/UI/LiveCaption/AppKitScrollViewRuntimeHelpers.swift`
- `spoke/UI/LiveCaption/LiveCaptionWindow.swift`

### 5.2 Live caption data / manager side

- `spoke/Core/LiveCaption/CaptionLineBuffer.swift`
- `spoke/Core/LiveCaption/LiveCaptionManager.swift`
- `spoke/Core/LiveCaption/LiveCaptionDebugSimulationRuntimeHelpers.swift`
- `spoke/Core/LiveCaption/LiveCaptionTranscriber.swift`

### 5.3 App bootstrap / verification chain

- `spoke/App/AppDelegate.swift`
- `spoke/App/AppRuntimeHelpers.swift`
- `spoke/App/AppLifecyclePlan.swift`
- `spoke/Core/Debug/DebugAutomationTriggerService.swift`
- `spoke/scripts/dev-run.sh`

### 5.4 Overlay isolation related

- `spoke/App/AppScreenshotRuntime.swift`
- `spoke/App/AppPinnedTextRuntime.swift`
- `spoke/Core/Screenshot/ScreenshotManager.swift`
- `spoke/Core/DesktopText/PinnedTextManager.swift`
- `spoke/Core/DesktopText/PinnedTextManagerLiveDependencies.swift`

## 6. Test Files Added / Touched

- `spoke/Tests/LiveCaptionRuntimeHelpersTests.swift`
- `spoke/Tests/LiveCaptionDebugSimulationRuntimeHelpersTests.swift`
- `spoke/Tests/AppKitScrollViewRuntimeHelpersTests.swift`
- `spoke/Tests/CaptionLineBufferTests.swift`
- `spoke/Tests/AppLifecyclePlanTests.swift`
- `spoke/Tests/AppRuntimeHelpersTests.swift`
- `spoke/Tests/LiveCaptionBottomProbeRuntimeHelpersTests.swift`

## 7. Commands That Were Used Successfully

### 7.1 Build and verification

Run from `spoke/` unless otherwise noted.

```bash
swift build
swift test
swift test --filter LiveCaptionRuntimeHelpersTests
swift test --filter LiveCaptionDebugSimulationRuntimeHelpersTests
swift test --filter AppKitScrollViewRuntimeHelpersTests
swift test --filter AppLifecyclePlanTests
swift test --filter AppRuntimeHelpersTests
bash Tests/run-concurrency-check.sh
```

### 7.2 Mock launch / visual verification

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke
SPOKE_DEBUG_LIVECAPTION_SCENARIO=long_translation ./dev.sh
```

Important current behavior:

- `./dev.sh` in open mode writes `/tmp/spoke-livecaption-mock-scenario.txt`
- the installed app then bootstraps the mock scene from that file

## 8. Things A New Session Should Not Re-Debug First

Do **not** restart from these topics unless new evidence directly points there:

1. stale bundler app vs installed app mismatch
2. `exec` mode env propagation
3. overlay restore pollution from screenshot / pinned text
4. the old strict concurrency warning on `AppDebugLaunchContext`
5. whether `AppKitScrollView` is globally broken

These were all already narrowed or fixed.

## 9. Current Open Question

The open design question is now very specific:

> What collapsed-mode rendering contract best satisfies BOTH:
>
> 1. manual history scrolling in default collapsed mode
> 2. newest Chinese translation fully visible and visually prioritized

The current candidate implementation is close, but not yet considered accepted.

## 10. Recommended Next Step

Resume directly from collapsed-mode contract tuning in `LiveCaptionView.swift`.

Suggested sequence:

1. launch the real mock window with:

   ```bash
   cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke
   SPOKE_DEBUG_LIVECAPTION_SCENARIO=long_translation ./dev.sh
   ```

2. inspect the real `ui.live-caption.window`

3. evaluate whether the current "older original-only summary + latest full item" contract is visually sufficient

4. if not, continue only in the collapsed rendering layer, for example by exploring:
   - fewer old summary rows
   - more aggressive line limits on old summaries
   - a dedicated visual split between history summary and current focus block

5. do **not** revert to:
   - full old Chinese history in collapsed mode
   - latest-only with no scrollable history

The next win should come from improving the collapsed visual contract, not from going back down into environment or event-propagation debugging.
