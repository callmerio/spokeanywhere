import AppKit

@MainActor
struct PinnedTextActionDependencies {
    let togglePin: (PinnedTextItem) -> Void
    let toggleLock: (PinnedTextItem) -> Void
    let toggleMark: (PinnedTextItem) -> Void
    let updateWindowCollectionBehavior: (UUID) -> Void
    let updateWindowMovable: (UUID) -> Void
    let updateWindowGlow: (UUID) -> Void
    let closeWindow: (PinnedTextItem) -> Void
    let saveWindowState: () -> Void
}

@MainActor
final class PinnedTextContentView: NSView, NSTextViewDelegate {
    private enum LayoutMetrics {
        static let toolbarInset: CGFloat = 6
        static let hoveredToolbarAlpha: CGFloat = 0.88
        static let editingToolbarAlpha: CGFloat = 0.96
    }

    private let item: PinnedTextItem
    private let dependencies: PinnedTextActionDependencies

    private let previewScrollView = PinnedTextPreviewScrollView()
    private let previewTextView = PinnedTextPreviewTextView()
    private let editorScrollView = NSScrollView()
    private let editorTextView = PinnedTextEditorTextView()
    private lazy var actionBar = PinnedTextActionBarView(item: item, dependencies: dependencies)
    private let glowLayer = CAShapeLayer()
    private let cardLayer = CAShapeLayer()


    private var trackingArea: NSTrackingArea?
    private var lastHoverScreenLocation: CGPoint?
    private var isHovered = false {
        didSet { updateToolbarVisibility() }
    }
    private(set) var isFocusedBrowsing = false
    private(set) var gestureZoom: Double?
    private var pendingZoomCommitTimer: Timer?
    private var forwardedVerticalScrollCount = 0
    private(set) var isEditing = false {
        didSet { updateEditingVisibility() }
    }
    private var editingSnapshot = ""

