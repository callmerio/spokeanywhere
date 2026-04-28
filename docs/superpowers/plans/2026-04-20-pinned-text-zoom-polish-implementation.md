# PinnedText Zoom Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:super-40-subagent-driven-development (recommended) or superpowers:super-41-executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `PinnedText` hover zoom feel more direct and natural while keeping width and height visually proportional even when content overflows and requires scrolling.

**Architecture:** Separate zoom polish into two explicit layers: a geometry layer that computes one uniform viewport scale regardless of content overflow amount, and a dynamics layer that turns wheel deltas into responsive preview motion plus short post-gesture inertia. Keep `PinnedTextWindow` as the event router, but stop using raw `preferredWindowSize(text:zoom:)` as the direct preview/commit geometry source for scrollable content.

**Tech Stack:** Swift 5.9, AppKit `NSPanel` / `NSView`, `PinnedTextWindow`, `PinnedTextContentView`, `PinnedTextMarkdownRenderer`, Swift Testing, `swift test`, `swift build`

---

## Scope And Assumptions

This plan covers two user-reported problems in the same interaction surface:

1. `跟手性 / 惯性`
   - preview zoom currently feels slightly slow and stops too abruptly
2. `scrollable content 下的非等比缩放`
   - if content overflows only a little, the window currently stretches height first and only then behaves proportionally
   - if content is very long and hits the height cap, width keeps changing while height stays pinned, so the card no longer looks like one uniformly scaled object

This plan makes one explicit product assumption:

- Hover-unfocused zoom should visually behave like scaling a single viewport/card object.
- Overflow amount may change how much content is scrollable inside the card, but must not change the rule that the visible card scales with one uniform factor.

This means the zoom pipeline will shift from:

```text
zoomLevel -> renderer preferred size -> maybe capped height -> frame
```

to:

```text
zoomLevel delta -> viewport scale ratio -> proportional preview/commit frame
                         │
                         └─ preview text rerendered at the same preview zoom
```

## File Map

### Core implementation files

- Modify: `spoke/UI/DesktopText/PinnedTextWindow.swift`
  - Replace the current preview/commit geometry path with a proportional viewport-scaling path.
  - Add inertia lifecycle ownership and cancellation rules.
- Modify: `spoke/UI/DesktopText/PinnedTextContentView.swift`
  - Keep preview text rerendering tied to preview zoom.
  - Add any small preview viewport hooks needed by tests.
- Modify: `spoke/UI/DesktopText/PinnedTextMarkdownRenderer.swift`
  - Keep typography and text measurement helpers.
  - Stop treating `preferredWindowSize` as the only geometry answer for hover zoom.
- Create: `spoke/UI/DesktopText/PinnedTextZoomGeometry.swift`
  - Pure geometry helper for uniform viewport scaling and cap handling.
- Create: `spoke/UI/DesktopText/PinnedTextZoomDynamics.swift`
  - Pure helper for wheel velocity smoothing and inertia decay.

### Tests

- Modify: `spoke/Tests/PinnedTextWindowStateTests.swift`
  - Add regression coverage for the two overflow classes and inertia-visible behavior.
- Create: `spoke/Tests/PinnedTextZoomGeometryTests.swift`
  - Add pure tests for proportional scaling under normal, lightly overflowing, and heavily overflowing content.
- Create: `spoke/Tests/PinnedTextZoomDynamicsTests.swift`
  - Add pure tests for velocity accumulation, decay, and stop thresholds.
- Modify: `spoke/Tests/AppPinnedTextRuntimeTests.swift`
  - Keep runtime frame propagation covered if commit semantics change from `preferredWindowSize` to proportional viewport geometry.

### Reference docs

- Reference: `docs/superpowers/specs/2026-04-19-pinned-text-hover-zoom-design.md`
- Reference: `docs/superpowers/plans/2026-04-19-pinned-text-hover-zoom-implementation.md`

---

