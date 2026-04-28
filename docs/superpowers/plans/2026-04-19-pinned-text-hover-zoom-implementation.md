# PinnedText Hover Zoom Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign `PinnedText` hover interactions so unfocused hover uses vertical gestures for proportional zoom, focused hover uses vertical gestures for content scroll, and editing remains consistent with the committed zoom level.

**Architecture:** Keep `PinnedTextWindow` as the single wheel-event router and `PinnedTextContentView` as the owner of hover/focus/edit state. Drive committed scaling from `zoomLevel`, add an explicit focused-browsing state, and then layer gesture-time smooth preview zoom on top in Phase 2 without changing persisted model shape.

**Tech Stack:** Swift 5.9, AppKit `NSPanel` / `NSView`, existing `PinnedText*` UI modules, Swift Testing, `swift test`

---

## File Map

### Core implementation files

- Modify: `spoke/UI/DesktopText/PinnedTextContentView.swift`
  - Add focused-browsing state, gesture-preview zoom state, and mouse event ownership changes.
- Modify: `spoke/UI/DesktopText/PinnedTextWindow.swift`
  - Replace current vertical-scroll routing with the new zoom/scroll decision table and centered-frame zoom commit logic.
- Modify: `spoke/UI/DesktopText/PinnedTextMarkdownRenderer.swift`
  - Keep renderer as the single committed zoom source and add any tiny helper needed for clamping or preferred-size recomputation.

### Test files

- Modify: `spoke/Tests/PinnedTextWindowStateTests.swift`
  - Add regression coverage for unfocused zoom, Shift-scroll override, focused browsing lifecycle, and zoom commit behavior.
- Modify: `spoke/Tests/PinnedTextModelTests.swift`
  - Add renderer-oriented assertions if new helper functions or zoom-boundary semantics are introduced.
- Modify: `spoke/Tests/AppPinnedTextRuntimeTests.swift`
  - Only if frame callback semantics need an explicit regression for committed centered resizing.

### Docs

- Reference: `docs/superpowers/specs/2026-04-19-pinned-text-hover-zoom-design.md`

---

## Phase Breakdown

### Phase 1

Semantic correctness and interaction closure:

- three-state interaction model
- click-to-focus and hover-exit defocus
- unfocused zoom / focused scroll / editing scroll routing
- Shift temporary scroll override
- committed zoom driven by `zoomLevel`
- centered frame recomputation after committed zoom
- baseline regression tests

### Phase 2

Smooth preview zoom and polish:

- gesture-time preview zoom state
- settle-time committed zoom
- reduced jitter during continuous gestures
- optional lightweight feedback hooks if needed for smoothness
- regression coverage for preview/commit behavior

---

### Task 1: Lock Phase 1 behavior with failing window interaction tests

**Files:**
- Modify: `spoke/Tests/PinnedTextWindowStateTests.swift`
- Reference: `docs/superpowers/specs/2026-04-19-pinned-text-hover-zoom-design.md`

- [ ] **Step 1: Write failing tests for the new hover/focus wheel routing**

Add tests covering:

```swift
    @Test("unfocused hover vertical scroll updates zoom instead of scrolling content")
    func unfocusedHoverVerticalScrollZooms() throws {
        let (window, counter) = makeWindow()
        let content = try #require(window.pinnedTextContentView)
        window.contentView = content

        content.mouseEntered(with: try makeMouseEvent(
            window: window,
            type: .mouseEntered,
            location: CGPoint(x: 80, y: 80),
            clickCount: 0
        ))

        let originalZoom = window.item.zoomLevel
        window.scrollWheel(with: try makeScrollEvent(deltaY: 20, precise: true))

        #expect(window.item.zoomLevel > originalZoom)
        #expect(counter.saves >= 1)
    }

    @Test("Shift vertical scroll in unfocused hover scrolls content without changing zoom")
    func unfocusedHoverShiftVerticalScrollTemporarilyScrolls() throws {
        let (window, _) = makeWindow()
        let content = try #require(window.pinnedTextContentView)
        window.contentView = content

        content.mouseEntered(with: try makeMouseEvent(
            window: window,
            type: .mouseEntered,
            location: CGPoint(x: 80, y: 80),
            clickCount: 0
        ))

        let originalZoom = window.item.zoomLevel
        let originalOffset = content.previewScrollOriginYForTesting

        window.scrollWheel(with: try makeScrollEvent(deltaY: -30, precise: true, modifiers: [.shift]))

        #expect(window.item.zoomLevel == originalZoom)
        #expect(content.previewScrollOriginYForTesting != originalOffset)
    }

    @Test("click enters focused browsing and mouse exit clears it")
    func clickFocusesAndMouseExitClearsFocusedBrowsing() throws {
        let (window, _) = makeWindow()
        let content = try #require(window.pinnedTextContentView)
        window.contentView = content

        content.mouseEntered(with: try makeMouseEvent(
            window: window,
            type: .mouseEntered,
            location: CGPoint(x: 80, y: 80),
            clickCount: 0
        ))

        content.mouseDown(with: try makeMouseEvent(
            window: window,
            type: .leftMouseDown,
            location: CGPoint(x: 80, y: 80),
            clickCount: 1
        ))
        content.mouseUp(with: try makeMouseEvent(
            window: window,
            type: .leftMouseUp,
            location: CGPoint(x: 80, y: 80),
            clickCount: 1
        ))

        #expect(content.isFocusedBrowsingForTesting == true)

        content.mouseExited(with: try makeMouseEvent(
            window: window,
            type: .mouseExited,
            location: CGPoint(x: 500, y: 500),
            clickCount: 0
        ))

        #expect(content.isFocusedBrowsingForTesting == false)
    }
```

