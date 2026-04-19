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

    private func advanceMainLoop(by seconds: TimeInterval = 0.2) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private func itemFramesMatch(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat = 0.001) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) <= tolerance &&
        abs(lhs.origin.y - rhs.origin.y) <= tolerance &&
        abs(lhs.size.width - rhs.size.width) <= tolerance &&
        abs(lhs.size.height - rhs.size.height) <= tolerance
    }

    private func sizesMatch(_ lhs: CGSize, _ rhs: CGSize, tolerance: CGFloat = 0.5) -> Bool {
        abs(lhs.width - rhs.width) <= tolerance &&
        abs(lhs.height - rhs.height) <= tolerance
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

    @Test("preview mode vertical scroll does not create preview zoom")
    func previewModeVerticalScrollDoesNotCreatePreviewZoom() throws {
        let (window, _) = makeWindow(
            text: makeScrollablePreviewText(),
            frame: CGRect(x: 0, y: 0, width: 360, height: 160)
        )
        let content = try #require(window.pinnedTextContentView)
        prepareContentForInteraction(content, in: window)

        let originalZoom = window.item.zoomLevel
        let originalForwardedScrollCount = content.forwardedVerticalScrollCountForTesting

        window.scrollWheel(with: try makeScrollEvent(deltaY: 30, precise: true))

        #expect(content.forwardedVerticalScrollCountForTesting > originalForwardedScrollCount)
        #expect(content.previewZoomForTesting == originalZoom)
        #expect(window.item.zoomLevel == originalZoom)
    }

    @Test("horizontal precise scroll while hover unfocused does not create preview zoom")
    func horizontalPreciseScrollDoesNotCreatePreviewZoom() throws {
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
        let originalOpacity = window.item.opacity

        window.scrollWheel(with: try makeScrollEvent(deltaX: -40, precise: true))

        #expect(window.item.opacity < originalOpacity)
        #expect(content.previewZoomForTesting == originalZoom)
        #expect(window.item.zoomLevel == originalZoom)
        #expect(counter.saves >= 1)
    }

    @Test("horizontal precise scroll during preview zoom cancels pending commit")
    func horizontalPreciseScrollDuringPreviewZoomCancelsPendingCommit() throws {
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

        let committedZoom = window.item.zoomLevel
        let committedFrame = window.frame
        let originalOpacity = window.item.opacity
        window.scrollWheel(with: try makeScrollEvent(deltaY: 30, precise: true))

        #expect(content.previewZoomForTesting > committedZoom)
        #expect(window.item.zoomLevel == committedZoom)
        #expect(window.frame.width > committedFrame.width)
        #expect(window.frame.height > committedFrame.height)

        window.scrollWheel(with: try makeScrollEvent(deltaX: -40, precise: true))
        advanceMainLoop()

        #expect(window.item.opacity < originalOpacity)
        #expect(counter.saves >= 1)
        #expect(window.item.zoomLevel == committedZoom)
        #expect(content.previewZoomForTesting == committedZoom)
        #expect(itemFramesMatch(window.frame, committedFrame, tolerance: 0.5))
        #expect(itemFramesMatch(window.item.frame, committedFrame, tolerance: 0.5))
        #expect(abs(content.previewScaleForTesting - 1.0) <= 0.0001)
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
        let scrollEvent = try makeScrollEvent(deltaY: 30, precise: true)
        let endEvent = try makeScrollEvent(deltaY: 0, precise: true, phase: .ended)

        #expect(scrollEvent.hasPreciseScrollingDeltas == true)
        window.scrollWheel(with: scrollEvent)

        #expect(content.previewZoomForTesting > originalZoom)
        #expect(window.item.zoomLevel == originalZoom)
        #expect(content.forwardedVerticalScrollCountForTesting == originalForwardedScrollCount)
        #expect(content.previewScrollOriginYForTesting == originalOffset)
        #expect(counter.saves == 0)

        window.scrollWheel(with: endEvent)

        #expect(window.item.zoomLevel != originalZoom)
        #expect(content.previewZoomForTesting == window.item.zoomLevel)
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

    @Test("shift override during preview zoom cancels pending commit")
    func shiftOverrideDuringPreviewZoomCancelsPendingCommit() throws {
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

        let committedZoom = window.item.zoomLevel
        let committedFrame = window.frame
        window.scrollWheel(with: try makeScrollEvent(deltaY: 30, precise: true))

        #expect(content.previewZoomForTesting > committedZoom)
        #expect(window.item.zoomLevel == committedZoom)
        #expect(window.frame.width > committedFrame.width)
        #expect(window.frame.height > committedFrame.height)

        let originalForwardedScrollCount = content.forwardedVerticalScrollCountForTesting
        window.scrollWheel(with: try makeScrollEvent(deltaY: -30, precise: true, modifiers: [.shift]))

        advanceMainLoop()

        #expect(content.forwardedVerticalScrollCountForTesting > originalForwardedScrollCount)
        #expect(window.item.zoomLevel == committedZoom)
        #expect(content.previewZoomForTesting == committedZoom)
        #expect(itemFramesMatch(window.frame, committedFrame, tolerance: 0.5))
        #expect(itemFramesMatch(window.item.frame, committedFrame, tolerance: 0.5))
        #expect(abs(content.previewScaleForTesting - 1.0) <= 0.0001)
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

    @Test("focused browsing vertical scroll does not create preview zoom")
    func focusedBrowsingVerticalScrollDoesNotCreatePreviewZoom() throws {
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

        let originalZoom = window.item.zoomLevel
        let originalForwardedScrollCount = content.forwardedVerticalScrollCountForTesting

        window.scrollWheel(with: try makeScrollEvent(deltaY: 30, precise: true))

        #expect(content.isFocusedBrowsingForTesting == true)
        #expect(content.forwardedVerticalScrollCountForTesting > originalForwardedScrollCount)
        #expect(content.previewZoomForTesting == originalZoom)
        #expect(window.item.zoomLevel == originalZoom)
    }

    @Test("focused browsing horizontal precise scroll changes opacity without preview zoom")
    func focusedBrowsingHorizontalScrollChangesOpacityWithoutPreviewZoom() throws {
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

        let originalZoom = window.item.zoomLevel
        let originalOpacity = window.item.opacity

        window.scrollWheel(with: try makeScrollEvent(deltaX: -40, precise: true))

        #expect(content.isFocusedBrowsingForTesting == true)
        #expect(window.item.opacity < originalOpacity)
        #expect(content.previewZoomForTesting == originalZoom)
        #expect(window.item.zoomLevel == originalZoom)
        #expect(counter.saves >= 1)
    }

    @Test("entering focused browsing during preview zoom cancels pending commit")
    func enteringFocusedBrowsingDuringPreviewZoomCancelsPendingCommit() throws {
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

        let committedZoom = window.item.zoomLevel
        let committedFrame = window.frame
        window.scrollWheel(with: try makeScrollEvent(deltaY: 30, precise: true))

        #expect(content.previewZoomForTesting > committedZoom)
        #expect(window.item.zoomLevel == committedZoom)
        #expect(window.frame.width > committedFrame.width)
        #expect(window.frame.height > committedFrame.height)

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

        advanceMainLoop()

        #expect(content.isFocusedBrowsingForTesting == true)
        #expect(window.item.zoomLevel == committedZoom)
        #expect(content.previewZoomForTesting == committedZoom)
        #expect(itemFramesMatch(window.frame, committedFrame, tolerance: 0.5))
        #expect(itemFramesMatch(window.item.frame, committedFrame, tolerance: 0.5))
        #expect(abs(content.previewScaleForTesting - 1.0) <= 0.0001)
    }

    @Test("immediate window drag does not leave focused browsing enabled")
    func immediateWindowDragDoesNotFocusBrowsing() throws {
        let (window, _) = makeWindow(
            text: makeScrollablePreviewText(),
            frame: CGRect(x: 20, y: 30, width: 360, height: 160)
        )
        let content = try #require(window.pinnedTextContentView)
        prepareContentForInteraction(content, in: window)

        content.mouseEntered(with: try makeMouseEvent(
            window: window,
            type: .mouseEntered,
            location: CGPoint(x: 80, y: 80),
            clickCount: 0
        ))

        window.performDragHandlerForTesting = { _ in
            let draggedFrame = CGRect(x: 70, y: 90, width: 360, height: 160)
            window.setFrame(draggedFrame, display: true)
            window.item.frame = draggedFrame
        }

        content.mouseDown(with: try makeMouseEvent(
            window: window,
            type: .leftMouseDown,
            location: CGPoint(x: 80, y: 80),
            clickCount: 1
        ))

        #expect(content.isFocusedBrowsingForTesting == false)
    }

    @Test("drag handler call without net frame change still does not focus browsing")
    func dragHandlerWithoutNetFrameChangeDoesNotFocusBrowsing() throws {
        let (window, _) = makeWindow(
            text: makeScrollablePreviewText(),
            frame: CGRect(x: 20, y: 30, width: 360, height: 160)
        )
        let content = try #require(window.pinnedTextContentView)
        prepareContentForInteraction(content, in: window)

        content.mouseEntered(with: try makeMouseEvent(
            window: window,
            type: .mouseEntered,
            location: CGPoint(x: 80, y: 80),
            clickCount: 0
        ))

        var dragCalls = 0
        window.performDragHandlerForTesting = { _ in
            dragCalls += 1
        }

        content.mouseDown(with: try makeMouseEvent(
            window: window,
            type: .leftMouseDown,
            location: CGPoint(x: 80, y: 80),
            clickCount: 1
        ))

        #expect(dragCalls == 1)
        #expect(content.isFocusedBrowsingForTesting == false)
    }

    @Test("resize affordance remains available just outside the card edge")
    func resizeAffordanceStillWorksOutsideCardEdge() throws {
        let (window, _) = makeWindow()
        let content = try #require(window.pinnedTextContentView)
        prepareContentForInteraction(content, in: window)

        let cardFrame = content.interactiveCardFrame()
        let resizeEdgePoint = CGPoint(x: cardFrame.minX - 4, y: cardFrame.midY)

        content.mouseDown(with: try makeMouseEvent(
            window: window,
            type: .leftMouseDown,
            location: resizeEdgePoint,
            clickCount: 1
        ))

        #expect(window.activeResizeRegionForTesting == .left)
    }

    @Test("entering resize interaction during preview zoom cancels pending commit")
    func enteringResizeInteractionDuringPreviewZoomCancelsPendingCommit() throws {
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

        let committedZoom = window.item.zoomLevel
        window.scrollWheel(with: try makeScrollEvent(deltaY: 30, precise: true))

        #expect(content.previewZoomForTesting > committedZoom)
        #expect(window.item.zoomLevel == committedZoom)

        let cardFrame = content.interactiveCardFrame()
        let resizeEdgePoint = CGPoint(x: cardFrame.minX - 4, y: cardFrame.midY)

        content.mouseDown(with: try makeMouseEvent(
            window: window,
            type: .leftMouseDown,
            location: resizeEdgePoint,
            clickCount: 1
        ))

        advanceMainLoop()

        #expect(window.activeResizeRegionForTesting == .left)
        #expect(window.item.zoomLevel == committedZoom)
        #expect(content.previewZoomForTesting == committedZoom)
    }

    @Test("unfocused hover zoom keeps center anchored and publishes updated frame")
    func unfocusedHoverZoomKeepsCenterAndPublishesFrame() throws {
        let (window, counter) = makeWindow(
            text: makeScrollablePreviewText(),
            frame: CGRect(x: 40, y: 50, width: 360, height: 160)
        )
        let content = try #require(window.pinnedTextContentView)
        prepareContentForInteraction(content, in: window)

        var receivedFrames: [CGRect] = []
        window.onFrameChanged = { frame in
            receivedFrames.append(frame)
        }

        content.mouseEntered(with: try makeMouseEvent(
            window: window,
            type: .mouseEntered,
            location: CGPoint(x: 90, y: 80),
            clickCount: 0
        ))

        let originalFrame = window.frame
        let originalCenter = CGPoint(x: originalFrame.midX, y: originalFrame.midY)

        let scrollEvent = try makeScrollEvent(deltaY: 30, precise: true)
        let endEvent = try makeScrollEvent(deltaY: 0, precise: true, phase: .ended)

        window.scrollWheel(with: scrollEvent)

        #expect(window.item.zoomLevel == 1.0)
        #expect(receivedFrames.isEmpty)
        #expect(counter.saves == 0)

        window.scrollWheel(with: endEvent)

        let committedFrame = window.frame
        let committedCenter = CGPoint(x: committedFrame.midX, y: committedFrame.midY)

        #expect(abs(committedCenter.x - originalCenter.x) <= 0.5)
        #expect(abs(committedCenter.y - originalCenter.y) <= 0.5)
        #expect(window.item.frame.equalTo(committedFrame))
        #expect(receivedFrames.last?.equalTo(committedFrame) == true)
        #expect(counter.saves >= 1)
    }

    @Test("unfocused hover zoom publishes exactly one committed frame update")
    func unfocusedHoverZoomPublishesSingleCommittedFrameUpdate() throws {
        let (window, _) = makeWindow(
            text: makeScrollablePreviewText(),
            frame: CGRect(x: 40, y: 50, width: 360, height: 160)
        )
        let content = try #require(window.pinnedTextContentView)
        prepareContentForInteraction(content, in: window)

        var receivedFrames: [CGRect] = []
        window.onFrameChanged = { frame in
            receivedFrames.append(frame)
        }

        content.mouseEntered(with: try makeMouseEvent(
            window: window,
            type: .mouseEntered,
            location: CGPoint(x: 90, y: 80),
            clickCount: 0
        ))

        window.scrollWheel(with: try makeScrollEvent(deltaY: 30, precise: true))
        #expect(receivedFrames.isEmpty)

        window.scrollWheel(with: try makeScrollEvent(deltaY: 0, precise: true, phase: .ended))

        #expect(receivedFrames.count == 1)
        #expect(receivedFrames.last?.equalTo(window.frame) == true)
    }

    @Test("active zoom gesture keeps preview zoom separate from committed item zoom")
    func activeZoomGestureUsesPreviewZoomBeforeCommit() throws {
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

        let committedZoom = window.item.zoomLevel
        window.beginPreviewZoomForTesting(deltaY: 20)

        #expect(content.previewZoomForTesting > committedZoom)
        #expect(window.item.zoomLevel == committedZoom)
    }

    @Test("active preview zoom uses renderer preferred size for the visible card")
    func activePreviewZoomUsesRendererPreferredSizeForVisibleCard() throws {
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

        window.beginPreviewZoomForTesting(deltaY: 20)

        let previewZoom = content.previewZoomForTesting
        let expectedSize = PinnedTextMarkdownRenderer.preferredWindowSize(
            text: window.item.text,
            zoomLevel: previewZoom
        )

        #expect(sizesMatch(window.frame.size, expectedSize))
        #expect(window.item.zoomLevel < previewZoom)
    }

    @Test("active preview zoom grows the visible card and cancellation restores the committed frame")
    func activePreviewZoomGrowsVisibleCardAndCancellationRestoresCommittedFrame() throws {
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

        let committedFrame = window.frame
        let committedZoom = window.item.zoomLevel

        window.scrollWheel(with: try makeScrollEvent(deltaY: 30, precise: true))

        #expect(content.previewZoomForTesting > committedZoom)
        #expect(window.item.zoomLevel == committedZoom)
        #expect(window.frame.width > committedFrame.width)
        #expect(window.frame.height > committedFrame.height)
        #expect(itemFramesMatch(window.item.frame, committedFrame))

        content.mouseExited(with: try makeMouseEvent(
            window: window,
            type: .mouseExited,
            location: CGPoint(x: 500, y: 500),
            clickCount: 0
        ))

        #expect(itemFramesMatch(window.frame, committedFrame))
        #expect(window.item.zoomLevel == committedZoom)
        #expect(content.previewZoomForTesting == committedZoom)
        #expect(abs(content.previewScaleForTesting - 1.0) <= 0.0001)
    }

    @Test("committing preview zoom keeps the preview-sized frame without an extra jump")
    func committingPreviewZoomKeepsPreviewSizedFrameWithoutExtraJump() throws {
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

        window.scrollWheel(with: try makeScrollEvent(deltaY: 30, precise: true))
        let previewFrame = window.frame

        window.scrollWheel(with: try makeScrollEvent(deltaY: 0, precise: true, phase: .ended))

        #expect(itemFramesMatch(window.frame, previewFrame, tolerance: 0.5))
        #expect(itemFramesMatch(window.item.frame, previewFrame, tolerance: 0.5))
        #expect(abs(content.previewScaleForTesting - 1.0) <= 0.0001)
    }

    @Test("double click entering edit during preview zoom cancels pending commit")
    func doubleClickEnteringEditDuringPreviewZoomCancelsPendingCommit() throws {
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

        let committedZoom = window.item.zoomLevel
        window.scrollWheel(with: try makeScrollEvent(deltaY: 30, precise: true))

        #expect(content.previewZoomForTesting > committedZoom)
        #expect(window.item.zoomLevel == committedZoom)

        content.mouseDown(with: try makeMouseEvent(
            window: window,
            type: .leftMouseDown,
            location: CGPoint(x: 80, y: 80),
            clickCount: 2
        ))

        advanceMainLoop()

        #expect(content.isEditing == true)
        #expect(window.item.zoomLevel == committedZoom)
        #expect(content.previewZoomForTesting == committedZoom)
    }

    @Test("mouse exit during preview zoom cancels pending commit")
    func mouseExitDuringPreviewZoomCancelsPendingCommit() throws {
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

        let committedZoom = window.item.zoomLevel
        window.scrollWheel(with: try makeScrollEvent(deltaY: 30, precise: true))

        #expect(content.previewZoomForTesting > committedZoom)
        #expect(window.item.zoomLevel == committedZoom)

        content.mouseExited(with: try makeMouseEvent(
            window: window,
            type: .mouseExited,
            location: CGPoint(x: 500, y: 500),
            clickCount: 0
        ))

        window.scrollWheel(with: try makeScrollEvent(deltaY: 0, precise: true, phase: .ended))

        #expect(window.item.zoomLevel == committedZoom)
        #expect(content.previewZoomForTesting == committedZoom)
    }

    @Test("multiple preview cancellation paths remain idempotent")
    func multiplePreviewCancellationPathsRemainIdempotent() throws {
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

        let committedZoom = window.item.zoomLevel
        window.scrollWheel(with: try makeScrollEvent(deltaY: 30, precise: true))

        #expect(content.previewZoomForTesting > committedZoom)
        #expect(content.previewScaleForTesting > 1.0)

        content.mouseExited(with: try makeMouseEvent(
            window: window,
            type: .mouseExited,
            location: CGPoint(x: 500, y: 500),
            clickCount: 0
        ))
        window.resignKey()

        #expect(window.item.zoomLevel == committedZoom)
        #expect(content.previewZoomForTesting == committedZoom)
        #expect(abs(content.previewScaleForTesting - 1.0) <= 0.0001)
    }

    @Test("preview zoom visual scale resets after commit")
    func previewZoomVisualScaleResetsAfterCommit() throws {
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

        window.scrollWheel(with: try makeScrollEvent(deltaY: 30, precise: true))

        #expect(content.previewScaleForTesting > 1.0)
        #expect(window.item.zoomLevel == 1.0)

        window.scrollWheel(with: try makeScrollEvent(deltaY: 0, precise: true, phase: .ended))

        #expect(window.item.zoomLevel > 1.0)
        #expect(abs(content.previewScaleForTesting - 1.0) <= 0.0001)
    }

    @Test("multiple preview zoom gestures accumulate before a single ended commit")
    func multiplePreviewZoomGesturesAccumulateBeforeCommit() throws {
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

        let committedZoom = window.item.zoomLevel
        let firstChanged = try makeScrollEvent(deltaY: 30, precise: true)
        let secondChanged = try makeScrollEvent(deltaY: 30, precise: true)
        let endEvent = try makeScrollEvent(deltaY: 0, precise: true, phase: .ended)

        window.scrollWheel(with: firstChanged)
        let firstPreviewZoom = content.previewZoomForTesting

        #expect(firstPreviewZoom > committedZoom)
        #expect(window.item.zoomLevel == committedZoom)

        window.scrollWheel(with: secondChanged)
        let secondPreviewZoom = content.previewZoomForTesting

        #expect(secondPreviewZoom > firstPreviewZoom)
        #expect(window.item.zoomLevel == committedZoom)

        window.scrollWheel(with: endEvent)

        #expect(window.item.zoomLevel == secondPreviewZoom)
        #expect(content.previewZoomForTesting == secondPreviewZoom)
    }

    @Test("preview zoom clamps at renderer max before and after commit")
    func previewZoomClampsAtRendererMax() throws {
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

        for _ in 0..<40 {
            window.scrollWheel(with: try makeScrollEvent(deltaY: 30, precise: true))
        }

        #expect(abs(content.previewZoomForTesting - PinnedTextMarkdownRenderer.maxZoomLevel) <= 0.0001)
        #expect(window.item.zoomLevel <= PinnedTextMarkdownRenderer.maxZoomLevel)

        window.scrollWheel(with: try makeScrollEvent(deltaY: 0, precise: true, phase: .ended))

        #expect(abs(window.item.zoomLevel - PinnedTextMarkdownRenderer.maxZoomLevel) <= 0.0001)
        #expect(abs(content.previewZoomForTesting - PinnedTextMarkdownRenderer.maxZoomLevel) <= 0.0001)
    }

    @Test("preview zoom clamps at renderer min before and after commit")
    func previewZoomClampsAtRendererMin() throws {
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

        for _ in 0..<40 {
            window.scrollWheel(with: try makeScrollEvent(deltaY: -30, precise: true))
        }

        #expect(abs(content.previewZoomForTesting - PinnedTextMarkdownRenderer.minZoomLevel) <= 0.0001)
        #expect(window.item.zoomLevel >= PinnedTextMarkdownRenderer.minZoomLevel)

        window.scrollWheel(with: try makeScrollEvent(deltaY: 0, precise: true, phase: .ended))

        #expect(abs(window.item.zoomLevel - PinnedTextMarkdownRenderer.minZoomLevel) <= 0.0001)
        #expect(abs(content.previewZoomForTesting - PinnedTextMarkdownRenderer.minZoomLevel) <= 0.0001)
    }

    @Test("non-precise hover zoom commits after delay without ended event")
    func nonPreciseHoverZoomCommitsAfterDelay() throws {
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

        let committedZoom = window.item.zoomLevel
        window.scrollWheel(with: try makeScrollEvent(deltaY: 3, precise: false))

        #expect(content.previewZoomForTesting > committedZoom)
        #expect(window.item.zoomLevel == committedZoom)
        #expect(counter.saves == 0)

        advanceMainLoop()

        #expect(window.item.zoomLevel > committedZoom)
        #expect(content.previewZoomForTesting == window.item.zoomLevel)
        #expect(counter.saves >= 1)
    }

    @Test("multiple non-precise hover zoom gestures commit the latest preview after one delay")
    func multipleNonPreciseHoverZoomGesturesCommitLatestPreview() throws {
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

        let committedZoom = window.item.zoomLevel
        window.scrollWheel(with: try makeScrollEvent(deltaY: 3, precise: false))
        let firstPreviewZoom = content.previewZoomForTesting

        #expect(firstPreviewZoom > committedZoom)
        #expect(window.item.zoomLevel == committedZoom)

        window.scrollWheel(with: try makeScrollEvent(deltaY: 3, precise: false))
        let secondPreviewZoom = content.previewZoomForTesting

        #expect(secondPreviewZoom > firstPreviewZoom)
        #expect(window.item.zoomLevel == committedZoom)
        #expect(counter.saves == 0)

        advanceMainLoop()

        #expect(window.item.zoomLevel == secondPreviewZoom)
        #expect(content.previewZoomForTesting == secondPreviewZoom)
        #expect(counter.saves >= 1)
    }

    @Test("resign key during preview zoom cancels pending commit")
    func resignKeyDuringPreviewZoomCancelsPendingCommit() throws {
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

        let committedZoom = window.item.zoomLevel
        let committedFrame = window.frame
        window.scrollWheel(with: try makeScrollEvent(deltaY: 30, precise: true))

        #expect(content.previewZoomForTesting > committedZoom)
        #expect(window.item.zoomLevel == committedZoom)
        #expect(window.frame.width > committedFrame.width)
        #expect(window.frame.height > committedFrame.height)

        window.resignKey()
        advanceMainLoop()

        #expect(window.item.zoomLevel == committedZoom)
        #expect(content.previewZoomForTesting == committedZoom)
        #expect(itemFramesMatch(window.frame, committedFrame, tolerance: 0.5))
        #expect(itemFramesMatch(window.item.frame, committedFrame, tolerance: 0.5))
        #expect(abs(content.previewScaleForTesting - 1.0) <= 0.0001)
    }

    @Test("double click enters editing and commit persists updated markdown source")
    func doubleClickEntersEditingAndCommitPersists() throws {
        let (window, counter) = makeWindow()
        let content = try #require(window.pinnedTextContentView)
        window.contentView = content
        let contentPoint = CGPoint(x: 80, y: 80)

        content.mouseDown(with: try makeMouseEvent(
            window: window,
            type: .leftMouseDown,
            location: contentPoint,
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
        let contentPoint = CGPoint(x: 80, y: 80)

        let resizedFrame = CGRect(x: 0, y: 0, width: 520, height: 220)
        window.setFrame(resizedFrame, display: true)
        window.item.frame = resizedFrame
        window.onFrameChanged = { newFrame in
            window.item.frame = newFrame
        }

        content.mouseDown(with: try makeMouseEvent(
            window: window,
            type: .leftMouseDown,
            location: contentPoint,
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
        let contentPoint = CGPoint(x: 80, y: 80)

        content.mouseDown(with: try makeMouseEvent(
            window: window,
            type: .leftMouseDown,
            location: contentPoint,
            clickCount: 2
        ))

        let editor = try #require(content.activeEditorTextView)
        let menu = try #require(editor.menu(for: makeMouseEvent(
            window: window,
            type: .rightMouseDown,
            location: contentPoint,
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
        let contentPoint = CGPoint(x: 80, y: 80)

        content.mouseDown(with: try makeMouseEvent(
            window: window,
            type: .leftMouseDown,
            location: contentPoint,
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
