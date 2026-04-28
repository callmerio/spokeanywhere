# Live Caption Collapsed Visibility Anchor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:super-40-subagent-driven-development (recommended) or superpowers:super-41-executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep collapsed live caption visually aligned with the expanded stacked style while making the newest Chinese translation the default visible focus in long-translation scenarios.

**Architecture:** Add a narrow collapsed-focus geometry helper layer rather than redesigning the view hierarchy. Keep `collapsedContent` and `expandedContent` structurally aligned, but teach the collapsed scroll pipeline to reveal the newest Chinese translation block instead of blindly pinning the document bottom; back that with richer probe logging that works in the trusted `open` launch path.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit `NSScrollView` bridge, existing live-caption mock bootstrap, Swift Testing, `swift build`, `swift test`, `bash Tests/run-concurrency-check.sh`

---

## File Map

### New helper + tests

- Create: `spoke/UI/LiveCaption/LiveCaptionCollapsedFocusRuntimeHelpers.swift`
  - Pure collapsed-focus target selection and viewport/target delta math.
- Create: `spoke/Tests/LiveCaptionCollapsedFocusRuntimeHelpersTests.swift`
  - Pure geometry tests for full reveal vs oversized translation alignment.

### Existing live-caption runtime files

- Modify: `spoke/UI/LiveCaption/LiveCaptionView.swift`
  - Keep collapsed layout visually identical to expanded stacking, but compute and dispatch collapsed focus-adjustment requests from probe snapshots.
- Modify: `spoke/UI/LiveCaption/LiveCaptionViewState.swift`
  - Add collapsed-focus pin state and pending explicit scroll-adjustment request.
- Modify: `spoke/UI/LiveCaption/AppKitScrollView.swift`
  - Support explicit delta-based scroll requests and a callback that clears collapsed focus pin on manual upward scroll.
- Modify: `spoke/UI/LiveCaption/AppKitScrollViewRuntimeHelpers.swift`
  - Add request type and resolved-origin helper for explicit scroll adjustments.
- Modify: `spoke/UI/LiveCaption/LiveCaptionBottomProbeRuntimeHelpers.swift`
  - Add richer collapsed probe output and probe bootstrap-file fallback so `open` launches can emit geometry logs.
- Modify: `spoke/UI/LiveCaption/LiveCaptionRuntimeHelpers.swift`
  - Keep recent-tail logic; add collapsed auto-scroll gating that respects collapsed focus pin.

### Existing debug-launch + tests

- Modify: `spoke/scripts/dev-run.sh`
  - Write/clear the probe bootstrap file in both `open` and `exec` flows, and pass `SPOKE_DEBUG_LIVECAPTION_PROBE` through `exec`.
- Modify: `spoke/Tests/LiveCaptionBottomProbeRuntimeHelpersTests.swift`
  - Add probe bootstrap-file coverage.
- Modify: `spoke/Tests/AppKitScrollViewRuntimeHelpersTests.swift`
  - Add explicit delta scroll-origin clamp coverage.
- Modify: `spoke/Tests/LiveCaptionRuntimeHelpersTests.swift`
  - Add collapsed auto-scroll gating coverage.

### Reference docs

- Reference: `docs/superpowers/specs/2026-04-21-live-caption-handoff.md`
- Reference: `spoke/UI/LiveCaption/LiveCaptionView.swift`
- Reference: `spoke/UI/LiveCaption/AppKitScrollView.swift`

---

## Scope Lock

This plan implements only the user-approved contract:

1. `collapsed` keeps the same stacked visual style as `expanded`
2. collapsed height stays at the current product size
3. old finalized items remain full English + Chinese blocks; no summary layout, no section titles
4. default collapsed focus may hide older items completely if needed to make the newest Chinese the visible focus
5. if the newest Chinese block itself is taller than the viewport, default alignment is to the Chinese block’s end

This plan does **not**:

1. reintroduce `最近历史` / `当前句子` sectioning
2. add history count product limits beyond the existing recent-tail helper
3. raise collapsed height as the primary fix
4. change expanded-mode layout
5. redesign the mock scenario content