- [ ] **Step 2: Run the focused pinned text window tests to verify failure**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && swift test --filter PinnedTextWindowStateTests
```

Expected:

- FAIL because the new test helpers and routing behavior do not exist yet

- [ ] **Step 3: Add minimal test-only inspection hooks**

In `spoke/UI/DesktopText/PinnedTextContentView.swift`, add internal testing accessors near the bottom of the file:

```swift
    var isFocusedBrowsingForTesting: Bool {
        isFocusedBrowsing
    }

    var previewScrollOriginYForTesting: CGFloat {
        previewScrollView.contentView.bounds.origin.y
    }
```

In `spoke/Tests/PinnedTextWindowStateTests.swift`, extend the existing event factory to support modifier flags:

```swift
    private func makeScrollEvent(
        deltaX: Int32 = 0,
        deltaY: Int32 = 0,
        precise: Bool = true,
        modifiers: NSEvent.ModifierFlags = []
    ) throws -> NSEvent {
        let units: CGScrollEventUnit = precise ? .pixel : .line
        let cgEvent = try #require(
            CGEvent(
                scrollWheelEvent2Source: nil,
                units: units,
                wheelCount: 2,
                wheel1: deltaY,
                wheel2: deltaX,
                wheel3: 0
            )
        )
        cgEvent.flags = CGEventFlags(modifiers)
        return try #require(NSEvent(cgEvent: cgEvent))
    }
```

- [ ] **Step 4: Run the focused pinned text window tests again**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && swift test --filter PinnedTextWindowStateTests
```

Expected:

- FAIL on behavior assertions rather than missing helper symbols

- [ ] **Step 5: Commit the red tests**

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && git add \
  spoke/Tests/PinnedTextWindowStateTests.swift \
  spoke/UI/DesktopText/PinnedTextContentView.swift && \
git commit -m "test: cover pinned text hover zoom state routing"
```

### Task 2: Implement Phase 1 state model and committed zoom routing

**Files:**
- Modify: `spoke/UI/DesktopText/PinnedTextContentView.swift`
- Modify: `spoke/UI/DesktopText/PinnedTextWindow.swift`
- Modify: `spoke/UI/DesktopText/PinnedTextMarkdownRenderer.swift`
- Test: `spoke/Tests/PinnedTextWindowStateTests.swift`

- [ ] **Step 1: Add focused-browsing state and focused lifecycle methods**

In `spoke/UI/DesktopText/PinnedTextContentView.swift`, add the new stored state near the existing hover/edit state:

```swift
    private(set) var isFocusedBrowsing = false
```

Add helpers:

```swift
    func enterFocusedBrowsing() {
        guard !isEditing else { return }
        isFocusedBrowsing = true
    }

    func exitFocusedBrowsing() {
        guard !isEditing else { return }
        isFocusedBrowsing = false
    }
```

Update hover exit:

```swift
    override func mouseExited(with event: NSEvent) {
        isHovered = false
        exitFocusedBrowsing()
        (window as? PinnedTextWindow)?.handleHoverChanged(false, locationInWindow: nil)
    }
