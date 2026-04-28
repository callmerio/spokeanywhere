# PinnedText Hover Zoom Design

Date: 2026-04-19
Status: Approved in conversation, pending written-spec review
Scope: `PinnedText` hover / focus / scroll / edit interaction redesign

## 1. Context

Current `PinnedText` behavior mixes floating-window interaction with text browsing:

- Double-click already enters editing.
- Vertical scrolling currently defaults to content scrolling.
- Hover does not create a distinct browse-focus mode.
- Text scale and window size are related through `zoomLevel`, but interaction semantics are not aligned with the desired card-like behavior.

The desired experience is to make pinned text behave more like a floating reading card:

- Hover without focus: vertical gesture means resize the whole reading card proportionally.
- Click once: enter a temporary focused-browsing state.
- Focused browsing: vertical gesture means scroll content.
- Mouse leaving the card exits focused browsing automatically.
- Double-click continues to enter editing.

## 2. Goals

### Primary goals

1. Redefine default vertical gesture semantics around reading intent:
   - unfocused hover -> zoom
   - focused hover -> scroll
   - editing -> editor-native scroll
2. Keep text size and card size visually aligned during zoom.
3. Preserve editing consistency so double-clicking into edit mode inherits the current text scale naturally.
4. Keep drag-to-move behavior intact where expected.

### Non-goals

1. No reintroduction of trackpad transparency gestures.
2. No heavyweight interaction-controller refactor in this phase of design.
3. No mouse-position-based zoom anchor.
4. No requirement that every gesture frame performs exact markdown reflow.

## 3. Final Interaction Model

```text
[ hover + unfocused ]
    vertical scroll           -> proportional zoom (text + card together)
    Shift + vertical scroll   -> temporary content scroll
    click                     -> enter focused browsing
    double-click              -> enter editing
    press then drag           -> drag window

[ hover + focused browsing ]
    vertical scroll           -> content scroll
    Shift + vertical scroll   -> content scroll
    double-click              -> enter editing
    mouse exits hover         -> exit focused browsing

[ editing ]
    vertical scroll           -> editor scroll
    Enter / Esc / resign key  -> commit or cancel per existing editing rules
```

## 4. State Model

The design keeps a lightweight three-state model rather than introducing a large controller object.

### Visible states

1. `hover + unfocused`
2. `hover + focused browsing`
3. `editing`

### Required transient fields

These should live in or near `PinnedTextContentView` unless implementation constraints strongly suggest otherwise:

- `isHovered`
- `isFocusedBrowsing`
- `isEditing`
- `gestureZoom` or `previewZoom`
- `isGestureZooming`
- `pendingZoomCommitWorkItem` or equivalent delayed commit token

### State rules

1. `isEditing == true` takes precedence over all browsing states.
2. `isHovered == false` forces `isFocusedBrowsing = false` unless editing is active.
3. `isFocusedBrowsing` is short-lived and tied to hover lifetime.
4. Gesture-preview zoom state is ephemeral and must not be persisted.

## 5. Event Ownership

### `PinnedTextWindow`

Responsible for:

- owning `scrollWheel(with:)`
- choosing between zoom, preview scroll, and editor scroll
- applying committed zoom changes
- recalculating and applying centered window frames
- persisting stable window state after committed changes

### `PinnedTextContentView`

Responsible for:

- hover enter / exit lifecycle
- click to focus
- double-click to edit
- maintaining `isFocusedBrowsing`
- preserving current drag-window behavior from content area when drag starts immediately
- forwarding vertical scroll to preview/editor scroll views as needed

### `PinnedTextMarkdownRenderer`

Remains the single source of truth for:

- zoom clamping
- preview font size
- editor font size
- preferred content size

## 6. Zoom Semantics

### Source of truth

Zoom is driven by `zoomLevel`, not by direct frame scaling.

That means:

- user intent updates zoom first
- layout derives from zoom
- frame derives from preferred content size
- edit mode inherits the same zoom-driven typography

### Anchor

Zoom uses the window center as the anchor.

After a committed zoom change:

1. compute the next preferred size from renderer output
2. rebuild the frame around the current window center
3. apply the updated frame

### Bounds

Zoom stays within `PinnedTextMarkdownRenderer.minZoomLevel` and `maxZoomLevel`.

At either limit:

- additional zoom input should be ignored
- behavior must not silently fall back to scroll

## 7. Two-Stage Zooming for Smoothness

The design explicitly separates gesture smoothness from final layout precision.

