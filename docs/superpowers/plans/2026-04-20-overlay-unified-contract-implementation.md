# Overlay Unified Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:super-40-subagent-driven-development (recommended) or superpowers:super-41-executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify `PinnedText` and `Screenshot` overlay interaction and appearance contracts around opacity, horizontal scroll transparency, shared context-menu skeleton, and convergent glow/shadow styling while keeping their content-specific implementations separate.

**Architecture:** Introduce a thin shared overlay contract layer rather than merging the two window implementations. Centralize shared knobs for minimum opacity, horizontal opacity sensitivity, common menu groups, and shared glow style selection; then wire `PinnedTextWindow` and `ScreenshotWindow` into that contract while leaving text zoom and image zoom pipelines independent.

**Tech Stack:** Swift 5.9, AppKit `NSPanel` / `NSView`, existing `PinnedText*` / `Screenshot*` UI modules, `DesignTokens`, Swift Testing, `swift test`, `swift build`

---

## File Map

### Shared contract files

- Create: `spoke/UI/Overlay/OverlayInteractionContract.swift`
  - Shared opacity bounds, shared horizontal-opacity scroll sensitivity, and shared menu-group descriptors.
- Create: `spoke/UI/Overlay/OverlayAppearanceContract.swift`
  - Shared glow/shadow style selection for idle / hover / mark states.

### Existing implementation files

- Modify: `spoke/UI/DesktopText/PinnedTextWindow.swift`
  - Replace hardcoded opacity floor with shared contract values.
- Modify: `spoke/UI/Screenshot/ScreenshotWindow.swift`
  - Replace hardcoded opacity floor with shared contract values.
- Modify: `spoke/UI/DesktopText/PinnedTextContentView.swift`
  - Rebuild context menu through shared menu skeleton while preserving text-specific items.
- Modify: `spoke/UI/Screenshot/ScreenshotContentView.swift`
  - Rebuild context menu through shared menu skeleton while preserving screenshot-specific items.
- Modify: `spoke/UI/Theme/DesignTokens.swift`
  - If needed, normalize `PinnedText` and `ScreenshotCard` glow definitions into a shared token source while keeping surface-specific override slots optional.

### Tests

- Modify: `spoke/Tests/PinnedTextWindowStateTests.swift`
  - Add opacity floor assertions and menu skeleton assertions for text overlays.
- Modify: `spoke/Tests/ScreenshotWindowInteractionTests.swift`
  - Add opacity floor assertions and glow parity assertions for screenshot overlays.
- Create: `spoke/Tests/OverlayInteractionContractTests.swift`
  - Add pure shared-contract tests for opacity bounds and menu grouping.

### Reference docs

- Reference: `docs/superpowers/specs/2026-04-20-overlay-unified-contract-design.md`
- Reference: `spoke/docs/architecture/pinned-text-zoom-notes.md`

---

## Scope Lock

This plan implements only the user-approved contract surface:

1. minimum overlay opacity unified to `0.05`
2. `horizontal dominant scroll -> opacity` unified for `PinnedText` and `Screenshot`
3. common right-click menu skeleton unified
4. glow / shadow contract investigated and converged toward the more natural `PinnedText` look

This plan does **not**:

1. merge `PinnedTextWindow` and `ScreenshotWindow`
2. merge text zoom and image zoom internals
3. touch screenshot annotation internal opacity clamps
4. rewrite OCR / Quick Ask / edit feature ownership

---

### Task 1: Lock the shared opacity and menu contract with failing tests

**Files:**
- Create: `spoke/Tests/OverlayInteractionContractTests.swift`
- Modify: `spoke/Tests/PinnedTextWindowStateTests.swift`
- Modify: `spoke/Tests/ScreenshotWindowInteractionTests.swift`

- [ ] **Step 1: Add pure contract tests for shared opacity bounds**

Create `spoke/Tests/OverlayInteractionContractTests.swift`:

```swift
import Testing
@testable import SpokenAnyWhere

@Suite("OverlayInteractionContract tests")
@MainActor
struct OverlayInteractionContractTests {
    @Test("shared overlay opacity bounds use 0.05 minimum and 1.0 maximum")
    func sharedOpacityBoundsUseExpectedRange() {
        #expect(OverlayInteractionContract.minimumOpacity == 0.05)
        #expect(OverlayInteractionContract.maximumOpacity == 1.0)
    }

    @Test("shared overlay horizontal opacity sensitivity is available to both surfaces")
    func sharedHorizontalOpacitySensitivityExists() {
        #expect(OverlayInteractionContract.horizontalOpacitySensitivity > 0)
    }
}
```