---

### Task 1: Lock the collapsed-focus geometry and probe bootstrap semantics with red tests

**Files:**
- Create: `spoke/Tests/LiveCaptionCollapsedFocusRuntimeHelpersTests.swift`
- Modify: `spoke/Tests/LiveCaptionBottomProbeRuntimeHelpersTests.swift`
- Modify: `spoke/Tests/AppKitScrollViewRuntimeHelpersTests.swift`
- Modify: `spoke/Tests/LiveCaptionRuntimeHelpersTests.swift`

- [ ] **Step 1: Add pure collapsed-focus geometry tests**

Create `spoke/Tests/LiveCaptionCollapsedFocusRuntimeHelpersTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import SpokenAnyWhere

@Suite("LiveCaptionCollapsedFocusRuntimeHelpers 测试")
struct LiveCaptionCollapsedFocusRuntimeHelpersTests {

    @Test("pending translation 优先作为 collapsed 焦点")
    func pendingTranslationWinsOverFinalized() {
        let viewport = LiveCaptionProbeSnapshot(
            slot: .viewportCollapsed,
            frame: CGRect(x: 0, y: 0, width: 300, height: 220),
            textLength: 0
        )
        let pending = LiveCaptionProbeSnapshot(
            slot: .pendingCollapsed,
            frame: CGRect(x: 0, y: 170, width: 280, height: 30),
            textLength: 24
        )
        let finalized = LiveCaptionProbeSnapshot(
            slot: .finalizedCollapsed,
            frame: CGRect(x: 0, y: 130, width: 280, height: 60),
            textLength: 88
        )

        let target = liveCaptionCollapsedPreferredTarget(
            viewport: viewport,
            pending: pending,
            finalized: finalized
        )

        #expect(target?.kind == .pendingTranslation)
        #expect(target?.targetFrame == pending.frame)
    }

    @Test("可放下的最新中文应被完整露出")
    func fittingTargetRequestsFullReveal() {
        let viewport = CGRect(x: 0, y: 0, width: 300, height: 200)
        let target = CGRect(x: 0, y: 150, width: 280, height: 40)

        #expect(liveCaptionCollapsedScrollDelta(viewportFrame: viewport, targetFrame: target) == 30)
    }

    @Test("超高中文默认对齐结尾而不是强行显示顶部")
    func oversizedTargetAnchorsToBottomEdge() {
        let viewport = CGRect(x: 0, y: 0, width: 300, height: 200)
        let target = CGRect(x: 0, y: 40, width: 280, height: 260)

        #expect(liveCaptionCollapsedScrollDelta(viewportFrame: viewport, targetFrame: target) == 100)
    }

    @Test("目标已经完整可见时不再请求额外滚动")
    func fullyVisibleTargetNeedsNoAdjustment() {
        let viewport = CGRect(x: 0, y: 0, width: 300, height: 220)
        let target = CGRect(x: 0, y: 120, width: 280, height: 60)

        #expect(liveCaptionCollapsedScrollDelta(viewportFrame: viewport, targetFrame: target) == 0)
    }
}
```

- [ ] **Step 2: Add a failing probe bootstrap-file test**

Append to `spoke/Tests/LiveCaptionBottomProbeRuntimeHelpersTests.swift`:

```swift
    @Test("probe 可从 bootstrap 文件启用，供 open 模式验收使用")
    func probeCanBeEnabledFromBootstrapFile() throws {
        try "1".write(
            toFile: liveCaptionProbeBootstrapFilePath,
            atomically: true,
            encoding: .utf8
        )
        defer {
            try? FileManager.default.removeItem(atPath: liveCaptionProbeBootstrapFilePath)
        }

        #expect(liveCaptionProbeIsEnabled([:]))
    }
```

- [ ] **Step 3: Add a failing explicit-scroll clamp test**

Append to `spoke/Tests/AppKitScrollViewRuntimeHelpersTests.swift`:

```swift
    @Test("显式 delta 滚动请求会被限制在合法范围内")
    func explicitScrollAdjustmentClampsToRange() {
        #expect(
            appKitScrollResolvedOrigin(
                currentY: 408,
                deltaY: 40,
                maxScrollY: 400,
                extraOffset: 8
            ) == 408
        )
        #expect(
            appKitScrollResolvedOrigin(
                currentY: 408,
                deltaY: -60,
                maxScrollY: 400,
                extraOffset: 8
            ) == 348
        )
        #expect(
            appKitScrollResolvedOrigin(
                currentY: 15,
                deltaY: -30,
                maxScrollY: 400,
                extraOffset: 8
            ) == 0
        )
    }
```

- [ ] **Step 4: Add a failing collapsed-focus gating test**

Append to `spoke/Tests/LiveCaptionRuntimeHelpersTests.swift`:

```swift
    @Test("collapsed 焦点 pin 打开时即使不在 document bottom 也继续允许自动跟随")
    func collapsedFocusPinKeepsAutoScrollAlive() {
        #expect(
            liveCaptionShouldAutoScrollCollapsed(
                isAtBottom: false,
                isFocusPinned: true,
                isUserSelecting: false
            )
        )
        #expect(
            !liveCaptionShouldAutoScrollCollapsed(
                isAtBottom: false,
                isFocusPinned: false,
                isUserSelecting: false
            )
        )
    }
```

- [ ] **Step 5: Run red tests**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && \
swift test --filter LiveCaptionCollapsedFocusRuntimeHelpersTests && \
swift test --filter LiveCaptionBottomProbeRuntimeHelpersTests && \
swift test --filter AppKitScrollViewRuntimeHelpersTests && \
swift test --filter LiveCaptionRuntimeHelpersTests
```

Expected:

- `LiveCaptionCollapsedFocusRuntimeHelpersTests` FAIL because helper file does not exist yet
- probe bootstrap test FAIL because `liveCaptionProbeBootstrapFilePath` does not exist yet
- explicit-scroll clamp test FAIL because `appKitScrollResolvedOrigin` does not exist yet
- collapsed-focus gating test FAIL because `liveCaptionShouldAutoScrollCollapsed` does not exist yet

- [ ] **Step 6: Commit the red tests**

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && \
git add \
  spoke/Tests/LiveCaptionCollapsedFocusRuntimeHelpersTests.swift \
  spoke/Tests/LiveCaptionBottomProbeRuntimeHelpersTests.swift \
  spoke/Tests/AppKitScrollViewRuntimeHelpersTests.swift \
  spoke/Tests/LiveCaptionRuntimeHelpersTests.swift && \
git commit -m "test: lock collapsed focus anchor semantics"
```

### Task 2: Implement pure collapsed-focus helpers and explicit scroll-request math

**Files:**
- Create: `spoke/UI/LiveCaption/LiveCaptionCollapsedFocusRuntimeHelpers.swift`
- Modify: `spoke/UI/LiveCaption/AppKitScrollViewRuntimeHelpers.swift`
- Modify: `spoke/UI/LiveCaption/LiveCaptionRuntimeHelpers.swift`
- Test: `spoke/Tests/LiveCaptionCollapsedFocusRuntimeHelpersTests.swift`
- Test: `spoke/Tests/AppKitScrollViewRuntimeHelpersTests.swift`
- Test: `spoke/Tests/LiveCaptionRuntimeHelpersTests.swift`

- [ ] **Step 1: Create the collapsed-focus helper file**

Create `spoke/UI/LiveCaption/LiveCaptionCollapsedFocusRuntimeHelpers.swift`:

```swift
import CoreGraphics
import Foundation

enum LiveCaptionCollapsedFocusTargetKind: Equatable {
    case pendingTranslation
    case finalizedTranslation
}

struct LiveCaptionCollapsedFocusTarget: Equatable {
    let kind: LiveCaptionCollapsedFocusTargetKind
    let viewportFrame: CGRect
    let targetFrame: CGRect
}

func liveCaptionCollapsedPreferredTarget(
    viewport: LiveCaptionProbeSnapshot?,
    pending: LiveCaptionProbeSnapshot?,
    finalized: LiveCaptionProbeSnapshot?
) -> LiveCaptionCollapsedFocusTarget? {
    guard let viewport else { return nil }

    if let pending {
        return LiveCaptionCollapsedFocusTarget(
            kind: .pendingTranslation,
            viewportFrame: viewport.frame,
            targetFrame: pending.frame
        )
    }

    if let finalized {
        return LiveCaptionCollapsedFocusTarget(
            kind: .finalizedTranslation,
            viewportFrame: viewport.frame,
            targetFrame: finalized.frame
        )
    }

    return nil
}

func liveCaptionCollapsedTopGap(
    viewportFrame: CGRect,
    targetFrame: CGRect
) -> CGFloat {
    targetFrame.minY - viewportFrame.minY
}

func liveCaptionCollapsedBottomGap(
    viewportFrame: CGRect,
    targetFrame: CGRect
) -> CGFloat {
    targetFrame.maxY - viewportFrame.maxY
}

func liveCaptionCollapsedScrollDelta(
    viewportFrame: CGRect,
    targetFrame: CGRect
) -> CGFloat {
    if targetFrame.height > viewportFrame.height {
        return liveCaptionCollapsedBottomGap(
            viewportFrame: viewportFrame,
            targetFrame: targetFrame
        )
    }

    if targetFrame.maxY > viewportFrame.maxY {
        return liveCaptionCollapsedBottomGap(
            viewportFrame: viewportFrame,
            targetFrame: targetFrame
        )
    }

    if targetFrame.minY < viewportFrame.minY {
        return liveCaptionCollapsedTopGap(
            viewportFrame: viewportFrame,
            targetFrame: targetFrame
        )
    }

    return 0
}
```

- [ ] **Step 2: Add explicit scroll-request math to the AppKit helpers**

Update `spoke/UI/LiveCaption/AppKitScrollViewRuntimeHelpers.swift`:

```swift
import AppKit
import Foundation

struct AppKitScrollAdjustmentRequest: Equatable {
    let id: Int
    let deltaY: CGFloat
}

func appKitScrollResolvedOrigin(
    currentY: CGFloat,
    deltaY: CGFloat,
    maxScrollY: CGFloat,
    extraOffset: CGFloat
) -> CGFloat {
    let maximumY = maxScrollY + extraOffset
    return min(max(0, currentY + deltaY), maximumY)
}
```

Keep the existing helpers in the same file unchanged.

- [ ] **Step 3: Add collapsed-focus auto-scroll gating**

Update `spoke/UI/LiveCaption/LiveCaptionRuntimeHelpers.swift`:

```swift
@MainActor
func liveCaptionShouldAutoScrollCollapsed(
    isAtBottom: Bool,
    isFocusPinned: Bool,
    isUserSelecting: Bool
) -> Bool {
    (isAtBottom || isFocusPinned) && !isUserSelecting
}
```

Leave `liveCaptionShouldAutoScroll(...)` intact for generic document-bottom behavior.

- [ ] **Step 4: Run the focused helper tests**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && \
swift test --filter LiveCaptionCollapsedFocusRuntimeHelpersTests && \
swift test --filter AppKitScrollViewRuntimeHelpersTests && \
swift test --filter LiveCaptionRuntimeHelpersTests
```

Expected:

- all three test targets PASS

- [ ] **Step 5: Commit the helper layer**

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && \
git add \
  spoke/UI/LiveCaption/LiveCaptionCollapsedFocusRuntimeHelpers.swift \
  spoke/UI/LiveCaption/AppKitScrollViewRuntimeHelpers.swift \
  spoke/UI/LiveCaption/LiveCaptionRuntimeHelpers.swift \
  spoke/Tests/LiveCaptionCollapsedFocusRuntimeHelpersTests.swift \
  spoke/Tests/AppKitScrollViewRuntimeHelpersTests.swift \
  spoke/Tests/LiveCaptionRuntimeHelpersTests.swift && \
git commit -m "feat: add collapsed focus anchor helpers"
```

### Task 3: Wire collapsed focus pin and explicit reveal requests into the live-caption view + scroll bridge

