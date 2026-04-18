---
status: awaiting_human_verify
trigger: "Investigate issue: pinned-text-glow-too-large"
created: 2026-04-13T19:27:10+08:00
updated: 2026-04-13T19:33:13+08:00
---

## Current Focus

hypothesis: The pinned text overlay glow was oversized because screenshot-sized hover and mark metrics were reused on a smaller surface.
test: Human-verify the updated pinned text overlay glow in the live desktop workflow.
expecting: Hover and mark should still read as the same blue and orange states, but the halo should sit closer to the card and stop dominating smaller text overlays.
next_action: Ask the user to verify the live pinned text overlay behavior and report whether the glow now feels appropriately restrained.

## Symptoms

expected: The pinned text overlay should keep the same screenshot-derived state language, but the blue hover glow and orange mark glow should feel tighter and more restrained around the card. The glow should not visually dominate the smaller text card.
actual: On the pinned text overlay window specifically, the blue and orange glow appear too large / too spread.
errors: none reported
reproduction: 1) Create a pinned text overlay. 2) Hover it to see blue glow, or mark it to see orange glow. 3) Observe the glow spread feels too large relative to the card size.
started: Current implementation, after recent iterations on the desktop text overlay UI.

## Eliminated

## Evidence

- timestamp: 2026-04-13T19:28:22+08:00
  checked: .planning/debug/knowledge-base.md
  found: No debug knowledge base file exists yet for this repository, so there is no prior known-pattern match to test first.
  implication: Investigation should proceed from source evidence rather than historical matches.

- timestamp: 2026-04-13T19:28:22+08:00
  checked: /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/.workflow (last 7 days)
  found: No recent workflow files were returned.
  implication: There are no recent local conclusions to reuse or conflict with this visual tuning change.

- timestamp: 2026-04-13T19:28:22+08:00
  checked: UI/DesktopText/PinnedTextContentView.swift and UI/Screenshot/ScreenshotContentView.swift via semantic retrieval
  found: Pinned text updateGlow uses the same hover and mark glow numbers seen in screenshot content view: hover shadowRadius 10 with opacity 0.45, mark shadowRadius 12 with opacity 0.5, lineWidth 1.5 for both.
  implication: A direct reuse of screenshot glow tuning is a strong candidate root cause if the pinned surface is materially smaller.

- timestamp: 2026-04-13T19:28:22+08:00
  checked: UI/Theme/DesignTokens.swift via semantic retrieval
  found: Design tokens define glow colors but not separate hover or mark glow radius tokens for pinned text.
  implication: Glow spread is currently controlled in the view implementation, so a targeted view-level adjustment is plausible and low-risk.

- timestamp: 2026-04-13T19:29:33+08:00
  checked: UI/DesktopText/PinnedTextMarkdownRenderer.swift and UI/Screenshot/ScreenshotContentView.swift
  found: Pinned text default content width starts at 320 with windowGlowPadding 14 and min window height 120, while screenshot content reserves 30 points of padding per side for much larger image cards; despite that, both surfaces use the same hover and mark glow radii and opacities.
  implication: The same glow recipe is being applied to a noticeably smaller surface, which explains why pinned text glow feels disproportionately large.

- timestamp: 2026-04-13T19:29:33+08:00
  checked: UI/DesktopText/PinnedTextContentView.swift
  found: The separate black card shadow is configured in setupCardLayer and does not change across idle, hover, or mark states.
  implication: The state-specific blue and orange spread issue originates in glowLayer tuning rather than the static card shadow.

- timestamp: 2026-04-13T19:33:13+08:00
  checked: UI/Theme/DesignTokens.swift, UI/DesktopText/PinnedTextContentView.swift, UI/Screenshot/ScreenshotContentView.swift, Tests/PinnedTextWindowStateTests.swift
  found: Added separate pinned-text glow tuning in DesignTokens, wired pinned text to the tighter hover and mark styles, and kept screenshot cards on their previous glow values; added a regression test that asserts pinned text hover and mark remain tighter than screenshot cards.
  implication: The fix targets the confirmed proportional mismatch without changing screenshot overlay behavior.

- timestamp: 2026-04-13T19:33:13+08:00
  checked: swift build; swift test --filter PinnedTextWindowStateTests; swift test
  found: Build passed, targeted pinned text tests passed including the new glow regression, and the full test suite passed with the existing AX smoke tests skipped by configuration.
  implication: The code change is internally verified and ready for live visual confirmation.

## Resolution

root_cause: PinnedTextContentView reused the same hover and mark glow radius and opacity values as ScreenshotContentView even though pinned text cards are much smaller, so the same glow recipe spread too far and visually dominated the card.
fix: Introduced surface-specific glow style tokens, kept screenshot glow values unchanged, and switched pinned text hover and mark states to tighter shadow radius and opacity values while preserving the same state colors and line width; added a regression test that locks pinned text glow tuning below screenshot glow tuning.
verification: swift build; swift test --filter PinnedTextWindowStateTests; swift test
files_changed:
  - UI/Theme/DesignTokens.swift
  - UI/DesktopText/PinnedTextContentView.swift
  - UI/Screenshot/ScreenshotContentView.swift
  - Tests/PinnedTextWindowStateTests.swift