## Design Delta From The Previous Plan

The previous hover-zoom plan intentionally tied preview frame sizing to:

```swift
PinnedTextMarkdownRenderer.preferredWindowSize(text: item.text, zoomLevel: zoom)
```

That was good enough to separate preview from committed zoom, but it still lets text reflow decide visible card aspect.

This follow-up plan changes that rule:

1. compute `zoomRatio = previewZoom / committedZoom`
2. scale the committed viewport frame by `zoomRatio`
3. clamp with one uniform factor when hitting viewport limits
4. rerender preview text at `previewZoom`
5. keep overflow scrollability inside the card instead of changing aspect-ratio semantics

That is the only way to make these three cases share one rule:

```text
[ case A ] content fits already
    -> proportional viewport scaling

[ case B ] content overflows a little
    -> proportional viewport scaling
    -> overflow amount changes, but card aspect does not jump first

[ case C ] content overflows a lot and hits max height
    -> viewport uses a uniform clamp factor
    -> width and height stop/change together rather than width-only drift
```

---

### Task 1: Lock the new geometry semantics with failing tests

**Files:**
- Modify: `spoke/Tests/PinnedTextWindowStateTests.swift`
- Create: `spoke/Tests/PinnedTextZoomGeometryTests.swift`
- Reference: `spoke/UI/DesktopText/PinnedTextWindow.swift`
- Reference: `spoke/UI/DesktopText/PinnedTextMarkdownRenderer.swift`

- [ ] **Step 1: Add failing window tests for the two overflow classes**

Add these tests to `spoke/Tests/PinnedTextWindowStateTests.swift` near the existing preview-zoom block:

```swift
    @Test("lightly overflowing content zoom keeps viewport scaling proportional instead of stretching height first")
    func lightlyOverflowingContentZoomKeepsViewportScalingProportional() throws {
        let text = makeScrollablePreviewText(lineCount: 24)
        let (window, _) = makeWindow(
            text: text,
            frame: CGRect(x: 0, y: 0, width: 300, height: 150)
        )
        let content = try #require(window.pinnedTextContentView)
        prepareContentForInteraction(content, in: window)

        let committedFrame = CGRect(x: 0, y: 0, width: 300, height: 150)
        window.setFrame(committedFrame, display: true)
        window.item.frame = committedFrame

        content.mouseEntered(with: try makeMouseEvent(
            window: window,
            type: .mouseEntered,
            location: CGPoint(x: 80, y: 80),
            clickCount: 0
        ))

        window.scrollWheel(with: try makeScrollEvent(deltaY: 30, precise: true))
        let previewFrame = window.frame

        let widthScale = previewFrame.width / committedFrame.width
        let heightScale = previewFrame.height / committedFrame.height

        #expect(abs(widthScale - heightScale) <= 0.02)
    }

    @Test("heavily overflowing content at max height does not degrade into width-only zoom")
    func heavilyOverflowingContentAtMaxHeightDoesNotDegradeIntoWidthOnlyZoom() throws {
        let text = makeScrollablePreviewText(lineCount: 120)
        let (window, _) = makeWindow(
            text: text,
            frame: CGRect(x: 0, y: 0, width: 320, height: 220)
        )
        let content = try #require(window.pinnedTextContentView)
        prepareContentForInteraction(content, in: window)

        content.mouseEntered(with: try makeMouseEvent(
            window: window,
            type: .mouseEntered,
            location: CGPoint(x: 80, y: 80),
            clickCount: 0
        ))

        let committedFrame = window.frame
        for _ in 0..<8 {
            window.scrollWheel(with: try makeScrollEvent(deltaY: 30, precise: true))
        }

        let previewFrame = window.frame
        let widthScale = previewFrame.width / committedFrame.width
        let heightScale = previewFrame.height / committedFrame.height

        #expect(abs(widthScale - heightScale) <= 0.02)
    }
```