**Files:**
- Modify: `spoke/UI/LiveCaption/LiveCaptionViewState.swift`
- Modify: `spoke/UI/LiveCaption/AppKitScrollView.swift`
- Modify: `spoke/UI/LiveCaption/LiveCaptionView.swift`
- Test: `spoke/Tests/LiveCaptionCollapsedFocusRuntimeHelpersTests.swift`
- Test: `spoke/Tests/AppKitScrollViewRuntimeHelpersTests.swift`

- [ ] **Step 1: Extend the collapsed scroll state**

Update `spoke/UI/LiveCaption/LiveCaptionViewState.swift`:

```swift
@Observable
final class LiveCaptionScrollState {
    var isAtBottom = true
    var scrollTrigger = 0
    var appearedItemIDs: Set<UUID> = []
    var isCollapsedFocusPinned = true
    var collapsedScrollRequest: AppKitScrollAdjustmentRequest?
}
```

- [ ] **Step 2: Teach `AppKitScrollView` to execute explicit delta requests**

Update the `AppKitScrollView` signature and initializer in `spoke/UI/LiveCaption/AppKitScrollView.swift`:

```swift
struct AppKitScrollView<Content: View>: NSViewRepresentable {
    let content: Content
    @Binding var isAtBottom: Bool
    let scrollTrigger: Int
    let scrollAdjustment: AppKitScrollAdjustmentRequest?
    let onUserScrollAway: (() -> Void)?

    init(
        isAtBottom: Binding<Bool>,
        scrollTrigger: Int,
        scrollAdjustment: AppKitScrollAdjustmentRequest? = nil,
        onUserScrollAway: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self._isAtBottom = isAtBottom
        self.scrollTrigger = scrollTrigger
        self.scrollAdjustment = scrollAdjustment
        self.onUserScrollAway = onUserScrollAway
    }
}
```

Add coordinator storage:

```swift
        var lastScrollAdjustmentID: Int = 0
        var onUserScrollAway: (() -> Void)?
```

In `updateNSView`, set the closure and execute explicit adjustment requests before the old bottom-follow branch:

```swift
        context.coordinator.onUserScrollAway = onUserScrollAway

        if let scrollAdjustment,
           scrollAdjustment.id != context.coordinator.lastScrollAdjustmentID {
            context.coordinator.lastScrollAdjustmentID = scrollAdjustment.id
            let coordinator = context.coordinator

            runAppKitScrollOnMain { [weak scrollView, weak coordinator] in
                guard let scrollView, let coordinator else { return }
                coordinator.applyScrollAdjustment(scrollAdjustment, to: scrollView)
            }
            return
        }
```

Add the coordinator method:

```swift
        func applyScrollAdjustment(
            _ request: AppKitScrollAdjustmentRequest,
            to scrollView: NSScrollView
        ) {
            guard !isScrollingProgrammatically else { return }
            guard let documentView = scrollView.documentView else { return }

            isScrollingProgrammatically = true

            if let hostingView = documentView.subviews.first {
                hostingView.needsLayout = true
                hostingView.layoutSubtreeIfNeeded()
            }
            documentView.needsLayout = true
            documentView.layoutSubtreeIfNeeded()

            let contentHeight = documentView.frame.height
            let clipHeight = scrollView.contentView.bounds.height
            let currentY = scrollView.contentView.bounds.origin.y
            guard let metrics = appKitScrollTargetMetrics(
                contentHeight: contentHeight,
                clipHeight: clipHeight,
                extraOffset: CaptionDesign.scrollExtraOffset
            ) else {
                isScrollingProgrammatically = false
                return
            }

            let targetY = appKitScrollResolvedOrigin(
                currentY: currentY,
                deltaY: request.deltaY,
                maxScrollY: metrics.maxScrollY,
                extraOffset: CaptionDesign.scrollExtraOffset
            )

            scrollView.contentView.scroll(to: NSPoint(x: 0, y: targetY))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            lastScrollY = targetY
            lastMaxScrollY = metrics.maxScrollY

            scheduleAppKitScrollMain(after: 0.02) {
                self.isScrollingProgrammatically = false
            }
        }
```

In `scrollViewDidScroll`, clear the collapsed focus pin only on real user upward movement:

```swift
            if !isScrollingProgrammatically &&
                appKitScrollUserScrolledAwayFromBottom(
                    currentY: scrollY,
                    lastScrollY: lastScrollY
                ) {
                onUserScrollAway?()
            }
```

- [ ] **Step 3: Compute collapsed focus requests from probe snapshots without changing the stacked layout**

Update the collapsed `AppKitScrollView` call inside `spoke/UI/LiveCaption/LiveCaptionView.swift`:

```swift
                AppKitScrollView(
                    isAtBottom: isAtBottomBinding,
                    scrollTrigger: scrollState.scrollTrigger,
                    scrollAdjustment: scrollState.collapsedScrollRequest,
                    onUserScrollAway: {
                        if scrollState.isCollapsedFocusPinned {
                            scrollState.isCollapsedFocusPinned = false
                        }
                    }
                ) {
```

Keep the existing `ForEach(collapsedItems)` stacked content intact. Do **not** add section titles or summary rows.

Replace the collapsed probe handler with a geometry-driven request calculation:

```swift
#if DEBUG
                .liveCaptionProbeFrame(slot: .viewportCollapsed)
                .onPreferenceChange(LiveCaptionProbePreferenceKey.self) { snapshots in
                    liveCaptionLogBottomProbe(
                        mode: "collapsed",
                        snapshots: snapshots,
                        isAtBottom: scrollState.isAtBottom,
                        isUserSelecting: interactionState.isUserSelecting,
                        scrollTrigger: scrollState.scrollTrigger
                    )

                    let target = liveCaptionCollapsedPreferredTarget(
                        viewport: snapshots[.viewportCollapsed],
                        pending: snapshots[.pendingCollapsed],
                        finalized: snapshots[.finalizedCollapsed]
                    )

                    guard let target else { return }
                    guard liveCaptionShouldAutoScrollCollapsed(
                        isAtBottom: scrollState.isAtBottom,
                        isFocusPinned: scrollState.isCollapsedFocusPinned,
                        isUserSelecting: interactionState.isUserSelecting
                    ) else {
                        return
                    }

                    let delta = liveCaptionCollapsedScrollDelta(
                        viewportFrame: target.viewportFrame,
                        targetFrame: target.targetFrame
                    )

                    guard abs(delta) > 1 else { return }
                    let nextID = (scrollState.collapsedScrollRequest?.id ?? 0) + 1
                    scrollState.collapsedScrollRequest = AppKitScrollAdjustmentRequest(
                        id: nextID,
                        deltaY: delta
                    )
                }
#endif
```

Also re-enable the pin when the user returns to real document bottom or re-enters collapsed mode:

```swift
        .onChange(of: scrollState.isAtBottom) { _, atBottom in
            guard !interactionState.isExpanded else { return }
            if atBottom {
                scrollState.isCollapsedFocusPinned = true
            }
        }
        .onChange(of: interactionState.isExpanded) { _, isExpanded in
            if !isExpanded {
                scrollState.isCollapsedFocusPinned = true
            }
        }
```

Finally, change the collapsed `scrollSyncKey` branch to keep firing while focus is pinned even if document-bottom is no longer visible:

```swift
                .onChange(of: scrollSyncKey) { _, _ in
                    guard liveCaptionShouldAutoScrollCollapsed(
                        isAtBottom: scrollState.isAtBottom,
                        isFocusPinned: scrollState.isCollapsedFocusPinned,
                        isUserSelecting: interactionState.isUserSelecting
                    ) else {
                        return
                    }
                    scrollState.scrollTrigger += 1
                }
```

- [ ] **Step 4: Run the focused view/scroll checks**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && \
swift test --filter LiveCaptionCollapsedFocusRuntimeHelpersTests && \
swift test --filter AppKitScrollViewRuntimeHelpersTests && \
swift build
```

Expected:

- helper tests PASS
- `swift build` PASS

- [ ] **Step 5: Commit the collapsed-focus wiring**

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && \
git add \
  spoke/UI/LiveCaption/LiveCaptionViewState.swift \
  spoke/UI/LiveCaption/AppKitScrollView.swift \
  spoke/UI/LiveCaption/LiveCaptionView.swift && \
git commit -m "feat: anchor collapsed captions to latest chinese block"
```