    init(
        item: PinnedTextItem,
        dependencies: PinnedTextActionDependencies
    ) {
        self.item = item
        self.dependencies = dependencies
        super.init(frame: .zero)

        setupView()
        refreshFromItem()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .group }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )

        if let trackingArea {
            addTrackingArea(trackingArea)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateLastHoverScreenLocation(from: event)
        (window as? PinnedTextWindow)?.handleHoverChanged(true, locationInWindow: event.locationInWindow)
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        exitFocusedBrowsing()
        if shouldCancelPreviewOnMouseExit(event) {
            cancelActivePreviewIfNeeded()
        }
        (window as? PinnedTextWindow)?.handleHoverChanged(false, locationInWindow: nil)
        lastHoverScreenLocation = nil
    }

    override func mouseMoved(with event: NSEvent) {
        updateLastHoverScreenLocation(from: event)
        (window as? PinnedTextWindow)?.handleHoverMovement(locationInWindow: event.locationInWindow)
    }

    override func mouseDown(with event: NSEvent) {
        guard !isEditing else {
            super.mouseDown(with: event)
            return
        }

        guard let pinnedWindow = window as? PinnedTextWindow else {
            return
        }

        if pinnedWindow.beginContentInteraction(with: event) {
            cancelActivePreviewIfNeeded()
            return
        }

        let isInsideCard = interactiveCardFrame().contains(event.locationInWindow)
        guard isInsideCard else {
            return
        }

        if event.clickCount >= 2 {
            beginEditing()
            return
        }

        guard !item.isLocked else {
            enterFocusedBrowsing()
            return
        }

        let didDrag = pinnedWindow.performWindowDrag(with: event)

        if didDrag {
            exitFocusedBrowsing()
        } else {
            enterFocusedBrowsing()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if (window as? PinnedTextWindow)?.continueContentInteraction(with: event) == true {
            return
        }
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if (window as? PinnedTextWindow)?.endContentInteraction(with: event) == true {
            return
        }
        super.mouseUp(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        return makeContextMenu()
    }

    override func layout() {
        super.layout()

        let cardFrame = interactiveCardFrame()
        let insets = PinnedTextMarkdownRenderer.contentInsets
        let contentFrame = CGRect(
            x: cardFrame.minX + insets.left,
            y: cardFrame.minY + insets.bottom,
            width: cardFrame.width - insets.left - insets.right,
            height: cardFrame.height - insets.top - insets.bottom
        )

        previewScrollView.frame = contentFrame
        editorScrollView.frame = contentFrame

        let toolbarSize = actionBar.intrinsicContentSize
        actionBar.frame = CGRect(
            x: cardFrame.maxX - toolbarSize.width - LayoutMetrics.toolbarInset,
            y: cardFrame.maxY - toolbarSize.height - LayoutMetrics.toolbarInset,
            width: toolbarSize.width,
            height: toolbarSize.height
        )
        updateChromePaths()
    }

    func preferredWindowSize() -> CGSize {
        PinnedTextMarkdownRenderer.preferredWindowSize(text: item.text, zoomLevel: item.zoomLevel)
    }

    func refreshFromItem(resizeWindow: Bool = false) {
        refreshPreviewContent()
        configureEditorAppearance()
        actionBar.refreshButtons()
        updatePreviewZoomVisuals()

        if resizeWindow {
            (window as? PinnedTextWindow)?.resizeToPreferredContent(animated: false)
        }
    }

    func beginEditing() {
        guard !isEditing else { return }
        cancelActivePreviewIfNeeded()
        editingSnapshot = item.text
        isEditing = true
        editorTextView.string = item.text
        configureEditorAppearance()

        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeFirstResponder(self.editorTextView)
            self.editorTextView.inputContext?.activate()
        }
    }

    func commitEditingIfNeeded() {
        guard isEditing else { return }

        let updatedText = PinnedTextMarkdownRenderer.normalize(editorTextView.string)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !updatedText.isEmpty {
            item.text = updatedText
        }

        isEditing = false
        refreshFromItem()
        dependencies.saveWindowState()
    }

    func cancelEditing() {
        guard isEditing else { return }
        editorTextView.string = editingSnapshot
        isEditing = false
        refreshFromItem()
    }

    func enterFocusedBrowsing() {
        guard !isEditing else { return }
        cancelActivePreviewIfNeeded()
        isFocusedBrowsing = true
    }

    func exitFocusedBrowsing() {
        guard !isEditing else { return }
        isFocusedBrowsing = false
    }

    func refreshToolbarState() {
        actionBar.refreshButtons()
    }

    var activeEditorTextView: NSTextView? {
        isEditing ? editorTextView : nil
    }

    func interactiveCardFrame() -> CGRect {
        bounds.insetBy(
            dx: PinnedTextMarkdownRenderer.windowGlowPadding,
            dy: PinnedTextMarkdownRenderer.windowGlowPadding
        )
    }

    func contextMenuItemTitles() -> [String] {
        makeContextMenu().items
            .filter { !$0.isSeparatorItem }
            .map(\.title)
    }

    @objc private func performCopyText() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
    }

    @objc private func performCopyImage() {
        guard let image = renderedCardImage() else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    @objc private func performPinAction() {
        dependencies.togglePin(item)
        dependencies.updateWindowCollectionBehavior(item.id)
        refreshToolbarState()
    }

    @objc private func performLockAction() {
        dependencies.toggleLock(item)
        dependencies.updateWindowMovable(item.id)
        refreshToolbarState()
    }

    @objc private func performMarkAction() {
        dependencies.toggleMark(item)
        dependencies.updateWindowGlow(item.id)
        refreshToolbarState()
    }

    @objc private func performCloseAction() {
        dependencies.closeWindow(item)
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = DesignTokens.Colors.NS.clear.cgColor
        layer?.masksToBounds = false

        setupGlowLayer()
        setupCardLayer()
        previewScrollView.borderType = .noBorder
        previewScrollView.drawsBackground = false
        previewScrollView.wantsLayer = true
        previewScrollView.hasVerticalScroller = false
        previewScrollView.hasHorizontalScroller = false
        previewScrollView.autohidesScrollers = true
        previewScrollView.scrollerStyle = .overlay
        previewScrollView.verticalScrollElasticity = .allowed
        previewScrollView.scrollerKnobStyle = .light

        previewTextView.drawsBackground = false
        previewTextView.isEditable = false
        previewTextView.isSelectable = false
        previewTextView.isRichText = true
        previewTextView.isVerticallyResizable = true
        previewTextView.isHorizontallyResizable = false
        previewTextView.textContainer?.lineFragmentPadding = 0
        previewTextView.textContainer?.widthTracksTextView = true
        previewTextView.textContainerInset = .zero

        previewScrollView.documentView = previewTextView
        addSubview(previewScrollView)

        editorScrollView.borderType = .noBorder
        editorScrollView.drawsBackground = false
        editorScrollView.hasVerticalScroller = false
        editorScrollView.hasHorizontalScroller = false
        editorScrollView.autohidesScrollers = true
        editorScrollView.scrollerStyle = .overlay
        editorScrollView.verticalScrollElasticity = .allowed
        editorScrollView.scrollerKnobStyle = .light

        editorTextView.delegate = self
        editorTextView.drawsBackground = false
        editorTextView.isRichText = false
        editorTextView.allowsUndo = true
        editorTextView.isVerticallyResizable = true
        editorTextView.isHorizontallyResizable = false
        editorTextView.textContainer?.lineFragmentPadding = 0
        editorTextView.textContainer?.widthTracksTextView = true
        editorTextView.textContainerInset = .zero
        editorTextView.contextMenuProvider = { [weak self] in
            self?.makeContextMenu()
        }
        editorTextView.onCommit = { [weak self] in
            self?.commitEditingIfNeeded()
        }
        editorTextView.onCancel = { [weak self] in
            self?.cancelEditing()
        }

        editorScrollView.documentView = editorTextView
        editorScrollView.isHidden = true
        addSubview(editorScrollView)

        actionBar.alphaValue = 0
        actionBar.isHidden = true
        addSubview(actionBar)

        updateEditingVisibility()
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()

        let copyImageItem = NSMenuItem(title: "Copy Image (C)", action: #selector(performCopyImage), keyEquivalent: "c")
        copyImageItem.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
        copyImageItem.target = self
        menu.addItem(copyImageItem)

        let copyTextItem = NSMenuItem(title: "Copy Text (T)", action: #selector(performCopyText), keyEquivalent: "t")
        copyTextItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        copyTextItem.target = self
        menu.addItem(copyTextItem)

        menu.addItem(.separator())

        let pinItem = NSMenuItem(
            title: item.isPinned ? "Unpin (P)" : "Pin to Space (P)",
            action: #selector(performPinAction),
            keyEquivalent: "p"
        )
        pinItem.image = NSImage(systemSymbolName: item.isPinned ? "pin.slash" : "pin", accessibilityDescription: nil)
        pinItem.target = self
        menu.addItem(pinItem)

        let lockItem = NSMenuItem(
            title: item.isLocked ? "Unlock (L)" : "Lock (L)",
            action: #selector(performLockAction),
            keyEquivalent: "l"
        )
        lockItem.image = NSImage(systemSymbolName: item.isLocked ? "lock.open" : "lock", accessibilityDescription: nil)
        lockItem.target = self
        menu.addItem(lockItem)

        menu.addItem(.separator())

        let markItem = NSMenuItem(
            title: item.isMarked ? "Unmark (M)" : "Mark (M)",
            action: #selector(performMarkAction),
            keyEquivalent: "m"
        )
        markItem.image = NSImage(systemSymbolName: item.isMarked ? "bookmark.slash" : "bookmark", accessibilityDescription: nil)
        markItem.target = self
        menu.addItem(markItem)

        menu.addItem(.separator())

        let closeItem = NSMenuItem(title: "Close (Q)", action: #selector(performCloseAction), keyEquivalent: "q")
        closeItem.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: nil)
        closeItem.target = self
        menu.addItem(closeItem)

        return menu
    }

    private func renderedCardImage() -> NSImage? {
        layoutSubtreeIfNeeded()
        let cardFrame = interactiveCardFrame()
        guard cardFrame.width > 0, cardFrame.height > 0 else { return nil }
        guard let bitmap = bitmapImageRepForCachingDisplay(in: cardFrame) else { return nil }

        cacheDisplay(in: cardFrame, to: bitmap)
        let image = NSImage(size: cardFrame.size)
        image.addRepresentation(bitmap)
        return image
    }

    private func setupGlowLayer() {
        glowLayer.fillColor = DesignTokens.Colors.NS.clear.cgColor
        glowLayer.strokeColor = nil
        glowLayer.lineWidth = 0
        glowLayer.zPosition = -2
        layer?.addSublayer(glowLayer)
    }

    private func setupCardLayer() {
        let shadow = DesignTokens.Shadow.PinnedText.card
        cardLayer.fillColor = DesignTokens.Colors.NS.pinnedTextBackground.cgColor
        cardLayer.strokeColor = DesignTokens.Colors.NS.pinnedTextForeground.withAlphaComponent(0.16).cgColor
        cardLayer.lineWidth = DesignTokens.BorderWidth.none
        cardLayer.shadowColor = shadow.color.cgColor
        cardLayer.shadowOpacity = shadow.opacity
        cardLayer.shadowRadius = shadow.radius
        cardLayer.shadowOffset = shadow.offset
        cardLayer.zPosition = -1
        layer?.addSublayer(cardLayer)
    }

    private func updateChromePaths() {
        let cardFrame = interactiveCardFrame()
        let cardPath = NSBezierPath(
            roundedRect: cardFrame,
            xRadius: DesignTokens.CornerRadius.xl,
            yRadius: DesignTokens.CornerRadius.xl
        ).cgPath

        cardLayer.frame = bounds
        cardLayer.path = cardPath
        cardLayer.shadowPath = cardPath

        glowLayer.frame = bounds
        let glowRect = cardFrame.insetBy(dx: -1, dy: -1)
        let path = NSBezierPath(
            roundedRect: glowRect,
            xRadius: DesignTokens.CornerRadius.xl,
            yRadius: DesignTokens.CornerRadius.xl
        ).cgPath
        glowLayer.path = path
        glowLayer.shadowPath = path
    }

    func updateGlow(isHovered: Bool, isMarked: Bool, isPinned: Bool) {
        updateChromePaths()

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))

        let style = Self.glowStyle(isHovered: isHovered, isMarked: isMarked, isPinned: isPinned)

        if isMarked {
            applyGlow(
                strokeColor: DesignTokens.Colors.NS.glowMarkStroke,
                shadowColor: DesignTokens.Colors.NS.glowMarkShadow,
                style: style
            )
        } else if isHovered {
            applyGlow(
                strokeColor: DesignTokens.Colors.NS.glowHoverStroke,
                shadowColor: DesignTokens.Colors.NS.glowHoverShadow,
                style: style
            )
        } else if isPinned {
            applyGlow(
                strokeColor: DesignTokens.Colors.NS.glowIdle.withAlphaComponent(0.5),
                shadowColor: DesignTokens.Colors.NS.glowIdle,
                style: style
            )
        } else {
            clearGlow()
        }

        CATransaction.commit()
    }

    private func applyGlow(
        strokeColor: NSColor,
        shadowColor: NSColor,
        style: DesignTokens.Glow.Style?
    ) {
        let style = style ?? DesignTokens.Glow.PinnedText.idle
        glowLayer.fillColor = DesignTokens.Colors.NS.clear.withAlphaComponent(style.fillOpacity).cgColor
        glowLayer.strokeColor = strokeColor.cgColor
        glowLayer.lineWidth = style.lineWidth
        glowLayer.shadowColor = shadowColor.cgColor
        glowLayer.shadowRadius = style.shadowRadius
        glowLayer.shadowOffset = .zero
        glowLayer.shadowOpacity = style.shadowOpacity
    }

    private func clearGlow() {
        glowLayer.fillColor = DesignTokens.Colors.NS.clear.cgColor
        glowLayer.strokeColor = nil
        glowLayer.lineWidth = 0
        glowLayer.shadowColor = nil
        glowLayer.shadowOpacity = 0
    }

    static func glowStyle(isHovered: Bool, isMarked: Bool, isPinned: Bool) -> DesignTokens.Glow.Style? {
        if isMarked {
            return DesignTokens.Glow.PinnedText.mark
        }

        if isHovered {
            return DesignTokens.Glow.PinnedText.hover
        }

        if isPinned {
            return DesignTokens.Glow.PinnedText.idle
        }

        return nil
    }

    private func configurePreviewAppearance(zoomLevel: Double) {
        previewTextView.font = PinnedTextMarkdownRenderer.bodyFont(for: zoomLevel)
        previewTextView.textColor = DesignTokens.Colors.NS.pinnedTextForeground
    }

    private func configureEditorAppearance() {
        let font = PinnedTextMarkdownRenderer.editorFont(for: item.zoomLevel)
        let paragraphStyle = PinnedTextMarkdownRenderer.editorParagraphStyle()
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: DesignTokens.Colors.NS.pinnedTextForeground,
            .paragraphStyle: paragraphStyle
        ]

        editorTextView.font = font
        editorTextView.textColor = DesignTokens.Colors.NS.pinnedTextForeground
        editorTextView.insertionPointColor = DesignTokens.Colors.NS.pinnedTextForeground
        editorTextView.defaultParagraphStyle = paragraphStyle
        editorTextView.typingAttributes = textAttributes

        let fullRange = NSRange(location: 0, length: editorTextView.string.utf16.count)
        if fullRange.length > 0 {
            editorTextView.textStorage?.addAttributes(textAttributes, range: fullRange)
        }
    }

    private func updateEditingVisibility() {
        previewScrollView.isHidden = isEditing
        editorScrollView.isHidden = !isEditing
        updateToolbarVisibility()
    }

    private func updateToolbarVisibility() {
        let shouldShow = isHovered || isEditing
        let targetAlpha: CGFloat
        if isEditing {
            targetAlpha = LayoutMetrics.editingToolbarAlpha
        } else if isHovered {
            targetAlpha = LayoutMetrics.hoveredToolbarAlpha
        } else {
            targetAlpha = 0
        }

        if abs(actionBar.alphaValue - targetAlpha) < 0.001 {
            actionBar.isHidden = !shouldShow
            return
        }

        if shouldShow {
            actionBar.isHidden = false
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = DesignTokens.Animation.durationFast
            actionBar.animator().alphaValue = targetAlpha
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.actionBar.isHidden = !shouldShow
            }
        }
    }

    func forwardVerticalScroll(_ event: NSEvent) {
        forwardedVerticalScrollCount += 1
        let targetScrollView = isEditing ? editorScrollView : previewScrollView
        targetScrollView.scrollWheel(with: event)
    }

    func beginOrUpdatePreviewZoom(_ zoom: Double) {
        gestureZoom = zoom
        refreshPreviewContent()
        updatePreviewZoomVisuals()
    }

    func clearPreviewZoom(resetPreviewContent: Bool = true) {
        pendingZoomCommitTimer?.invalidate()
        pendingZoomCommitTimer = nil
        gestureZoom = nil
        if resetPreviewContent {
            refreshPreviewContent()
        }
        updatePreviewZoomVisuals()
    }

    func cancelActivePreviewIfNeeded() {
        guard gestureZoom != nil || pendingZoomCommitTimer != nil else { return }
        if let pinnedWindow = window as? PinnedTextWindow {
            pinnedWindow.cancelPreviewZoomIfNeeded()
        } else {
            clearPreviewZoom()
        }
    }

    func schedulePendingPreviewZoomCommit(
        after delay: TimeInterval,
        _ action: @escaping @MainActor () -> Void
    ) {
        pendingZoomCommitTimer?.invalidate()
        pendingZoomCommitTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            MainActor.assumeIsolated {
                action()
            }
        }
    }

    func currentPreviewOrCommittedZoom() -> Double {
        gestureZoom ?? item.zoomLevel
    }

    private func refreshPreviewContent() {
        let previewZoom = currentPreviewOrCommittedZoom()
        let attributed = PinnedTextMarkdownRenderer.makePreviewAttributedString(item.text, zoomLevel: previewZoom)
        previewTextView.textStorage?.setAttributedString(attributed)
        configurePreviewAppearance(zoomLevel: previewZoom)
    }

    private func updateLastHoverScreenLocation(from event: NSEvent) {
        guard let window else { return }
        lastHoverScreenLocation = window.convertPoint(toScreen: event.locationInWindow)
    }

    private func shouldCancelPreviewOnMouseExit(_ event: NSEvent) -> Bool {
        guard gestureZoom != nil else { return true }
        guard let window,
              let lastHoverScreenLocation else { return true }

        let exitScreenLocation = window.convertPoint(toScreen: event.locationInWindow)
        let deltaX = exitScreenLocation.x - lastHoverScreenLocation.x
        let deltaY = exitScreenLocation.y - lastHoverScreenLocation.y
        let distance = hypot(deltaX, deltaY)
        return distance > 1.0
    }

    private func updatePreviewZoomVisuals() {
        previewScrollView.layer?.setAffineTransform(.identity)
    }
}