- [ ] **Step 2: Add failing pure geometry tests**

Create `spoke/Tests/PinnedTextZoomGeometryTests.swift`:

```swift
import AppKit
import Testing
@testable import SpokenAnyWhere

@Suite("PinnedTextZoomGeometry tests")
@MainActor
struct PinnedTextZoomGeometryTests {
    @Test("uniform clamp keeps width and height on the same scale factor")
    func uniformClampKeepsWidthAndHeightOnSameScaleFactor() {
        let base = CGSize(width: 300, height: 150)
        let scaled = PinnedTextZoomGeometry.scaledViewportSize(
            baseViewport: base,
            zoomRatio: 2.0,
            minimumSize: CGSize(width: 220, height: 120),
            maximumSize: CGSize(width: 760, height: 540)
        )

        #expect(abs((scaled.width / base.width) - (scaled.height / base.height)) <= 0.0001)
    }

    @Test("minimum clamp also preserves a single scale factor")
    func minimumClampAlsoPreservesSingleScaleFactor() {
        let base = CGSize(width: 320, height: 240)
        let scaled = PinnedTextZoomGeometry.scaledViewportSize(
            baseViewport: base,
            zoomRatio: 0.3,
            minimumSize: CGSize(width: 220, height: 120),
            maximumSize: CGSize(width: 760, height: 540)
        )

        #expect(abs((scaled.width / base.width) - (scaled.height / base.height)) <= 0.0001)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail against the current implementation**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && \
swift test --filter PinnedTextWindowStateTests && \
swift test --filter PinnedTextZoomGeometryTests
```

Expected:

- `PinnedTextWindowStateTests` fails because preview sizing is still derived from renderer preferred size
- `PinnedTextZoomGeometryTests` fails because the helper does not exist yet

- [ ] **Step 4: Commit the red tests**

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && \
git add \
  spoke/Tests/PinnedTextWindowStateTests.swift \
  spoke/Tests/PinnedTextZoomGeometryTests.swift && \
git commit -m "test: lock pinned text zoom geometry semantics"
```

### Task 2: Introduce a pure geometry helper for proportional viewport scaling

**Files:**
- Create: `spoke/UI/DesktopText/PinnedTextZoomGeometry.swift`
- Create: `spoke/Tests/PinnedTextZoomGeometryTests.swift`
- Modify: `spoke/UI/DesktopText/PinnedTextWindow.swift`

- [ ] **Step 1: Create the pure geometry helper**

Create `spoke/UI/DesktopText/PinnedTextZoomGeometry.swift`:

```swift
import CoreGraphics

@MainActor
enum PinnedTextZoomGeometry {
    static func scaledViewportSize(
        baseViewport: CGSize,
        zoomRatio: CGFloat,
        minimumSize: CGSize,
        maximumSize: CGSize
    ) -> CGSize {
        let target = CGSize(
            width: baseViewport.width * zoomRatio,
            height: baseViewport.height * zoomRatio
        )

        let maxScale = min(
            maximumSize.width / max(target.width, 0.0001),
            maximumSize.height / max(target.height, 0.0001),
            1.0
        )
        let minScale = max(
            minimumSize.width / max(target.width, 0.0001),
            minimumSize.height / max(target.height, 0.0001),
            1.0
        )

        let factor: CGFloat
        if target.width > maximumSize.width || target.height > maximumSize.height {
            factor = maxScale
        } else if target.width < minimumSize.width || target.height < minimumSize.height {
            factor = minScale
        } else {
            factor = 1.0
        }

        return CGSize(
            width: target.width * factor,
            height: target.height * factor
        )
    }
}
```

- [ ] **Step 2: Replace preview frame sizing to use the geometry helper**

In `spoke/UI/DesktopText/PinnedTextWindow.swift`, replace the body of `applyPreviewZoomFrame(_:)` with:

```swift
    private func applyPreviewZoomFrame(_ zoom: Double) {
        guard let baseFrame = previewBaseFrame else { return }

        let zoomRatio = CGFloat(zoom / max(item.zoomLevel, 0.0001))
        let scaledSize = PinnedTextZoomGeometry.scaledViewportSize(
            baseViewport: baseFrame.size,
            zoomRatio: zoomRatio,
            minimumSize: minimumWindowSize,
            maximumSize: CGSize(
                width: PinnedTextMarkdownRenderer.maxContentWidth
                    + PinnedTextMarkdownRenderer.contentInsets.left
                    + PinnedTextMarkdownRenderer.contentInsets.right
                    + (PinnedTextMarkdownRenderer.windowGlowPadding * 2),
                height: PinnedTextMarkdownRenderer.maxWindowHeight
            )
        )
        let center = CGPoint(x: baseFrame.midX, y: baseFrame.midY)
        let nextFrame = CGRect(
            x: center.x - scaledSize.width / 2,
            y: center.y - scaledSize.height / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )

        suppressManagedFrameCallbacks = true
        setFrame(nextFrame, display: true)
        suppressManagedFrameCallbacks = false
    }
