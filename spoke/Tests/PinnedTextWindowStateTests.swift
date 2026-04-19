import AppKit
import Testing
@testable import SpokenAnyWhere

@Suite("PinnedText 窗口状态测试", .serialized)
@MainActor
struct PinnedTextWindowStateTests {
    private final class SaveCounter {
        var saves = 0
    }

    private func makeMouseEvent(
        window: NSWindow,
        type: NSEvent.EventType,
        location: CGPoint,
        clickCount: Int
    ) throws -> NSEvent {
        if type == .mouseEntered || type == .mouseExited {
            return try #require(
                NSEvent.enterExitEvent(
                    with: type,
                    location: location,
                    modifierFlags: [],
                    timestamp: 0,
                    windowNumber: window.windowNumber,
                    context: nil,
                    eventNumber: 0,
                    trackingNumber: 0,
                    userData: nil
                )
            )
        }

        return try #require(
            NSEvent.mouseEvent(
                with: type,
                location: location,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: clickCount,
                pressure: 1
            )
        )
    }

    private func makeScrollEvent(
        deltaX: Int32 = 0,
        deltaY: Int32 = 0,
        precise: Bool = true,
        modifiers: NSEvent.ModifierFlags = [],
        phase: NSEvent.Phase = .changed
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
        cgEvent.flags = CGEventFlags(rawValue: UInt64(modifiers.rawValue))

        if precise {
            cgEvent.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
            cgEvent.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(phase.rawValue))
            cgEvent.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: Int64(deltaY))
            cgEvent.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: Int64(deltaX))
        }

        return try #require(NSEvent(cgEvent: cgEvent))
    }

    private func makeWindow() -> (PinnedTextWindow, SaveCounter) {
        makeWindow(
            text: "# Preview\n- item",
            frame: CGRect(x: 0, y: 0, width: 360, height: 220)
        )
    }

    private func makeWindow(
        text: String,
        frame: CGRect
    ) -> (PinnedTextWindow, SaveCounter) {
        let item = PinnedTextItem(
            text: text,
            frame: frame
        )
        let counter = SaveCounter()

        let dependencies = PinnedTextActionDependencies(
            togglePin: { item in item.isPinned.toggle() },
            toggleLock: { item in item.isLocked.toggle() },
            toggleMark: { item in item.isMarked.toggle() },
            updateWindowCollectionBehavior: { _ in },
            updateWindowMovable: { _ in },
            updateWindowGlow: { _ in },
            closeWindow: { _ in },
            saveWindowState: { counter.saves += 1 }
        )

        return (PinnedTextWindow(item: item, dependencies: dependencies), counter)
    }

    private func makeScrollablePreviewText(lineCount: Int = 80) -> String {
        let lines = (1...lineCount).map { index in
            "- item \(index): preview body line \(index)"
        }
        return "# Preview\n" + lines.joined(separator: "\n")
    }

    private func prepareContentForInteraction(
        _ content: PinnedTextContentView,
        in window: NSWindow
    ) {
        content.frame = CGRect(origin: .zero, size: window.frame.size)
        window.contentView = content
        content.layoutSubtreeIfNeeded()
        content.displayIfNeeded()
        window.displayIfNeeded()
    }

    @Test("preview mode keeps vertical scroll for content and uses horizontal scroll for opacity")
    func scrollWheelUsesVerticalForContentAndHorizontalForOpacity() throws {
        let (window, counter) = makeWindow()

        let originalZoom = window.item.zoomLevel
        let originalOpacity = window.item.opacity

        window.scrollWheel(with: try makeScrollEvent(deltaY: 20, precise: true))
        #expect(window.item.zoomLevel == originalZoom)

        window.scrollWheel(with: try makeScrollEvent(deltaX: -40, precise: true))
        #expect(window.item.opacity < originalOpacity)
        #expect(counter.saves >= 1)
    }

    @Test("unfocused hover vertical scroll updates zoom instead of scrolling content")
    func unfocusedHoverVerticalScrollZooms() throws {
        let (window, counter) = makeWindow(
            text: makeScrollablePreviewText(),
            frame: CGRect(x: 0, y: 0, width: 360, height: 160)
        )
        let content = try #require(window.pinnedTextContentView)
        prepareContentForInteraction(content, in: window)

        content.mouseEntered(with: try makeMouseEvent(
            window: window,
            type: .mouseEntered,
            location: CGPoint(x: 80, y: 80),
            clickCount: 0
        ))

        let originalZoom = window.item.zoomLevel
        let originalForwardedScrollCount = content.forwardedVerticalScrollCountForTesting
        let originalOffset = content.previewScrollOriginYForTesting
        let scrollEvent = try makeScrollEvent(deltaY: -30, precise: true)

        #expect(scrollEvent.hasPreciseScrollingDeltas == true)
        window.scrollWheel(with: scrollEvent)

        #expect(window.item.zoomLevel != originalZoom)
        #expect(content.forwardedVerticalScrollCountForTesting == originalForwardedScrollCount)
        #expect(content.previewScrollOriginYForTesting == originalOffset)
        #expect(counter.saves >= 1)
    }

    @Test("Shift vertical scroll in unfocused hover scrolls content without changing zoom")
    func unfocusedHoverShiftVerticalScrollTemporarilyScrolls() throws {
        let (window, _) = makeWindow(
            text: makeScrollablePreviewText(),
            frame: CGRect(x: 0, y: 0, width: 360, height: 160)
        )
        let content = try #require(window.pinnedTextContentView)
        prepareContentForInteraction(content, in: window)

        content.mouseEntered(with: try makeMouseEvent(
            window: window,
            type: .mouseEntered,
            location: CGPoint(x: 80, y: 80),
            clickCount: 0
        ))

        let originalZoom = window.item.zoomLevel
        let originalForwardedScrollCount = content.forwardedVerticalScrollCountForTesting
        let scrollEvent = try makeScrollEvent(deltaY: -30, precise: true, modifiers: [.shift])

        #expect(scrollEvent.hasPreciseScrollingDeltas == true)
        window.scrollWheel(with: scrollEvent)

        #expect(window.item.zoomLevel == originalZoom)
        #expect(content.forwardedVerticalScrollCountForTesting > originalForwardedScrollCount)
    }

    @Test("click enters focused browsing and mouse exit clears it")
    func clickFocusesAndMouseExitClearsFocusedBrowsing() throws {
        let (window, _) = makeWindow(
            text: makeScrollablePreviewText(),
            frame: CGRect(x: 0, y: 0, width: 360, height: 160)
        )
        let content = try #require(window.pinnedTextContentView)
        prepareContentForInteraction(content, in: window)

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

    @Test("double click enters editing and commit persists updated markdown source")
    func doubleClickEntersEditingAndCommitPersists() throws {
        let (window, counter) = makeWindow()
        let content = try #require(window.pinnedTextContentView)
        window.contentView = content

        content.mouseDown(with: try makeMouseEvent(
            window: window,
            type: .leftMouseDown,
            location: CGPoint(x: 40, y: 40),
            clickCount: 2
        ))

        #expect(content.isEditing == true)

        let editor = try #require(content.activeEditorTextView)
        editor.string = "# Updated\n- second"
        content.commitEditingIfNeeded()

        #expect(content.isEditing == false)
        #expect(window.item.text == "# Updated\n- second")
        #expect(counter.saves >= 1)
    }

    @Test("losing focus after editing preserves a user-resized frame")
    func resignKeyAfterEditingPreservesManualFrame() throws {
        let (window, counter) = makeWindow()
        let content = try #require(window.pinnedTextContentView)
        window.contentView = content

        let resizedFrame = CGRect(x: 0, y: 0, width: 520, height: 220)
        window.setFrame(resizedFrame, display: true)
        window.item.frame = resizedFrame
        window.onFrameChanged = { newFrame in
            window.item.frame = newFrame
        }

        content.mouseDown(with: try makeMouseEvent(
            window: window,
            type: .leftMouseDown,
            location: CGPoint(x: 40, y: 40),
            clickCount: 2
        ))

        #expect(content.isEditing == true)

        let editor = try #require(content.activeEditorTextView)
        editor.string = "# Updated\n- second"

        window.resignKey()

        #expect(content.isEditing == false)
        #expect(window.item.text == "# Updated\n- second")
        #expect(window.frame.equalTo(resizedFrame))
        #expect(window.item.frame.equalTo(resizedFrame))
        #expect(counter.saves >= 1)
    }

    @Test("resize affordance uses hand cursors on edges and corners, arrow in the center")
    func resizeAffordanceUsesResizeCursors() {
        let (window, _) = makeWindow()
        let leftCursor = window.resolvedCursor(for: .left)
        let rightCursor = window.resolvedCursor(for: .right)
        let topCursor = window.resolvedCursor(for: .top)
        let bottomCursor = window.resolvedCursor(for: .bottom)
        let topLeftCursor = window.resolvedCursor(for: .topLeft)
        let topRightCursor = window.resolvedCursor(for: .topRight)

        #expect(window.resolvedCursor(for: .none) === NSCursor.arrow)
        #expect(leftCursor === rightCursor)
        #expect(topCursor === bottomCursor)
        #expect(leftCursor === NSCursor.openHand)
        #expect(topCursor === NSCursor.openHand)
        #expect(topLeftCursor === NSCursor.openHand)
        #expect(topRightCursor === NSCursor.openHand)
    }

    @Test("pinned text glow follows screenshot card reference semantics")
    func pinnedTextGlowFollowsScreenshotCardReferenceSemantics() {
        let hoverStyle = PinnedTextContentView.glowStyle(isHovered: true, isMarked: false, isPinned: true)
        let markStyle = PinnedTextContentView.glowStyle(isHovered: false, isMarked: true, isPinned: true)
        let pinnedIdleStyle = PinnedTextContentView.glowStyle(isHovered: false, isMarked: false, isPinned: true)
        let unpinnedIdleStyle = PinnedTextContentView.glowStyle(isHovered: false, isMarked: false, isPinned: false)

        #expect(hoverStyle == DesignTokens.Glow.ScreenshotCard.hover)
        #expect(markStyle == DesignTokens.Glow.ScreenshotCard.mark)
        #expect(pinnedIdleStyle == DesignTokens.Glow.ScreenshotCard.idle)
        #expect(unpinnedIdleStyle == nil)

        #expect(DesignTokens.BorderWidth.none == 0)
        #expect(DesignTokens.Shadow.PinnedText.card.opacity == 0)
        #expect(DesignTokens.Shadow.PinnedText.card.radius == 0)
        #expect(DesignTokens.Glow.PinnedText.hover == DesignTokens.Glow.ScreenshotCard.hover)
        #expect(DesignTokens.Glow.PinnedText.mark == DesignTokens.Glow.ScreenshotCard.mark)
        #expect(DesignTokens.Glow.PinnedText.idle == DesignTokens.Glow.ScreenshotCard.idle)
        #expect(DesignTokens.Glow.PinnedText.hover.fillOpacity == 0)
        #expect(DesignTokens.Glow.PinnedText.mark.fillOpacity == 0)
        #expect(PinnedTextMarkdownRenderer.windowGlowPadding == ScreenshotContentView.paddingPerSide)

        let idleGlowColor = DesignTokens.Colors.NS.glowIdle.usingColorSpace(.deviceRGB)
        #expect(idleGlowColor?.redComponent == 0)
        #expect(idleGlowColor?.greenComponent == 0)
        #expect(idleGlowColor?.blueComponent == 0)
        #expect(idleGlowColor?.alphaComponent == 1)
    }

    @Test("hover glow layer uses transparent fill and stroked shadow source")
    func hoverGlowLayerUsesTransparentFillAndStrokedShadowSource() throws {
        let (window, _) = makeWindow()
        let content = try #require(window.pinnedTextContentView)
        content.frame = CGRect(origin: .zero, size: window.frame.size)

        window.handleHoverChanged(true, locationInWindow: CGPoint(x: 80, y: 80))
        content.layoutSubtreeIfNeeded()

        let glowLayer = try #require(
            content.layer?.sublayers?
                .compactMap { $0 as? CAShapeLayer }
                .first { $0.zPosition == -2 }
        )

        #expect(glowLayer.fillColor?.alpha == 0)
        #expect(glowLayer.strokeColor != nil)
        #expect(glowLayer.lineWidth == DesignTokens.Glow.ScreenshotCard.hover.lineWidth)
        #expect(glowLayer.shadowRadius == DesignTokens.Glow.ScreenshotCard.hover.shadowRadius)
        #expect(glowLayer.shadowOpacity == DesignTokens.Glow.ScreenshotCard.hover.shadowOpacity)
        #expect(glowLayer.shadowPath != nil)
    }

    @Test("right click context menu exposes text and window actions")
    func rightClickContextMenuExposesTextAndWindowActions() throws {
        let (window, _) = makeWindow()
        let content = try #require(window.pinnedTextContentView)
        window.contentView = content

        let menu = try #require(content.menu(for: makeMouseEvent(
            window: window,
            type: .rightMouseDown,
            location: CGPoint(x: 40, y: 40),
            clickCount: 1
        )))
        let titles = menu.items.filter { !$0.isSeparatorItem }.map(\.title)

        #expect(titles.contains("Copy Text (T)"))
        #expect(titles.contains("Copy Image (C)"))
        #expect(titles.contains("Unpin (P)"))
        #expect(titles.contains("Lock (L)"))
        #expect(titles.contains("Mark (M)"))
        #expect(titles.contains("Close (Q)"))

        window.item.isPinned = false
        window.item.isLocked = true
        window.item.isMarked = true

        let updatedTitles = content.contextMenuItemTitles()
        #expect(updatedTitles.contains("Pin to Space (P)"))
        #expect(updatedTitles.contains("Unlock (L)"))
        #expect(updatedTitles.contains("Unmark (M)"))
    }

    @Test("editing state keeps the pinned text context menu")
    func editingStateKeepsPinnedTextContextMenu() throws {
        let (window, _) = makeWindow()
        let content = try #require(window.pinnedTextContentView)
        window.contentView = content

        content.mouseDown(with: try makeMouseEvent(
            window: window,
            type: .leftMouseDown,
            location: CGPoint(x: 40, y: 40),
            clickCount: 2
        ))

        let editor = try #require(content.activeEditorTextView)
        let menu = try #require(editor.menu(for: makeMouseEvent(
            window: window,
            type: .rightMouseDown,
            location: CGPoint(x: 40, y: 40),
            clickCount: 1
        )))
        let titles = menu.items.filter { !$0.isSeparatorItem }.map(\.title)

        #expect(titles.contains("Copy Text (T)"))
        #expect(titles.contains("Copy Image (C)"))
        #expect(titles.contains("Close (Q)"))
    }

    @Test("editor typography matches preview body rhythm")
    func editorTypographyMatchesPreviewBodyRhythm() throws {
        let (window, _) = makeWindow()
        let content = try #require(window.pinnedTextContentView)
        window.contentView = content

        content.mouseDown(with: try makeMouseEvent(
            window: window,
            type: .leftMouseDown,
            location: CGPoint(x: 40, y: 40),
            clickCount: 2
        ))

        let editor = try #require(content.activeEditorTextView)
        let editorFont = try #require(editor.font)
        let paragraph = try #require(editor.defaultParagraphStyle)
        let storedParagraph = try #require(
            editor.textStorage?.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        )

        #expect(editorFont.pointSize == PinnedTextMarkdownRenderer.bodyFont(for: window.item.zoomLevel).pointSize)
        #expect(paragraph.lineSpacing == PinnedTextMarkdownRenderer.bodyLineSpacing)
        #expect(paragraph.paragraphSpacing == PinnedTextMarkdownRenderer.bodyParagraphSpacing)
        #expect(storedParagraph.lineSpacing == PinnedTextMarkdownRenderer.bodyLineSpacing)
        #expect(storedParagraph.paragraphSpacing == PinnedTextMarkdownRenderer.bodyParagraphSpacing)
    }

}
