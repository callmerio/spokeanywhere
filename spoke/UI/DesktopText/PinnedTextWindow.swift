import AppKit

@MainActor
final class PinnedTextWindow: NSPanel, NSWindowDelegate {
    enum ResizeRegion {
        case none
        case left
        case right
        case top
        case bottom
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight

        var isResizable: Bool { self != .none }
    }

    let item: PinnedTextItem
    private let dependencies: PinnedTextActionDependencies

    var onFrameChanged: ((CGRect) -> Void)?
    private(set) var pinnedTextContentView: PinnedTextContentView?
    private(set) var isHovered = false

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    private var activeResizeRegion: ResizeRegion = .none
    private var dragStartScreenPoint: CGPoint = .zero
    private var dragStartFrame: CGRect = .zero
    private var suppressManagedFrameCallbacks = false
    private var isObservingWindowDragSession = false
    private var didMoveDuringWindowDragSession = false
    // Minimal test hook so unit tests can deterministically model immediate window drag.
    var performDragHandlerForTesting: ((NSEvent) -> Void)?
    private let resizeHandleInset: CGFloat = 14
    private let minimumWindowSize = CGSize(width: 220, height: 120)

    init(
        item: PinnedTextItem,
        dependencies: PinnedTextActionDependencies
    ) {
        self.item = item
        self.dependencies = dependencies

        super.init(
            contentRect: item.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configure()
    }

    convenience init(item: PinnedTextItem) {
        self.init(item: item, dependencies: .live)
    }

    override func resignKey() {
        super.resignKey()
        pinnedTextContentView?.clearPreviewZoom()
        pinnedTextContentView?.commitEditingIfNeeded()
    }

    override func scrollWheel(with event: NSEvent) {
        guard let contentView = pinnedTextContentView else {
            super.scrollWheel(with: event)
            return
        }

        if contentView.isEditing {
            super.scrollWheel(with: event)
            return
        }

        let isZeroDeltaPreciseEnd = event.hasPreciseScrollingDeltas
            && abs(event.scrollingDeltaY) < 0.001
            && abs(event.scrollingDeltaX) < 0.001
        let isNonPreciseExplicitEnd = !event.hasPreciseScrollingDeltas
            && (event.phase == .ended || event.phase == .cancelled)

        if contentView.gestureZoom != nil && (isZeroDeltaPreciseEnd || isNonPreciseExplicitEnd) {
            commitPreviewZoomIfNeeded()
            return
        }

        let isVerticalDominant = abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX)
        let wantsScrollOverride = event.modifierFlags.contains(.shift)

        guard isVerticalDominant else {
            handleHorizontalScroll(event)
            return
        }

        guard isHovered else {
            contentView.forwardVerticalScroll(event)
            return
        }

        if contentView.isFocusedBrowsing || wantsScrollOverride {
            contentView.forwardVerticalScroll(event)
            return
        }

        updatePreviewZoom(deltaY: event.scrollingDeltaY)

        if !event.hasPreciseScrollingDeltas {
            schedulePreviewZoomCommit()
        }
    }

    func updatePinnedState() {
        if item.isPinned {
            collectionBehavior = []
        } else {
            collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        }
        updateGlow()
    }

    func updateLockState() {
        pinnedTextContentView?.refreshToolbarState()
    }

    func refreshToolbarState() {
        pinnedTextContentView?.refreshToolbarState()
    }

    func updateGlow() {
        pinnedTextContentView?.updateGlow(
            isHovered: isHovered,
            isMarked: item.isMarked,
            isPinned: item.isPinned
        )
    }

    func resizeToPreferredContent(animated: Bool) {
        guard let contentView = pinnedTextContentView else { return }

        let size = contentView.preferredWindowSize()
        let currentFrame = frame
        let currentCenter = CGPoint(x: currentFrame.midX, y: currentFrame.midY)
        let nextFrame = CGRect(
            x: currentCenter.x - size.width / 2,
            y: currentCenter.y - size.height / 2,
            width: size.width,
            height: size.height
        )

        guard abs(currentFrame.width - nextFrame.width) > 0.5 || abs(currentFrame.height - nextFrame.height) > 0.5 else {
            return
        }

        suppressManagedFrameCallbacks = true
        setFrame(nextFrame, display: true, animate: animated)
        suppressManagedFrameCallbacks = false
        onFrameChanged?(nextFrame)
    }