```

- [ ] **Step 3: Run geometry tests and window tests**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && \
swift test --filter PinnedTextZoomGeometryTests && \
swift test --filter PinnedTextWindowStateTests
```

Expected:

- geometry tests PASS
- window tests still FAIL on commit semantics, because commit is still falling back to `resizeToPreferredContent(animated: false)`

- [ ] **Step 4: Commit the geometry layer**

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && \
git add \
  spoke/UI/DesktopText/PinnedTextZoomGeometry.swift \
  spoke/UI/DesktopText/PinnedTextWindow.swift \
  spoke/Tests/PinnedTextZoomGeometryTests.swift \
  spoke/Tests/PinnedTextWindowStateTests.swift && \
git commit -m "feat: add pinned text proportional zoom geometry"
```

### Task 3: Make committed zoom use the same viewport geometry as preview

**Files:**
- Modify: `spoke/UI/DesktopText/PinnedTextWindow.swift`
- Modify: `spoke/Tests/PinnedTextWindowStateTests.swift`
- Modify: `spoke/Tests/AppPinnedTextRuntimeTests.swift`

- [ ] **Step 1: Add a helper that commits from the preview frame instead of re-deriving from preferred size**

In `spoke/UI/DesktopText/PinnedTextWindow.swift`, add:

```swift
    private func commitPreviewZoomUsingCurrentFrame(_ zoom: Double) {
        item.zoomLevel = zoom
        pinnedTextContentView?.refreshFromItem()
        item.frame = frame
        onFrameChanged?(frame)
        dependencies.saveWindowState()
    }
```

Then update `commitPreviewZoomIfNeeded()`:

```swift
    private func commitPreviewZoomIfNeeded() {
        guard let contentView = pinnedTextContentView,
              let previewZoom = contentView.gestureZoom else { return }

        guard abs(previewZoom - item.zoomLevel) > 0.0001 else {
            previewBaseFrame = nil
            contentView.clearPreviewZoom()
            return
        }

        previewBaseFrame = nil
        contentView.clearPreviewZoom(resetPreviewContent: false)
        commitPreviewZoomUsingCurrentFrame(previewZoom)
    }
```

- [ ] **Step 2: Add tests that commit keeps the proportional viewport**

Add to `spoke/Tests/PinnedTextWindowStateTests.swift`:

```swift
    @Test("overflowing content commit keeps the proportional preview frame instead of jumping to preferred reflow size")
    func overflowingContentCommitKeepsProportionalPreviewFrame() throws {
        let (window, _) = makeWindow(
            text: makeScrollablePreviewText(lineCount: 120),
            frame: CGRect(x: 0, y: 0, width: 320, height: 220)
        )
        let content = try #require(window.pinnedTextContentView)
        prepareContentForInteraction(content, in: window)

        content.mouseEntered(with: try makeMouseEvent(
            window: window,
            type: .mouseEntered,
            location: CGPoint(x: 80, y: 80),
            clickCount: 0
        ))

        window.scrollWheel(with: try makeScrollEvent(deltaY: 30, precise: true))
        let previewFrame = window.frame

        window.scrollWheel(with: try makeScrollEvent(deltaY: 0, precise: true, phase: .ended))

        #expect(itemFramesMatch(window.frame, previewFrame, tolerance: 0.5))
        #expect(itemFramesMatch(window.item.frame, previewFrame, tolerance: 0.5))
    }