```

- [ ] **Step 2: Update click and drag priority for focus vs drag**

Replace the beginning of `mouseDown(with:)` with:

```swift
    override func mouseDown(with event: NSEvent) {
        guard !isEditing else {
            super.mouseDown(with: event)
            return
        }

        let isInsideCard = interactiveCardFrame().contains(event.locationInWindow)
        guard isInsideCard else { return }

        if event.clickCount >= 2 {
            beginEditing()
            return
        }

        enterFocusedBrowsing()

        guard let pinnedWindow = window as? PinnedTextWindow else {
            return
        }

        if pinnedWindow.beginContentInteraction(with: event) {
            return
        }

        guard !item.isLocked else {
            return
        }

        pinnedWindow.performDrag(with: event)
    }
```

This preserves immediate drag-to-move while still setting focus on a plain single click.

- [ ] **Step 3: Replace current wheel routing with zoom-first unfocused behavior**

In `spoke/UI/DesktopText/PinnedTextWindow.swift`, replace `scrollWheel(with:)` with routing like:

```swift
    override func scrollWheel(with event: NSEvent) {
        guard let contentView = pinnedTextContentView else {
            super.scrollWheel(with: event)
            return
        }

        if contentView.isEditing {
            super.scrollWheel(with: event)
            return
        }

        let wantsScrollOverride = event.modifierFlags.contains(.shift)
        let isVerticalDominant = abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX)

        guard isVerticalDominant else {
            super.scrollWheel(with: event)
            return
        }

        if contentView.isFocusedBrowsing || wantsScrollOverride {
            contentView.forwardVerticalScroll(event)
            return
        }

        applyCommittedZoom(deltaY: event.scrollingDeltaY)
    }
```

Add committed zoom application:

```swift
    private func applyCommittedZoom(deltaY: CGFloat) {
        guard deltaY != 0 else { return }

        let step: Double = deltaY > 0 ? 0.08 : -0.08
        let clamped = PinnedTextMarkdownRenderer.clampedZoom(item.zoomLevel + step)
        guard abs(clamped - item.zoomLevel) > 0.0001 else { return }

        item.zoomLevel = clamped
        pinnedTextContentView?.refreshFromItem()
        resizeToPreferredContent(animated: false)
        item.frame = frame
        dependencies.saveWindowState()
        onFrameChanged?(frame)
    }
```

- [ ] **Step 4: Preserve centered frame recomputation**

Keep `resizeToPreferredContent(animated:)` centered around the existing window midpoint. If needed, make the frame update explicit:

```swift
        let currentCenter = CGPoint(x: currentFrame.midX, y: currentFrame.midY)
        let nextFrame = CGRect(
            x: currentCenter.x - size.width / 2,
            y: currentCenter.y - size.height / 2,
            width: size.width,
            height: size.height
        )
```

- [ ] **Step 5: Run pinned text window tests to verify Phase 1 passes**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && swift test --filter PinnedTextWindowStateTests
```

Expected:

- PASS for the new hover/focus/zoom behavior tests

- [ ] **Step 6: Run the pinned text model tests to verify renderer compatibility**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && swift test --filter PinnedTextModelTests
```

Expected:

- PASS with no renderer regression

- [ ] **Step 7: Commit Phase 1 interaction routing**

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && git add \
  spoke/UI/DesktopText/PinnedTextContentView.swift \
  spoke/UI/DesktopText/PinnedTextWindow.swift \
  spoke/UI/DesktopText/PinnedTextMarkdownRenderer.swift \
  spoke/Tests/PinnedTextWindowStateTests.swift \
  spoke/Tests/PinnedTextModelTests.swift && \
git commit -m "feat: add pinned text hover zoom browsing states"
```

### Task 3: Add Phase 1 regression coverage for runtime frame propagation

**Files:**
- Modify: `spoke/Tests/AppPinnedTextRuntimeTests.swift`
- Reference: `spoke/UI/DesktopText/PinnedTextWindow.swift`

- [ ] **Step 1: Add a regression test for centered zoom frame callback propagation**

Append:

```swift
    @Test("committed zoom resizing still propagates frame updates through the runtime hook")
    func committedZoomResizeStillPropagatesFrameUpdates() throws {
        let item = PinnedTextItem(
            text: "hello",
            frame: CGRect(x: 40, y: 50, width: 300, height: 180)
        )
        var updates: [CGRect] = []

        let runtime = AppPinnedTextRuntime(
            makeWindow: { item in
                PinnedTextWindow(item: item)
            },
            updateFrame: { frame, _ in
                updates.append(frame)
            },
            restoreAll: {},
            createFromClipboard: {}
        )

        let panel = runtime.makeWindowFactory()(item)
        let window = try #require(panel as? PinnedTextWindow)
        window.onFrameChanged?(CGRect(x: 20, y: 30, width: 360, height: 220))

        #expect(updates.last == CGRect(x: 20, y: 30, width: 360, height: 220))
    }
```