    func windowDidMove(_ notification: Notification) {
        if isObservingWindowDragSession {
            didMoveDuringWindowDragSession = true
        }
        guard !suppressManagedFrameCallbacks else { return }
        onFrameChanged?(frame)
    }

    func windowDidResize(_ notification: Notification) {
        guard !suppressManagedFrameCallbacks else { return }
        onFrameChanged?(frame)
    }

    private func configure() {
        identifier = NSUserInterfaceItemIdentifier(UITestIdentifiers.Window.pinnedText)
        setAccessibilityIdentifier(UITestIdentifiers.Window.pinnedText)
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        animationBehavior = .utilityWindow
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        delegate = self

        updatePinnedState()
        alphaValue = item.opacity

        let contentView = PinnedTextContentView(item: item, dependencies: dependencies)
        contentView.identifier = NSUserInterfaceItemIdentifier(UITestIdentifiers.Element.pinnedTextContent)
        contentView.setAccessibilityIdentifier(UITestIdentifiers.Element.pinnedTextContent)
        contentView.autoresizingMask = [.width, .height]
        self.contentView = contentView
        self.pinnedTextContentView = contentView
        updateGlow()
    }

    func beginContentInteraction(with event: NSEvent) -> Bool {
        guard !item.isLocked, activeResizeRegion == .none else {
            return false
        }

        let region = resizeRegion(at: event.locationInWindow)
        guard region.isResizable else { return false }

        activeResizeRegion = region
        dragStartScreenPoint = NSEvent.mouseLocation
        dragStartFrame = frame
        NSCursor.closedHand.set()
        return true
    }

    func continueContentInteraction(with event: NSEvent) -> Bool {
        guard activeResizeRegion.isResizable else { return false }

        let currentPoint = NSEvent.mouseLocation
        let deltaX = currentPoint.x - dragStartScreenPoint.x
        let deltaY = currentPoint.y - dragStartScreenPoint.y

        var nextFrame = dragStartFrame

        switch activeResizeRegion {
        case .left:
            nextFrame.origin.x += deltaX
            nextFrame.size.width -= deltaX
        case .right:
            nextFrame.size.width += deltaX
        case .top:
            nextFrame.size.height += deltaY
        case .bottom:
            nextFrame.origin.y += deltaY
            nextFrame.size.height -= deltaY
        case .topLeft:
            nextFrame.origin.x += deltaX
            nextFrame.size.width -= deltaX
            nextFrame.size.height += deltaY
        case .topRight:
            nextFrame.size.width += deltaX
            nextFrame.size.height += deltaY
        case .bottomLeft:
            nextFrame.origin.x += deltaX
            nextFrame.size.width -= deltaX
            nextFrame.origin.y += deltaY
            nextFrame.size.height -= deltaY
        case .bottomRight:
            nextFrame.size.width += deltaX
            nextFrame.origin.y += deltaY
            nextFrame.size.height -= deltaY
        case .none:
            return false
        }

        nextFrame = clampedResizeFrame(nextFrame, from: dragStartFrame, region: activeResizeRegion)
        suppressManagedFrameCallbacks = true
        setFrame(nextFrame, display: true)
        suppressManagedFrameCallbacks = false
        item.frame = nextFrame
        onFrameChanged?(nextFrame)
        NSCursor.closedHand.set()
        return true
    }

    func endContentInteraction(with event: NSEvent) -> Bool {
        guard activeResizeRegion.isResizable else { return false }
        activeResizeRegion = .none
        applyHoverCursor(at: event.locationInWindow)
        dependencies.saveWindowState()
        return true
    }

    func performWindowDrag(with event: NSEvent) -> Bool {
        isObservingWindowDragSession = true
        didMoveDuringWindowDragSession = false

        if let performDragHandlerForTesting {
            performDragHandlerForTesting(event)
            didMoveDuringWindowDragSession = true
            isObservingWindowDragSession = false
            return true
        }

        performDrag(with: event)
        let didMove = didMoveDuringWindowDragSession
        isObservingWindowDragSession = false
        return didMove
    }

    func handleHoverChanged(_ hovered: Bool, locationInWindow: CGPoint?) {
        isHovered = hovered
        updateGlow()

        if hovered, let locationInWindow {
            applyHoverCursor(at: locationInWindow)
        } else {
            NSCursor.arrow.set()
        }
    }