```

- [ ] **Step 3: Keep runtime frame propagation green**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && \
swift test --filter PinnedTextWindowStateTests && \
swift test --filter AppPinnedTextRuntimeTests
```

Expected:

- both suites PASS

- [ ] **Step 4: Commit the proportional commit semantics**

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && \
git add \
  spoke/UI/DesktopText/PinnedTextWindow.swift \
  spoke/Tests/PinnedTextWindowStateTests.swift \
  spoke/Tests/AppPinnedTextRuntimeTests.swift && \
git commit -m "fix: keep pinned text zoom commit proportional"
```

### Task 4: Introduce a pure dynamics helper for follow-through and inertia

**Files:**
- Create: `spoke/UI/DesktopText/PinnedTextZoomDynamics.swift`
- Create: `spoke/Tests/PinnedTextZoomDynamicsTests.swift`
- Modify: `spoke/UI/DesktopText/PinnedTextWindow.swift`

- [ ] **Step 1: Create a small pure inertia model**

Create `spoke/UI/DesktopText/PinnedTextZoomDynamics.swift`:

```swift
import Foundation

@MainActor
struct PinnedTextZoomDynamics {
    private(set) var velocity: Double = 0

    mutating func ingest(stepDelta: Double) {
        velocity = (velocity * 0.55) + (stepDelta * 0.45)
    }

    mutating func nextDecayStep() -> Double? {
        guard abs(velocity) >= 0.002 else {
            velocity = 0
            return nil
        }

        let step = velocity
        velocity *= 0.82
        return step
    }

    mutating func reset() {
        velocity = 0
    }
}
```

- [ ] **Step 2: Add pure dynamics tests**

Create `spoke/Tests/PinnedTextZoomDynamicsTests.swift`:

```swift
import Testing
@testable import SpokenAnyWhere

@Suite("PinnedTextZoomDynamics tests")
@MainActor
struct PinnedTextZoomDynamicsTests {
    @Test("ingest accumulates wheel intent into velocity")
    func ingestAccumulatesWheelIntentIntoVelocity() {
        var dynamics = PinnedTextZoomDynamics()
        dynamics.ingest(stepDelta: 0.05)
        dynamics.ingest(stepDelta: 0.05)

        #expect(dynamics.velocity > 0.05)
    }

    @Test("nextDecayStep decays velocity to rest")
    func nextDecayStepDecaysVelocityToRest() {
        var dynamics = PinnedTextZoomDynamics()
        dynamics.ingest(stepDelta: 0.08)

        var values: [Double] = []
        while let next = dynamics.nextDecayStep() {
            values.append(next)
        }

        #expect(values.isEmpty == false)
        #expect(abs(dynamics.velocity) <= 0.002)
    }
}
```

- [ ] **Step 3: Run the dynamics tests to verify failure then pass**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && \
swift test --filter PinnedTextZoomDynamicsTests
```

Expected:

- initial FAIL before the helper exists
- PASS after adding the helper

- [ ] **Step 4: Commit the pure dynamics helper**

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && \
git add \
  spoke/UI/DesktopText/PinnedTextZoomDynamics.swift \
  spoke/Tests/PinnedTextZoomDynamicsTests.swift && \