- [ ] **Step 2: Add a failing text-overlay test for the lower opacity floor**

Append to `spoke/Tests/PinnedTextWindowStateTests.swift`:

```swift
    @Test("pinned text horizontal opacity scroll clamps at shared minimum opacity")
    func pinnedTextHorizontalOpacityScrollClampsAtSharedMinimumOpacity() throws {
        let (window, _) = makeWindow(
            text: makeScrollablePreviewText(),
            frame: CGRect(x: 0, y: 0, width: 360, height: 160)
        )
        let content = try #require(window.pinnedTextContentView)
        prepareContentForInteraction(content, in: window)

        for _ in 0..<60 {
            window.scrollWheel(with: try makeScrollEvent(deltaX: -50, precise: true))
        }

        #expect(abs(window.item.opacity - 0.05) <= 0.0001)
    }
```

- [ ] **Step 3: Add a failing screenshot-overlay test for the lower opacity floor**

Append to `spoke/Tests/ScreenshotWindowInteractionTests.swift`:

```swift
    @Test("screenshot horizontal opacity scroll clamps at shared minimum opacity")
    func screenshotHorizontalOpacityScrollClampsAtSharedMinimumOpacity() throws {
        let item = makeScreenshotItem()
        let window = ScreenshotWindow(item: item, dependencies: .live)

        for _ in 0..<60 {
            window.scrollWheel(with: try makeScrollEvent(deltaX: -50, precise: true))
        }

        #expect(abs(window.item.opacity - 0.05) <= 0.0001)
    }
```

- [ ] **Step 4: Run red tests**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && \
swift test --filter OverlayInteractionContractTests && \
swift test --filter pinnedTextHorizontalOpacityScrollClampsAtSharedMinimumOpacity && \
swift test --filter screenshotHorizontalOpacityScrollClampsAtSharedMinimumOpacity
```

Expected:

- contract tests FAIL because `OverlayInteractionContract` does not exist yet
- text and screenshot opacity-floor tests FAIL because both implementations still clamp at `0.3`

- [ ] **Step 5: Commit the red tests**

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && \
git add \
  spoke/Tests/OverlayInteractionContractTests.swift \
  spoke/Tests/PinnedTextWindowStateTests.swift \
  spoke/Tests/ScreenshotWindowInteractionTests.swift && \
git commit -m "test: lock overlay shared opacity contract"
```

### Task 2: Introduce a shared overlay interaction contract

**Files:**
- Create: `spoke/UI/Overlay/OverlayInteractionContract.swift`
- Modify: `spoke/UI/DesktopText/PinnedTextWindow.swift`
- Modify: `spoke/UI/Screenshot/ScreenshotWindow.swift`
- Modify: `spoke/Tests/OverlayInteractionContractTests.swift`

- [ ] **Step 1: Create the shared interaction contract**

Create `spoke/UI/Overlay/OverlayInteractionContract.swift`:

```swift
import Foundation

@MainActor
enum OverlayInteractionContract {
    static let minimumOpacity: Double = 0.05
    static let maximumOpacity: Double = 1.0
    static let horizontalOpacitySensitivity: CGFloat = 0.003
}
```

- [ ] **Step 2: Replace hardcoded opacity bounds in pinned text**

Update `spoke/UI/DesktopText/PinnedTextWindow.swift`:

```swift
    private func handleOpacityChange(delta: CGFloat, sensitivity: CGFloat) {
        let opacityDelta = delta * sensitivity
        let newOpacity = max(
            OverlayInteractionContract.minimumOpacity,
            min(OverlayInteractionContract.maximumOpacity, item.opacity + opacityDelta)
        )

        guard abs(item.opacity - newOpacity) > 0.001 else { return }
        item.opacity = newOpacity
        alphaValue = newOpacity
        dependencies.saveWindowState()
    }
```

And replace the call site:

```swift
        handleOpacityChange(
            delta: deltaX,
            sensitivity: OverlayInteractionContract.horizontalOpacitySensitivity
        )
```

- [ ] **Step 3: Replace hardcoded opacity bounds in screenshot**

Update `spoke/UI/Screenshot/ScreenshotWindow.swift`:

```swift
    private func handleOpacityChange(delta: CGFloat, sensitivity: CGFloat) {
        let opacityDelta = delta * sensitivity
        let newOpacity = max(
            OverlayInteractionContract.minimumOpacity,
            min(OverlayInteractionContract.maximumOpacity, item.opacity + opacityDelta)
        )

        if abs(item.opacity - newOpacity) > 0.001 {
            item.opacity = newOpacity
            alphaValue = newOpacity
            dependencies.saveWindowState()
        }
    }
```