- [ ] **Step 2: Run the runtime tests**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && swift test --filter AppPinnedTextRuntimeTests
```

Expected:

- PASS

- [ ] **Step 3: Commit the runtime regression**

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && git add \
  spoke/Tests/AppPinnedTextRuntimeTests.swift && \
git commit -m "test: cover pinned text zoom frame propagation"
```

### Task 4: Write failing tests for Phase 2 smooth preview zoom

**Files:**
- Modify: `spoke/Tests/PinnedTextWindowStateTests.swift`
- Modify: `spoke/UI/DesktopText/PinnedTextContentView.swift`

- [ ] **Step 1: Add failing tests for gesture preview zoom state**

Add tests like:

```swift
    @Test("active zoom gesture keeps preview zoom separate from committed item zoom")
    func activeZoomGestureUsesPreviewZoomBeforeCommit() throws {
        let (window, _) = makeWindow()
        let content = try #require(window.pinnedTextContentView)
        window.contentView = content

        content.mouseEntered(with: try makeMouseEvent(
            window: window,
            type: .mouseEntered,
            location: CGPoint(x: 80, y: 80),
            clickCount: 0
        ))

        let committedZoom = window.item.zoomLevel
        window.beginPreviewZoomForTesting(deltaY: 20)

        #expect(content.previewZoomForTesting > committedZoom)
        #expect(window.item.zoomLevel == committedZoom)
    }
```

- [ ] **Step 2: Run pinned text window tests to verify failure**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && swift test --filter PinnedTextWindowStateTests
```

Expected:

- FAIL because preview zoom APIs and behavior do not exist yet

- [ ] **Step 3: Add minimal test-only hooks for preview zoom**

Add temporary accessors in `PinnedTextContentView.swift`:

```swift
    var previewZoomForTesting: Double {
        gestureZoom ?? item.zoomLevel
    }
```

Add a temporary test shim in `PinnedTextWindow.swift`:

```swift
    func beginPreviewZoomForTesting(deltaY: CGFloat) {
        updatePreviewZoom(deltaY: deltaY)
    }
```

- [ ] **Step 4: Re-run the focused window tests**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && swift test --filter PinnedTextWindowStateTests
```

Expected:

- FAIL on preview/commit behavior assertions rather than missing symbols

- [ ] **Step 5: Commit the red Phase 2 tests**

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && git add \
  spoke/Tests/PinnedTextWindowStateTests.swift \
  spoke/UI/DesktopText/PinnedTextContentView.swift \
  spoke/UI/DesktopText/PinnedTextWindow.swift && \
git commit -m "test: cover pinned text preview zoom smoothing"
```

### Task 5: Implement Phase 2 preview zoom and settle-time commit

**Files:**
- Modify: `spoke/UI/DesktopText/PinnedTextContentView.swift`
- Modify: `spoke/UI/DesktopText/PinnedTextWindow.swift`
- Test: `spoke/Tests/PinnedTextWindowStateTests.swift`

- [ ] **Step 1: Add preview zoom state to the content view**

In `spoke/UI/DesktopText/PinnedTextContentView.swift`, add:

```swift
    private(set) var gestureZoom: Double?
    private var pendingZoomCommitWorkItem: DispatchWorkItem?
```

Add helpers:

```swift
    func beginOrUpdatePreviewZoom(_ zoom: Double) {
        gestureZoom = zoom
    }

    func clearPreviewZoom() {
        gestureZoom = nil
    }
```

- [ ] **Step 2: Add preview zoom routing in the window**

In `spoke/UI/DesktopText/PinnedTextWindow.swift`, replace direct committed zoom during unfocused hover with:

```swift
    private func updatePreviewZoom(deltaY: CGFloat) {
        guard let contentView = pinnedTextContentView, deltaY != 0 else { return }

        let baseZoom = contentView.gestureZoom ?? item.zoomLevel
        let step: Double = deltaY > 0 ? 0.05 : -0.05
        let nextZoom = PinnedTextMarkdownRenderer.clampedZoom(baseZoom + step)

        guard abs(nextZoom - baseZoom) > 0.0001 else { return }

        contentView.beginOrUpdatePreviewZoom(nextZoom)
        schedulePreviewZoomCommit()
    }