### Stage A: gesture-time preview

While the gesture is actively changing:

- update a temporary `gestureZoom`
- provide visually smooth proportional scaling
- avoid forcing full markdown rebuild and final window measurement on every tiny delta

### Stage B: settle-time commit

When the gesture ends or briefly pauses:

- commit the final value into `item.zoomLevel`
- rebuild preview text
- reconfigure editor typography
- recalculate preferred window size
- update frame using centered anchor
- save stable state

### Why this is required

Without this split, every input delta could trigger:

1. markdown rebuilding
2. text measurement
3. preferred size recalculation
4. frame mutation

That risks visible jitter and a coarse, non-fluid zoom feel.

## 8. Scroll Semantics

### Unfocused hover

- vertical gesture means zoom
- `Shift + vertical gesture` means temporary preview scroll

### Focused browsing

- vertical gesture means preview scroll
- `Shift` does not change semantics; it remains scroll

### Editing

- scrolling is owned by the editor scroll view

### Non-scrollable content

If focused browsing is active but the content has nothing meaningful to scroll:

- preserve scroll semantics
- show no fallback zoom behavior
- remain visually still

This prevents gesture meaning from changing unexpectedly inside the same state.

## 9. Click / Drag / Edit Priority

### Click in content region

- plain click enters focused browsing

### Immediate drag from content region

- drag wins over focus
- the window moves as it does today
- this preserves familiar pinned-card manipulation behavior

### Edge regions

- keep existing resize / frame-adjust behavior

### Double-click

- remains the highest-priority direct entry to editing

## 10. Visual Feedback

The final design includes both baseline feedback and optional enhancement feedback.

### Baseline feedback

Must exist:

1. card size changes continuously during zoom preview
2. text scale changes continuously during zoom preview
3. hover glow and toolbar visibility remain stable
4. focus changes behavior without requiring loud new chrome

### Optional enhancement layer

Designed now, not forgotten later:

1. subtle zoom percentage HUD
2. slightly stronger focused-browsing visual affordance
3. small settle animation after commit
4. gentle resistance feedback when scroll cannot move further

These belong to the complete design, but do not all need to ship in the first execution phase.

## 11. Persistence Rules

Persist:

- `item.zoomLevel`
- stable `item.frame`
- existing pinned text state fields

Do not persist:

- `isFocusedBrowsing`
- hover state
- `gestureZoom`
- active gesture timing artifacts

## 12. Testing Requirements

At minimum, the final implementation should cover:

1. unfocused hover vertical gesture updates zoom intent instead of scrolling content
2. `Shift + vertical gesture` in unfocused hover scrolls content
3. single click enters focused browsing
4. `mouseExited` clears focused browsing
5. focused browsing vertical gesture scrolls content
6. double-click still enters editing
7. editor font matches current committed zoom
8. committed zoom updates preferred window size and centered frame
9. non-scrollable focused content does not revert to zoom
10. content-region immediate drag still drags the window

## 13. Implementation Phases

This design is intentionally complete first, then split into phased execution.

### Phase 1: semantic correctness and interaction closure

Deliver:

1. three-state interaction model
2. click-to-focus and mouse-exit defocus
3. unfocused zoom / focused scroll / editing scroll routing
4. `Shift` temporary scroll override in unfocused hover
5. zoom driven by `zoomLevel`
6. centered frame recomputation after committed zoom
7. baseline regression tests for interaction correctness

Phase 1 priority:

- correct behavior
- consistent text/edit scaling
- no semantic ambiguity

### Phase 2: smooth zoom and feedback polish

Deliver:

1. two-stage zoom preview + commit
2. smoother gesture-time scaling
3. settle-time precise layout convergence
4. optional lightweight feedback enhancements
5. tuning and regression coverage for feel and stability

Phase 2 priority:

- fluidity
- reduced jitter
- stronger perceived quality

## 14. Acceptance Criteria

The design should be considered fully delivered when:

1. users can hover a pinned text card and vertically scroll to proportionally resize text and card together
2. a single click enters a temporary browsing mode where vertical scroll becomes content scroll
3. leaving hover automatically exits browsing mode
4. double-click still enters editing without font mismatch
5. scaling feels smooth in practice and settles into an exact committed zoom value
6. the system no longer depends on transparency gestures for this interaction family

## 15. Self-Review Notes

Checked for:

- no placeholder sections
- no contradiction between zoom source and frame ownership
- phased execution included without losing complete end-state design
- no fallback behavior that changes gesture meaning mid-state