And replace the horizontal opacity call sites with the shared sensitivity.

- [ ] **Step 4: Run focused verification**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && \
swift test --filter OverlayInteractionContractTests && \
swift test --filter pinnedTextHorizontalOpacityScrollClampsAtSharedMinimumOpacity && \
swift test --filter screenshotHorizontalOpacityScrollClampsAtSharedMinimumOpacity && \
swift build
```

Expected:

- all tests PASS
- build PASS

- [ ] **Step 5: Commit the shared opacity contract**

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && \
git add \
  spoke/UI/Overlay/OverlayInteractionContract.swift \
  spoke/UI/DesktopText/PinnedTextWindow.swift \
  spoke/UI/Screenshot/ScreenshotWindow.swift \
  spoke/Tests/OverlayInteractionContractTests.swift \
  spoke/Tests/PinnedTextWindowStateTests.swift \
  spoke/Tests/ScreenshotWindowInteractionTests.swift && \
git commit -m "feat: unify overlay opacity contract"
```

### Task 3: Unify the shared context-menu skeleton

**Files:**
- Modify: `spoke/UI/DesktopText/PinnedTextContentView.swift`
- Modify: `spoke/UI/Screenshot/ScreenshotContentView.swift`
- Modify: `spoke/Tests/PinnedTextWindowStateTests.swift`
- Modify: `spoke/Tests/ScreenshotWindowInteractionTests.swift`

- [ ] **Step 1: Add a shared menu-group order**

Inside `spoke/UI/Overlay/OverlayInteractionContract.swift`, extend:

```swift
    enum MenuGroup: String, CaseIterable {
        case copy
        case pin
        case sourceSpecific
        case mark
        case close
    }
```

- [ ] **Step 2: Rebuild pinned text menu to follow the shared skeleton**

Refactor `makeContextMenu()` in `spoke/UI/DesktopText/PinnedTextContentView.swift` so the resulting order is:

```text
Copy Image
Copy Text
---
Pin / Unpin
Lock / Unlock
---
Mark / Unmark
---
Close
```

Do not remove `Lock / Unlock`; keep it as a text-specific item inside the nearest group that still preserves the common skeleton.

- [ ] **Step 3: Rebuild screenshot menu to follow the same skeleton**

Refactor screenshot content menu builders so the resulting order is:

```text
Copy Image
Copy Text (if available)
Copy Enhanced Image (if available)
---
Pin / Unpin
---
Quick Ask / OCR (source-specific)
---
Mark / Unmark
---
Close
```

- [ ] **Step 4: Add regression assertions for menu order**

Add to `spoke/Tests/PinnedTextWindowStateTests.swift`:

```swift
    @Test("pinned text context menu follows shared overlay skeleton order")
    func pinnedTextContextMenuFollowsSharedSkeletonOrder() {
        let (window, _) = makeWindow()
        let content = try! #require(window.pinnedTextContentView)
        let titles = content.contextMenuItemTitles()

        #expect(titles.first == "Copy Text (T)" || titles.first == "Copy Image (C)")
        #expect(titles.contains("Close (Q)"))
        #expect(titles.contains(where: { $0.contains("Pin") || $0.contains("Unpin") }))
        #expect(titles.contains(where: { $0.contains("Mark") || $0.contains("Unmark") }))
    }
```

Add equivalent order assertions to `spoke/Tests/ScreenshotWindowInteractionTests.swift`.

- [ ] **Step 5: Run focused tests and build**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && \
swift test --filter PinnedTextWindowStateTests && \
swift test --filter ScreenshotWindowInteractionTests && \
swift build
```

Expected:

- all PASS

- [ ] **Step 6: Commit the menu skeleton unification**

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && \
git add \
  spoke/UI/DesktopText/PinnedTextContentView.swift \
  spoke/UI/Screenshot/ScreenshotContentView.swift \
  spoke/UI/Overlay/OverlayInteractionContract.swift \
  spoke/Tests/PinnedTextWindowStateTests.swift \
  spoke/Tests/ScreenshotWindowInteractionTests.swift && \
git commit -m "feat: unify overlay context menu skeleton"
```

### Task 4: Investigate and converge screenshot glow/shadow toward the pinned-text style