git commit -m "feat: add pinned text zoom dynamics helper"
```

### Task 5: Wire inertia into the window preview lifecycle

**Files:**
- Modify: `spoke/UI/DesktopText/PinnedTextWindow.swift`
- Modify: `spoke/Tests/PinnedTextWindowStateTests.swift`
- Modify: `spoke/Tests/AppPinnedTextRuntimeTests.swift`

- [ ] **Step 1: Add inertia state to the window**

In `spoke/UI/DesktopText/PinnedTextWindow.swift`, add stored properties near the existing preview fields:

```swift
    private var previewDynamics = PinnedTextZoomDynamics()
    private var inertiaTimer: Timer?
```

Add cancellation:

```swift
    private func stopZoomInertia() {
        inertiaTimer?.invalidate()
        inertiaTimer = nil
        previewDynamics.reset()
    }
```

Call `stopZoomInertia()` from:

```swift
cancelPreviewZoomIfNeeded()
resignKey()
handleHorizontalScroll(_:)
beginContentInteraction(with:)
beginEditing()
enterFocusedBrowsing()
```

- [ ] **Step 2: Feed velocity during changed events and decay after gesture end**

Update `updatePreviewZoom(deltaY:)`:

```swift
    private func updatePreviewZoom(deltaY: CGFloat) {
        guard let contentView = pinnedTextContentView, deltaY != 0 else { return }

        stopZoomInertia()

        let step: Double = deltaY > 0 ? 0.05 : -0.05
        previewDynamics.ingest(stepDelta: step)

        let baseZoom = contentView.currentPreviewOrCommittedZoom()
        let nextZoom = PinnedTextMarkdownRenderer.clampedZoom(baseZoom + step)
        guard abs(nextZoom - baseZoom) > 0.0001 else { return }

        if contentView.gestureZoom == nil {
            previewBaseFrame = frame
        }
        applyPreviewZoomFrame(nextZoom)
        contentView.beginOrUpdatePreviewZoom(nextZoom)
    }
```

Add inertia kick-off:

```swift
    private func beginZoomInertiaIfNeeded() {
        guard inertiaTimer == nil else { return }
        inertiaTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else {
                    timer.invalidate()
                    return
                }
                guard let decayStep = self.previewDynamics.nextDecayStep() else {
                    timer.invalidate()
                    self.inertiaTimer = nil
                    self.commitPreviewZoomIfNeeded()
                    return
                }
                self.updatePreviewZoom(deltaY: decayStep > 0 ? 1 : -1)
            }
        }
    }
```

Then in `scrollWheel(with:)`, replace the current precise ended branch:

```swift
        if contentView.gestureZoom != nil && (isZeroDeltaPreciseEnd || isNonPreciseExplicitEnd) {
            beginZoomInertiaIfNeeded()
            if inertiaTimer == nil {
                commitPreviewZoomIfNeeded()
            }
            return
        }
```

- [ ] **Step 3: Add window-level inertia regressions**

Add to `spoke/Tests/PinnedTextWindowStateTests.swift`:

```swift
    @Test("precise zoom gesture keeps moving briefly after ended before committing")
    func preciseZoomGestureKeepsMovingBrieflyAfterEndedBeforeCommitting() throws {
        let (window, _) = makeWindow(
            text: makeScrollablePreviewText(lineCount: 40),
            frame: CGRect(x: 0, y: 0, width: 320, height: 220)
        )
        let content = try #require(window.pinnedTextContentView)
        prepareContentForInteraction(content, in: window)

        content.mouseEntered(with: try makeMouseEvent(
            window: window,
            type: .mouseEntered,
            location: CGPoint(x: 80, y: 80),
            clickCount: 0
        ))

        window.scrollWheel(with: try makeScrollEvent(deltaY: 30, precise: true))
        let frameBeforeEnd = window.frame

        window.scrollWheel(with: try makeScrollEvent(deltaY: 0, precise: true, phase: .ended))
        advanceMainLoop(by: 0.05)
        let frameDuringInertia = window.frame

        #expect(frameDuringInertia.width >= frameBeforeEnd.width)
        #expect(frameDuringInertia.height >= frameBeforeEnd.height)

        advanceMainLoop(by: 0.35)

        #expect(window.item.zoomLevel == content.previewZoomForTesting)
        #expect(abs(content.previewScaleForTesting - 1.0) <= 0.0001)
    }