### Task 4: Make probe logging available in the trusted `open` flow and verify the full contract

**Files:**
- Modify: `spoke/UI/LiveCaption/LiveCaptionBottomProbeRuntimeHelpers.swift`
- Modify: `spoke/scripts/dev-run.sh`
- Modify: `spoke/Tests/LiveCaptionBottomProbeRuntimeHelpersTests.swift`
- Test: `spoke/Tests/LiveCaptionCollapsedFocusRuntimeHelpersTests.swift`
- Test: `spoke/Tests/AppKitScrollViewRuntimeHelpersTests.swift`

- [ ] **Step 1: Implement probe bootstrap fallback and richer logs**

Update `spoke/UI/LiveCaption/LiveCaptionBottomProbeRuntimeHelpers.swift`:

```swift
private let liveCaptionProbeBootstrapFilePath = "/tmp/spoke-livecaption-probe-enabled.txt"

private func liveCaptionProbeFlag(
    from raw: String?
) -> Bool? {
    guard let raw = raw?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased(),
          !raw.isEmpty else {
        return nil
    }

    switch raw {
    case "1", "true", "yes", "on":
        return true
    case "0", "false", "no", "off":
        return false
    default:
        return nil
    }
}

private func liveCaptionProbeEnabledFromBootstrapFile(
    fileManager: FileManager = .default
) -> Bool {
    guard fileManager.fileExists(atPath: liveCaptionProbeBootstrapFilePath),
          let raw = try? String(
            contentsOfFile: liveCaptionProbeBootstrapFilePath,
            encoding: .utf8
          ) else {
        return false
    }

    return liveCaptionProbeFlag(from: raw) == true
}

func liveCaptionProbeIsEnabled(
    _ environment: [String: String] = ProcessInfo.processInfo.environment,
    fileManager: FileManager = .default
) -> Bool {
    if let explicit = liveCaptionProbeFlag(
        from: environment[liveCaptionProbeEnabledEnvKey]
    ) {
        return explicit
    }

    return liveCaptionProbeEnabledFromBootstrapFile(fileManager: fileManager)
}
```

Expand the log payload:

```swift
    let topGap = liveCaptionCollapsedTopGap(
        viewportFrame: viewport.frame,
        targetFrame: target.frame
    )
    let fullyVisible = target.frame.minY >= viewport.frame.minY &&
        target.frame.maxY <= viewport.frame.maxY

    liveCaptionProbeLogger.debug(
        "📏 probe mode=\(mode, privacy: .public) target=\(target.slot.rawValue, privacy: .public) textLength=\(target.textLength, privacy: .public) viewportHeight=\(viewport.frame.height, privacy: .public) targetHeight=\(target.frame.height, privacy: .public) topGap=\(topGap, privacy: .public) bottomGap=\(gap, privacy: .public) fullyVisible=\(fullyVisible, privacy: .public) isAtBottom=\(isAtBottom, privacy: .public) isUserSelecting=\(isUserSelecting, privacy: .public) scrollTrigger=\(scrollTrigger, privacy: .public)"
    )
```

- [ ] **Step 2: Write probe bootstrap support into the real launch script**

Update `spoke/scripts/dev-run.sh`:

```bash
LIVE_CAPTION_PROBE_BOOTSTRAP_FILE="/tmp/spoke-livecaption-probe-enabled.txt"
```

Inside `launch_app_bundle()` handle the probe bootstrap alongside the scenario bootstrap:

```bash
  if [[ -n "${SPOKE_DEBUG_LIVECAPTION_PROBE:-}" ]]; then
    log_info "写入 live caption probe bootstrap: ${SPOKE_DEBUG_LIVECAPTION_PROBE}"
    if [[ "$DRY_RUN" == "1" ]]; then
      printf '[DRY-RUN] %q > %q\n' "${SPOKE_DEBUG_LIVECAPTION_PROBE}" "$LIVE_CAPTION_PROBE_BOOTSTRAP_FILE"
    else
      printf '%s\n' "${SPOKE_DEBUG_LIVECAPTION_PROBE}" > "$LIVE_CAPTION_PROBE_BOOTSTRAP_FILE"
    fi
  else
    run_cmd rm -f "$LIVE_CAPTION_PROBE_BOOTSTRAP_FILE"
  fi
```