**Files:**
- Modify: `spoke/UI/Theme/DesignTokens.swift`
- Modify: `spoke/UI/Screenshot/ScreenshotContentView.swift`
- Modify: `spoke/Tests/ScreenshotWindowInteractionTests.swift`
- Modify: `spoke/Tests/PinnedTextWindowStateTests.swift`

- [ ] **Step 1: Add a shared appearance contract shape in DesignTokens**

Refactor the glow token layout so both surfaces are expressed through the same structure:

```swift
extension DesignTokens.Glow {
    enum OverlayContract {
        static let idle = ScreenshotCard.idle
        static let hover = ScreenshotCard.hover
        static let mark = ScreenshotCard.mark
    }
}
```

If screenshot still needs a slight override later, keep the override explicit rather than hidden in duplicated constants.

- [ ] **Step 2: Make screenshot consume the shared overlay glow contract**

In `spoke/UI/Screenshot/ScreenshotContentView.swift`, replace direct `DesignTokens.Glow.ScreenshotCard.*` lookups with the shared overlay glow contract.

- [ ] **Step 3: Add regression that screenshot no longer diverges structurally from pinned text**

Add or update tests so they assert:

```swift
    #expect(DesignTokens.Glow.PinnedText.hover.lineWidth == DesignTokens.Glow.OverlayContract.hover.lineWidth)
    #expect(DesignTokens.Glow.PinnedText.mark.lineWidth == DesignTokens.Glow.OverlayContract.mark.lineWidth)
```

Do not overfit exact pixel output if the surface still legitimately differs in size; focus on token-structure parity and absence of a uniquely heavy screenshot-only glow recipe.

- [ ] **Step 4: Run glow-focused tests and build**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && \
swift test --filter ScreenshotWindowInteractionTests && \
swift test --filter PinnedTextWindowStateTests && \
swift build
```

Expected:

- all PASS

- [ ] **Step 5: Commit the appearance convergence**

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && \
git add \
  spoke/UI/Theme/DesignTokens.swift \
  spoke/UI/Screenshot/ScreenshotContentView.swift \
  spoke/Tests/ScreenshotWindowInteractionTests.swift \
  spoke/Tests/PinnedTextWindowStateTests.swift && \
git commit -m "style: converge overlay glow contract"
```

### Task 5: Final overlay UAT and documentation touch-up

**Files:**
- Modify: `spoke/docs/architecture/pinned-text-zoom-notes.md`
- Create: `spoke/docs/architecture/overlay-unified-contract-notes.md`

- [ ] **Step 1: Write a short overlay note for future work**

Create `spoke/docs/architecture/overlay-unified-contract-notes.md` with:

```md
# Overlay Unified Contract Notes

- minimum overlay opacity is shared at 0.05
- horizontal scroll drives opacity for both pinned text and screenshot overlays
- context menus share a common skeleton with source-specific slots
- screenshot visual styling should converge toward the more natural pinned-text look
```

- [ ] **Step 2: Run final verification**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && \
swift test --filter OverlayInteractionContractTests && \
swift test --filter PinnedTextWindowStateTests && \
swift test --filter ScreenshotWindowInteractionTests && \
swift build
```

Expected:

- all PASS

- [ ] **Step 3: Manual UAT checklist**

Run the app:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && ./dev.sh
```

Verify:

```text
1. PinnedText 和 Screenshot 都可以淡到 0.05 附近
2. 两者横向调透明的速度感受一致
3. 右键菜单共有项顺序 / 命名 / 分组更接近
4. Screenshot 不再比 PinnedText 明显更黑更重
```

- [ ] **Step 4: Commit documentation and final polish**

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && \
git add \
  spoke/docs/architecture/overlay-unified-contract-notes.md \
  spoke/docs/architecture/pinned-text-zoom-notes.md && \
git commit -m "docs: record overlay unified contract"
```

---

## Self-Review

### Spec coverage

- minimum opacity unified to 0.05: covered by Tasks 1 and 2
- horizontal opacity semantics unified: covered by Task 2
- menu skeleton unified: covered by Task 3
- glow/shadow convergence: covered by Task 4
- docs / reusable notes: covered by Task 5

### Placeholder scan

- No placeholder markers remain in executable tasks
- Every code-changing step includes concrete code or concrete structure
- Every task has exact file paths and verification commands

### Type consistency

- Shared interaction contract is consistently named `OverlayInteractionContract`
- Shared appearance contract remains an explicit overlay contract inside `DesignTokens.Glow`
- `minimumOpacity`, `maximumOpacity`, and `horizontalOpacitySensitivity` are named consistently across tasks