```

Call `updatePreviewZoom(deltaY:)` from `scrollWheel(with:)` for the unfocused-hover path instead of `applyCommittedZoom(deltaY:)`.

- [ ] **Step 3: Add delayed commit to stable zoom**

Still in `PinnedTextWindow.swift`, add:

```swift
    private func schedulePreviewZoomCommit() {
        pinnedTextContentView?.pendingZoomCommitWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.commitPreviewZoomIfNeeded()
        }

        pinnedTextContentView?.pendingZoomCommitWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    private func commitPreviewZoomIfNeeded() {
        guard let contentView = pinnedTextContentView,
              let previewZoom = contentView.gestureZoom else { return }

        guard abs(previewZoom - item.zoomLevel) > 0.0001 else {
            contentView.clearPreviewZoom()
            return
        }

        item.zoomLevel = previewZoom
        contentView.clearPreviewZoom()
        contentView.refreshFromItem()
        resizeToPreferredContent(animated: false)
        item.frame = frame
        dependencies.saveWindowState()
        onFrameChanged?(frame)
    }
```

- [ ] **Step 4: Apply lightweight preview visuals without final markdown rebuild**

In `PinnedTextContentView.swift`, apply a view-level preview transform while `gestureZoom` is active:

```swift
    private func updatePreviewZoomVisuals() {
        let preview = gestureZoom ?? item.zoomLevel
        let scale = preview / item.zoomLevel
        previewScrollView.layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
    }
```

Call this from `beginOrUpdatePreviewZoom(_:)`, `clearPreviewZoom()`, and `refreshFromItem()`. Ensure `previewScrollView.wantsLayer = true`.

- [ ] **Step 5: Run pinned text window tests to verify preview/commit passes**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && swift test --filter PinnedTextWindowStateTests
```

Expected:

- PASS with preview zoom state and settled commit behavior

- [ ] **Step 6: Run the full pinned text test slice**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && \
swift test --filter PinnedTextModelTests && \
swift test --filter PinnedTextWindowStateTests && \
swift test --filter AppPinnedTextRuntimeTests
```

Expected:

- PASS across all pinned text suites

- [ ] **Step 7: Commit Phase 2 smooth zoom**

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && git add \
  spoke/UI/DesktopText/PinnedTextContentView.swift \
  spoke/UI/DesktopText/PinnedTextWindow.swift \
  spoke/Tests/PinnedTextWindowStateTests.swift \
  spoke/Tests/PinnedTextModelTests.swift \
  spoke/Tests/AppPinnedTextRuntimeTests.swift && \
git commit -m "feat: smooth pinned text hover zoom preview"
```

### Task 6: Final verification sweep

**Files:**
- Modify: none unless verification exposes regressions
- Test: `spoke/Tests/PinnedTextModelTests.swift`
- Test: `spoke/Tests/PinnedTextWindowStateTests.swift`
- Test: `spoke/Tests/AppPinnedTextRuntimeTests.swift`

- [ ] **Step 1: Run the pinned text verification suite**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && \
swift test --filter PinnedTextModelTests && \
swift test --filter PinnedTextWindowStateTests && \
swift test --filter AppPinnedTextRuntimeTests
```

Expected:

- PASS for all pinned text suites

- [ ] **Step 2: Run a build check**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && swift build
```

Expected:

- BUILD SUCCEEDED / exit code 0

- [ ] **Step 3: Commit final verification if any verification-only updates were needed**

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && git status --short
```

Expected:

- no unexpected pinned text diffs remain after verification

## Self-Review

### Spec coverage

- State model: covered in Tasks 1-2
- Zoom-driven sizing: covered in Task 2
- Focus lifecycle and hover exit: covered in Tasks 1-2
- Drag priority: covered in Task 2
- Phase 2 preview smoothing: covered in Tasks 4-5
- Regression verification: covered in Tasks 3 and 6

### Placeholder scan

- No `TODO` / `TBD` / deferred implementation placeholders remain.
- Every task names exact files and exact commands.

### Type consistency

- `isFocusedBrowsing`, `gestureZoom`, and preview zoom helper names are used consistently across later tasks.
- `applyCommittedZoom`, `updatePreviewZoom`, and `commitPreviewZoomIfNeeded` are consistently referenced.