Also pass it through the `exec` branch:

```bash
        SPOKE_DEBUG_LIVECAPTION_PROBE="${SPOKE_DEBUG_LIVECAPTION_PROBE:-}" \
```

And update the help footer:

```bash
- 如果要启用几何 probe：SPOKE_DEBUG_LIVECAPTION_PROBE=1 SPOKE_DEBUG_LIVECAPTION_SCENARIO=long_translation ./dev.sh
```

- [ ] **Step 3: Run targeted tests for probe enablement**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && \
swift test --filter LiveCaptionBottomProbeRuntimeHelpersTests
```

Expected:

- `LiveCaptionBottomProbeRuntimeHelpersTests` PASS, including the bootstrap-file case

- [ ] **Step 4: Run full verification**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && \
swift build && \
swift test && \
bash Tests/run-concurrency-check.sh
```

Expected:

- `swift build` PASS
- `swift test` PASS
- strict concurrency check PASS with `0 warnings`

- [ ] **Step 5: Run the real acceptance flow**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && \
SPOKE_DEBUG_LIVECAPTION_PROBE=1 \
SPOKE_DEBUG_LIVECAPTION_SCENARIO=long_translation \
./dev.sh
```

Then inspect the newest log:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && \
LATEST=$(ls -1t .tmp_frames/dev-*.log | head -n 1) && \
echo "$LATEST" && \
rg "probe mode=collapsed|fullyVisible|topGap|bottomGap" "$LATEST" | tail -n 40
```

Expected:

- log contains `probe mode=collapsed`
- latest target is `pendingCollapsed` or `finalizedCollapsed`
- `fullyVisible=true` whenever the newest Chinese block fits in the collapsed viewport
- if `targetHeight > viewportHeight`, the log shows bottom-aligned oversized behavior instead of chasing top visibility

Perform the visual check in the real window:

1. collapsed mode still shows the same stacked card structure as expanded mode
2. no `最近历史` / `当前句子` titles appear
3. default collapsed view may show only the newest sentence block
4. manual upward scroll still reveals older full bilingual items
5. returning to bottom restores the newest Chinese focus

- [ ] **Step 6: Commit the probe/bootstrap and final verification pass**

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && \
git add \
  spoke/UI/LiveCaption/LiveCaptionBottomProbeRuntimeHelpers.swift \
  spoke/scripts/dev-run.sh \
  spoke/Tests/LiveCaptionBottomProbeRuntimeHelpersTests.swift && \
git commit -m "feat: expose collapsed probe diagnostics in open flow"
```

---

## Self-Review

### Spec coverage

- `collapsed` 保持 expanded 同构样式：Task 3 明确要求保留 `ForEach(collapsedItems)` 堆叠结构，不再引入 section title
- 当前高度不变：Task 3 明确不改 `collapsed` 高度，仅改默认焦点滚动目标
- 旧句不做摘要化：Task 3 明确保留现有 bilingual blocks
- 最新中文完整可见：Task 2 + Task 3 通过纯几何 helper 和显式 delta 请求实现
- 超高中文对齐结尾：Task 2 的 `liveCaptionCollapsedScrollDelta(...)` 明确锁定
- trusted `open` flow 下可调试：Task 4 通过 bootstrap-file fallback + `dev-run.sh` 处理

### Placeholder scan

- 无 `TODO` / `TBD`
- 每个代码步骤都给出具体代码
- 每个验证步骤都给出精确命令和预期结果

### Type consistency

- helper type names统一为 `LiveCaptionCollapsedFocus*`
- 显式滚动请求统一为 `AppKitScrollAdjustmentRequest`
- probe bootstrap 路径统一为 `liveCaptionProbeBootstrapFilePath`