```

- [ ] **Step 4: Run all zoom-related verification**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && \
swift test --filter PinnedTextZoomGeometryTests && \
swift test --filter PinnedTextZoomDynamicsTests && \
swift test --filter PinnedTextWindowStateTests && \
swift test --filter AppPinnedTextRuntimeTests && \
swift build
```

Expected:

- all four test filters PASS
- `swift build` PASS

- [ ] **Step 5: Commit the inertia wiring**

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && \
git add \
  spoke/UI/DesktopText/PinnedTextWindow.swift \
  spoke/Tests/PinnedTextWindowStateTests.swift \
  spoke/Tests/AppPinnedTextRuntimeTests.swift \
  spoke/UI/DesktopText/PinnedTextZoomDynamics.swift \
  spoke/Tests/PinnedTextZoomDynamicsTests.swift && \
git commit -m "feat: add pinned text zoom follow-through"
```

### Task 6: Final polish verification and manual UAT checklist

**Files:**
- Modify: `spoke/Tests/PinnedTextWindowStateTests.swift` (only if tiny assertion cleanup is needed)
- Reference: `spoke/UI/DesktopText/PinnedTextWindow.swift`
- Reference: `spoke/UI/DesktopText/PinnedTextContentView.swift`

- [ ] **Step 1: Run the full pinned text verification set**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && \
swift test --filter PinnedTextZoomGeometryTests && \
swift test --filter PinnedTextZoomDynamicsTests && \
swift test --filter PinnedTextWindowStateTests && \
swift test --filter AppPinnedTextRuntimeTests && \
swift build
```

Expected:

- all PASS

- [ ] **Step 2: Manual UAT on the three user-reported scenarios**

Run the app:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && ./dev.sh
```

Verify manually:

```text
1. 内容完全铺满、不需要滚动：
   - hover 未聚焦上下滑时，卡片长宽同倍率变化
   - 手势结束后有轻微跟手延续，再稳定停住

2. 内容略超出、需要少量滚动：
   - 即使当前窗口被手动拖成较窄/较扁，hover 缩放也不应先单独拉高再进入等比
   - preview 与 commit 保持同一张卡片比例

3. 内容极长、命中高度上限：
   - 卡片不应出现“高度固定、宽度继续单独变化”的 width-only zoom
   - 如果继续放大，应该表现为统一 clamp / edge resistance，而不是变成另一套几何规则
```

- [ ] **Step 3: Commit any tiny verification-only assertion cleanup**

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && \
git add spoke/Tests/PinnedTextWindowStateTests.swift && \
git commit -m "test: finalize pinned text zoom polish coverage"
```

---

## Self-Review

### Spec coverage

- Hover-unfocused zoom remains the main interaction path: covered by Tasks 1, 2, 3, 5
- Smoothness / follow-through: covered by Tasks 4 and 5
- Proportional visible-card scaling across overflow classes: covered by Tasks 1, 2, 3, 6
- Runtime frame propagation: covered by Tasks 3 and 5
- Manual QA against the exact user-reported edge cases: covered by Task 6

### Placeholder scan

- No placeholder markers remain in executable tasks
- All new helpers, tests, files, and commands are named concretely
- All code-changing steps include code blocks

### Type consistency

- Geometry helper is consistently named `PinnedTextZoomGeometry`
- Dynamics helper is consistently named `PinnedTextZoomDynamics`
- The commit helper is consistently named `commitPreviewZoomUsingCurrentFrame(_:)`
