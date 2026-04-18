---
status: awaiting_human_verify
trigger: "Investigate issue: pinned-text-size-resets-after-edit"
created: 2026-04-13T11:14:01Z
updated: 2026-04-13T11:32:28Z
---

## Current Focus

hypothesis: Removing the unconditional preferred-size resize from commitEditingIfNeeded() preserves the current frame while still persisting edited text.
test: Self-verification passed; final confirmation now requires exercising the real desktop overlay workflow.
expecting: In the app, a manually widened overlay should remain widened after edit mode ends via clicking another window.
next_action: ask the user to verify the pinned text overlay interaction in the real app workflow

## Symptoms

expected: If the user manually resizes the overlay in preview mode, then enters edit mode and later exits edit mode by clicking another window, the overlay should keep the user-resized window frame.
actual: The overlay keeps the manually resized shape while editing, but after losing focus and automatically returning to preview mode, it snaps back to the original/default size.
errors: none reported
reproduction: 1) Create pinned text overlay. 2) In preview mode resize it from square-ish to a wider rectangle. 3) Double-click to enter editing. 4) Click another window to leave editing. 5) Observe it returns to preview but frame resets to the earlier/default size.
started: Started in the current desktop text overlay implementation during recent UI/interaction iterations. User says this is current behavior now.

## Eliminated

- hypothesis: The manual resize path fails to persist the user-selected frame before editing begins.
  evidence: PinnedTextWindow.continueContentInteraction updates item.frame on every drag, endContentInteraction calls saveWindowState(), and windowDidResize/onFrameChanged also publish frame changes.
  timestamp: 2026-04-13T11:25:28Z

## Evidence

- timestamp: 2026-04-13T11:18:49Z
  checked: UI/DesktopText/PinnedTextContentView.swift via semantic search
  found: commitEditingIfNeeded() ends by calling resizeToPreferredContent(animated: false) after saveWindowState()
  implication: Exiting edit mode appears to force the window back to content-derived dimensions instead of preserving the live frame

- timestamp: 2026-04-13T11:18:49Z
  checked: UI/DesktopText/PinnedTextWindow.swift via semantic search
  found: manual resize updates item.frame continuously and calls saveWindowState() when interaction ends
  implication: The user-resized frame is being tracked correctly before editing, so the reset likely happens during the edit-exit path rather than during resize itself

- timestamp: 2026-04-13T11:21:42Z
  checked: PinnedTextWindow.resignKey and PinnedTextWindow.resizeToPreferredContent
  found: losing key status calls commitEditingIfNeeded(), and resizeToPreferredContent() recenters the frame around current midpoint with preferred width/height before publishing onFrameChanged
  implication: Clicking another window after editing deterministically routes through a size-reset path that replaces the user-chosen frame dimensions

- timestamp: 2026-04-13T11:23:34Z
  checked: PinnedTextEditorTextView.doCommand, PinnedTextContentView.refreshFromItem, and repository search for manual resize state
  found: commit/cancel editor commands do not carry resize intent, refreshFromItem only resizes when explicitly requested, and no manual-resize marker exists in the pinned text code/tests
  implication: The unconditional resize at commit is the lone behavior forcing size changes on edit exit, so removing or gating that call is the smallest viable fix surface

- timestamp: 2026-04-13T11:25:28Z
  checked: AppPinnedTextRuntime.makeWindowFactory and PinnedTextManager.updateFrame
  found: resizeToPreferredContent publishes nextFrame through onFrameChanged, and the manager persists that frame directly to item.frame plus saveAll()
  implication: The edit-exit resize does not just affect live UI; it overwrites the persisted frame source of truth

- timestamp: 2026-04-13T11:32:28Z
  checked: swift test --filter PinnedTextWindowStateTests
  found: The focused suite passed, including the new regression test for resignKey() after manual resize
  implication: The patched edit-exit path preserves the live frame under the reproduced scenario in automated coverage

- timestamp: 2026-04-13T11:32:28Z
  checked: swift build and swift test
  found: Project build succeeded, and the full test suite passed with existing AX smoke tests skipped by configuration
  implication: The fix does not introduce compile/test regressions in the current local environment

## Resolution

root_cause: PinnedTextContentView.commitEditingIfNeeded() always calls PinnedTextWindow.resizeToPreferredContent(animated: false). On focus loss, PinnedTextWindow.resignKey() invokes that commit path, and resizeToPreferredContent() republishes the content-derived frame through onFrameChanged, causing PinnedTextManager.updateFrame() to overwrite the user-resized frame.
fix: Removed the unconditional preferred-size resize from PinnedTextContentView.commitEditingIfNeeded() so ending an edit session preserves the current window frame, and added a regression test covering manual resize plus resignKey().
verification: `swift test --filter PinnedTextWindowStateTests`, `swift build`, and full `swift test` all passed. The new regression test verifies that `resignKey()` after manual resize no longer resets the pinned text window frame.
files_changed: ["UI/DesktopText/PinnedTextContentView.swift", "Tests/PinnedTextWindowStateTests.swift"]