// MARK: - Testing Hooks

extension PinnedTextContentView {
    var isFocusedBrowsingForTesting: Bool {
        isFocusedBrowsing
    }

    var forwardedVerticalScrollCountForTesting: Int {
        forwardedVerticalScrollCount
    }

    var previewScrollOriginYForTesting: CGFloat {
        previewScrollView.contentView.bounds.origin.y
    }

    var previewZoomForTesting: Double {
        currentPreviewOrCommittedZoom()
    }

    var previewScaleForTesting: CGFloat {
        CGFloat(currentPreviewOrCommittedZoom() / item.zoomLevel)
    }

    var previewBodyFontPointSizeForTesting: CGFloat {
        guard let textStorage = previewTextView.textStorage, textStorage.length > 0 else { return 0 }

        var minimumPointSize = CGFloat.greatestFiniteMagnitude
        textStorage.enumerateAttribute(.font, in: NSRange(location: 0, length: textStorage.length)) { value, _, _ in
            guard let font = value as? NSFont else { return }
            minimumPointSize = min(minimumPointSize, font.pointSize)
        }

        return minimumPointSize == .greatestFiniteMagnitude ? 0 : minimumPointSize
    }
}

private final class PinnedTextEditorTextView: NSTextView {
    var contextMenuProvider: (() -> NSMenu?)?
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    override func menu(for event: NSEvent) -> NSMenu? {
        contextMenuProvider?() ?? super.menu(for: event)
    }

    override func doCommand(by selector: Selector) {
        if selector == #selector(insertNewline(_:)) {
            if NSApp.currentEvent?.modifierFlags.contains(.command) == true {
                onCommit?()
            } else {
                insertNewlineIgnoringFieldEditor(nil)
            }
            return
        }

        if selector == #selector(cancelOperation(_:)) {
            onCancel?()
            return
        }

        super.doCommand(by: selector)
    }
}

private final class PinnedTextPreviewTextView: NSTextView {
    override var acceptsFirstResponder: Bool { false }
    override var canBecomeKeyView: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

private final class PinnedTextPreviewScrollView: NSScrollView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