    func handleHoverMovement(locationInWindow: CGPoint) {
        guard pinnedTextContentView?.isEditing != true else { return }
        applyHoverCursor(at: locationInWindow)
    }

    private func handleHorizontalScroll(_ event: NSEvent) {
        guard event.hasPreciseScrollingDeltas else {
            super.scrollWheel(with: event)
            return
        }

        let deltaX = event.scrollingDeltaX
        guard abs(deltaX) > 1 else { return }
        handleOpacityChange(delta: deltaX, sensitivity: 0.003)
    }

    private func handleOpacityChange(delta: CGFloat, sensitivity: CGFloat) {
        let opacityDelta = delta * sensitivity
        let newOpacity = max(0.3, min(1.0, item.opacity + opacityDelta))

        guard abs(item.opacity - newOpacity) > 0.001 else { return }
        item.opacity = newOpacity
        alphaValue = newOpacity
        dependencies.saveWindowState()
    }

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
    }

    private func updatePreviewZoom(deltaY: CGFloat) {
        guard let contentView = pinnedTextContentView, deltaY != 0 else { return }

        let baseZoom = contentView.gestureZoom ?? item.zoomLevel
        let step: Double = deltaY > 0 ? 0.05 : -0.05
        let nextZoom = PinnedTextMarkdownRenderer.clampedZoom(baseZoom + step)

        guard abs(nextZoom - baseZoom) > 0.0001 else { return }

        contentView.beginOrUpdatePreviewZoom(nextZoom)
    }

    private func schedulePreviewZoomCommit() {
        pinnedTextContentView?.schedulePendingPreviewZoomCommit(after: 0.12) { [weak self] in
            self?.commitPreviewZoomIfNeeded()
        }
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
    }

    func resizeRegion(at locationInWindow: CGPoint) -> ResizeRegion {
        guard let contentView = pinnedTextContentView else { return .none }
        let cardFrame = contentView.interactiveCardFrame()
        let interactiveBounds = cardFrame.insetBy(dx: -resizeHandleInset, dy: -resizeHandleInset)
        guard interactiveBounds.contains(locationInWindow) else { return .none }

        let nearLeft = abs(locationInWindow.x - cardFrame.minX) <= resizeHandleInset
        let nearRight = abs(locationInWindow.x - cardFrame.maxX) <= resizeHandleInset
        let nearBottom = abs(locationInWindow.y - cardFrame.minY) <= resizeHandleInset
        let nearTop = abs(locationInWindow.y - cardFrame.maxY) <= resizeHandleInset

        if nearLeft && nearTop { return .topLeft }
        if nearRight && nearTop { return .topRight }
        if nearLeft && nearBottom { return .bottomLeft }
        if nearRight && nearBottom { return .bottomRight }
        if nearLeft { return .left }
        if nearRight { return .right }
        if nearTop { return .top }
        if nearBottom { return .bottom }
        return .none
    }

    private func clampedResizeFrame(
        _ proposedFrame: CGRect,
        from originalFrame: CGRect,
        region: ResizeRegion
    ) -> CGRect {
        var frame = proposedFrame

        if frame.width < minimumWindowSize.width {
            let delta = minimumWindowSize.width - frame.width
            frame.size.width = minimumWindowSize.width
            if region == .left || region == .topLeft || region == .bottomLeft {
                frame.origin.x -= delta
            }
        }

        if frame.height < minimumWindowSize.height {
            let delta = minimumWindowSize.height - frame.height
            frame.size.height = minimumWindowSize.height
            if region == .bottom || region == .bottomLeft || region == .bottomRight {
                frame.origin.y -= delta
            }
        }

        return frame
    }

    private func applyHoverCursor(at locationInWindow: CGPoint) {
        guard !item.isLocked else {
            NSCursor.arrow.set()
            return
        }
        let region = resizeRegion(at: locationInWindow)
        resolvedCursor(for: region).set()
    }

    func resolvedCursor(for region: ResizeRegion) -> NSCursor {
        switch region {
        case .left, .right, .top, .bottom, .topLeft, .bottomRight, .topRight, .bottomLeft:
            return .openHand
        case .none:
            return .arrow
        }
    }
}

// MARK: - Testing Hooks

extension PinnedTextWindow {
    var activeResizeRegionForTesting: ResizeRegion {
        activeResizeRegion
    }

    func beginPreviewZoomForTesting(deltaY: CGFloat) {
        updatePreviewZoom(deltaY: deltaY)
    }
}
