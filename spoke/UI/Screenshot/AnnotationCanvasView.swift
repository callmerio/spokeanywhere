import AppKit

// MARK: - Annotation Canvas Protocol

@MainActor
protocol AnnotationCanvas: AnyObject {
    func addAnnotation(_ annotation: Annotation, recordCommand: Bool)
    func removeAnnotation(_ annotation: Annotation, recordCommand: Bool)
}

// MARK: - Annotation Canvas View

/// 标注画布视图
final class AnnotationCanvasView: NSView, AnnotationCanvas {
    
    // MARK: - Types
    
    enum Tool {
        case none
        case arrow
        case pen
        case marker
        case text
        case eraser
    }

    enum CursorStyle: Equatable {
        case arrow
        case crosshair
        case iBeam
        case brush
        case openHand
        case eraser
    }
    
    // MARK: - Properties
    
    private(set) var annotations: [Annotation] = []
    private let historyManager = AnnotationHistoryManager()
    private var defaultTextStyle = TextAnnotationStyle.default
    private var selectedTextAnnotationID: UUID?
    
    var onTextStyleChanged: ((TextAnnotationStyle, Bool) -> Void)?
    var currentTextStyle: TextAnnotationStyle {
        editingTextAnnotation?.style ?? selectedTextAnnotation?.style ?? defaultTextStyle
    }
    
    var activeEditingTextAnnotation: TextAnnotation? { editingTextAnnotation }
    var selectedTextAnnotation: TextAnnotation? {
        guard let selectedTextAnnotationID else { return nil }
        return annotations.first { $0.id == selectedTextAnnotationID } as? TextAnnotation
    }
    
    var currentTool: Tool = .none {
        didSet {
            // 切换工具时重置笔刷大小（如果需要）
            // 这里我们保留笔刷大小，或者为不同工具设置默认值
            switch currentTool {
            case .pen: currentBrushSize = 3
            case .marker: currentBrushSize = 20
            default: break
            }
            
            if currentTool != .text {
                commitActiveTextIfNeeded(selectCommittedText: false)
                clearTextSelection()
            } else {
                publishTextStyleState()
            }
            
            updateCursor()
            hoveredAnnotation = nil
            window?.invalidateCursorRects(for: self)
        }
    }
    
    var currentColor: NSColor = DesignTokens.Colors.NS.annotationPrimary
    var currentLineWidth: CGFloat = 3 // For arrow
    var currentBrushSize: CGFloat = 3 // For pen/marker
    
    private var currentAnnotation: Annotation?
    private var dragStartPoint: CGPoint = .zero
    
    /// 正在编辑的文字
    private var editingTextView: NSTextView?
    private var editingTextAnnotation: TextAnnotation?
    private var editingOriginalTextSnapshot: TextAnnotationSnapshot?
    
    /// 正在拖动的标注
    private var draggingAnnotation: Annotation?
    private var draggingStartPosition: CGPoint = .zero
    
    /// Hover 的标注（橡皮擦模式）
    private var hoveredAnnotation: Annotation? {
        didSet {
            if oldValue?.id != hoveredAnnotation?.id {
                needsDisplay = true
            }
        }
    }
    
    /// 自定义橡皮擦光标
    private lazy var eraserCursor: NSCursor = createEraserCursor()
    
    var onAnnotationsChanged: (() -> Void)?
    var onHistoryChanged: ((Bool, Bool) -> Void)?
    
    // MARK: - Init
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = DesignTokens.Colors.NS.clear.cgColor
        
        historyManager.onHistoryChanged = { [weak self] in
            guard let self = self else { return }
            self.onHistoryChanged?(self.historyManager.canUndo, self.historyManager.canRedo)
        }
    }
}

extension AnnotationCanvasView {
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        for annotation in annotations {
            let isHovered = currentTool == .eraser && annotation.id == hoveredAnnotation?.id
            
            if isHovered {
                context.saveGState()
                context.setAlpha(0.5)
            }

            if let decorationRect = selectedTextDecorationRect(for: annotation) {
                drawSelectedTextDecoration(in: decorationRect, context: context)
            }
            
            annotation.draw(in: context)
            
            if isHovered {
                context.restoreGState()
            }
        }
        
        currentAnnotation?.draw(in: context)
    }
    
    // MARK: - AnnotationCanvas Protocol
    
    func addAnnotation(_ annotation: Annotation, recordCommand: Bool = true) {
        annotations.append(annotation)
        
        if recordCommand {
            let command = AddAnnotationCommand(annotation: annotation, canvas: self)
            historyManager.record(command)
        }
        
        needsDisplay = true
        onAnnotationsChanged?()
    }
    
    func removeAnnotation(_ annotation: Annotation, recordCommand: Bool = true) {
        annotations.removeAll { $0.id == annotation.id }
        if selectedTextAnnotationID == annotation.id {
            selectedTextAnnotationID = nil
        }
        
        if recordCommand {
            let command = RemoveAnnotationCommand(annotation: annotation, canvas: self)
            historyManager.record(command)
        }
        
        hoveredAnnotation = nil
        needsDisplay = true
        onAnnotationsChanged?()
    }
    
    // MARK: - Public API
    
    func undo() {
        historyManager.undo()
        syncTextStyleStateAfterHistoryChange()
        needsDisplay = true
    }
    
    func redo() {
        historyManager.redo()
        syncTextStyleStateAfterHistoryChange()
        needsDisplay = true
    }
    
    var canUndo: Bool { historyManager.canUndo }
    var canRedo: Bool { historyManager.canRedo }
    
    func clear() {
        annotations.removeAll()
        historyManager.clear()
        needsDisplay = true
        onAnnotationsChanged?()
    }

    func applyTextFontSizeStep(_ delta: CGFloat) {
        guard delta != 0 else { return }
        let baseStyle = editingTextAnnotation?.style ?? selectedTextAnnotation?.style ?? defaultTextStyle
        let updatedStyle = TextAnnotationStyle(
            fontSize: min(max(baseStyle.fontSize + delta, 10), 72),
            color: baseStyle.color,
            opacity: baseStyle.opacity
        )
        applyTextStyle(updatedStyle)
    }

    func applyTextColor(_ color: NSColor) {
        let baseStyle = editingTextAnnotation?.style ?? selectedTextAnnotation?.style ?? defaultTextStyle
        let updatedStyle = TextAnnotationStyle(
            fontSize: baseStyle.fontSize,
            color: color,
            opacity: baseStyle.opacity
        )
        applyTextStyle(updatedStyle)
    }

    func adjustSelectedTextOpacity(by delta: CGFloat) {
        guard delta != 0, let selectedTextAnnotation else { return }

        let updatedStyle = TextAnnotationStyle(
            fontSize: selectedTextAnnotation.style.fontSize,
            color: selectedTextAnnotation.style.color,
            opacity: min(max(selectedTextAnnotation.style.opacity + delta, 0.3), 1.0)
        )
        applyTextStyle(updatedStyle)
    }
    
    func renderAnnotations(on image: NSImage) -> NSImage {
        let size = image.size
        let result = NSImage(size: size)
        
        result.lockFocus()
        image.draw(in: CGRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1.0)
        
        if let context = NSGraphicsContext.current?.cgContext {
            for annotation in annotations {
                annotation.draw(in: context)
            }
        }
        
        result.unlockFocus()
        return result
    }
}

extension AnnotationCanvasView {
    
    // MARK: - Mouse Events
    
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        dragStartPoint = location
        
        if event.clickCount == 2 {
            if currentTool == .text, beginEditingTextAnnotation(at: location) {
                return
            }
            if currentTool == .text {
                beginTextDraft(at: location)
                return
            }
        }
        
        if currentTool == .text, selectTextAnnotation(at: location) {
            draggingAnnotation = selectedTextAnnotation
            draggingStartPosition = selectedTextAnnotation?.position ?? .zero
            return
        }
        
        if currentTool == .none {
            if let annotation = findAnnotation(at: location) {
                draggingAnnotation = annotation
                if let textAnn = annotation as? TextAnnotation {
                    draggingStartPosition = textAnn.position
                }
                return
            }
        }
        
        switch currentTool {
        case .none:
            break
            
        case .arrow:
            let arrow = ArrowAnnotation(start: location, end: location, color: currentColor, lineWidth: currentLineWidth)
            currentAnnotation = arrow
            
        case .pen:
            let pen = PenAnnotation(points: [location], color: currentColor, lineWidth: currentBrushSize)
            currentAnnotation = pen
            
        case .marker:
            let marker = MarkerAnnotation(points: [location], color: currentColor, lineWidth: currentBrushSize)
            currentAnnotation = marker
            
        case .text:
            beginTextDraft(at: location)
            
        case .eraser:
            commitActiveTextIfNeeded(selectCommittedText: false)
            clearTextSelection()
            if let annotation = findAnnotation(at: location) {
                removeAnnotation(annotation)
            }
        }
        
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        
        // 拖动标注
        if let annotation = draggingAnnotation {
            let delta = CGPoint(x: location.x - dragStartPoint.x, y: location.y - dragStartPoint.y)
            
            if let textAnn = annotation as? TextAnnotation {
                textAnn.position = CGPoint(x: draggingStartPosition.x + delta.x, y: draggingStartPosition.y + delta.y)
            }
            
            needsDisplay = true
            return
        }
        
        switch currentTool {
        case .none:
            break
            
        case .arrow:
            if let arrow = currentAnnotation as? ArrowAnnotation {
                arrow.endPoint = location
            }
            
        case .pen:
            if let pen = currentAnnotation as? PenAnnotation {
                pen.addPoint(location)
            }
            
        case .marker:
            if let marker = currentAnnotation as? MarkerAnnotation {
                marker.addPoint(location)
            }
            
        case .text, .eraser:
            break
        }
        
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        // 完成标注拖动
        if draggingAnnotation != nil {
            draggingAnnotation = nil
            needsDisplay = true
            return
        }
        
        if let annotation = currentAnnotation {
            var isValid = true
            
            if let arrow = annotation as? ArrowAnnotation {
                let length = hypot(arrow.endPoint.x - arrow.startPoint.x, arrow.endPoint.y - arrow.startPoint.y)
                isValid = length > 10
            } else if let pen = annotation as? PenAnnotation {
                isValid = pen.points.count > 2
            } else if let marker = annotation as? MarkerAnnotation {
                isValid = marker.points.count > 2
            }
            
            if isValid {
                addAnnotation(annotation)
            }
            
            currentAnnotation = nil
        }
        
        needsDisplay = true
    }
    
    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        
        // 橡皮擦模式：hover 变淡
        if currentTool == .eraser {
            hoveredAnnotation = findAnnotation(at: location)
        }
        
        // 检查是否 hover 到标注上（显示移动光标）
        let hoveredInteractiveAnnotation: Annotation?
        switch currentTool {
        case .text:
            hoveredInteractiveAnnotation = findTextAnnotation(at: location)
        default:
            hoveredInteractiveAnnotation = findAnnotation(at: location)
        }

        applyCursorStyle(resolvedCursorStyle(hasInteractiveTarget: hoveredInteractiveAnnotation != nil))
    }
    
    override func mouseExited(with event: NSEvent) {
        hoveredAnnotation = nil
    }
}

extension AnnotationCanvasView {
    
    // MARK: - Tracking Area
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }
    
    override func cursorUpdate(with event: NSEvent) {
        updateCursor()
    }
    
    // MARK: - Hit Testing
    
    private func findAnnotation(at point: CGPoint) -> Annotation? {
        return annotations.last(where: { $0.hitTest(point: point) })
    }
    
    private func findTextAnnotation(at point: CGPoint) -> TextAnnotation? {
        annotations.reversed().first(where: { annotation in
            guard annotation is TextAnnotation else { return false }
            return annotation.hitTest(point: point)
        }) as? TextAnnotation
    }
    
    // MARK: - Text Input
    
    @discardableResult
    func beginTextDraft(at position: CGPoint) -> NSTextView {
        commitActiveTextIfNeeded(selectCommittedText: false)
        
        var draftStyle = defaultTextStyle
        if selectedTextAnnotation == nil {
            draftStyle.color = currentColor
        }
        
        let textAnnotation = TextAnnotation(position: position, text: "")
        textAnnotation.style = draftStyle
        
        clearTextSelection()
        editingTextAnnotation = textAnnotation
        editingOriginalTextSnapshot = nil
        
        let textView = createTextView(at: position, style: draftStyle, existingText: "")
        addSubview(textView)
        editingTextView = textView
        
        publishTextStyleState()
        window?.makeFirstResponder(textView)
        return textView
    }
    
    func selectTextAnnotation(at point: CGPoint) -> Bool {
        commitActiveTextIfNeeded(selectCommittedText: false)
        
        guard let textAnnotation = findTextAnnotation(at: point) else {
            clearTextSelection()
            return false
        }
        
        selectedTextAnnotationID = textAnnotation.id
        defaultTextStyle = textAnnotation.style
        publishTextStyleState()
        needsDisplay = true
        return true
    }
    
    func beginEditingTextAnnotation(at point: CGPoint) -> Bool {
        commitActiveTextIfNeeded(selectCommittedText: false)
        
        guard let textAnnotation = findTextAnnotation(at: point) else {
            clearTextSelection()
            return false
        }
        
        editingOriginalTextSnapshot = TextAnnotationSnapshot(annotation: textAnnotation)
        annotations.removeAll { $0.id == textAnnotation.id }
        clearTextSelection()
        
        editingTextAnnotation = textAnnotation
        defaultTextStyle = textAnnotation.style
        
        let textView = createTextView(
            at: textAnnotation.position,
            style: textAnnotation.style,
            existingText: textAnnotation.text
        )
        addSubview(textView)
        editingTextView = textView
        
        needsDisplay = true
        onAnnotationsChanged?()
        publishTextStyleState()
        window?.makeFirstResponder(textView)
        return true
    }
    
    func clearTextSelection() {
        guard selectedTextAnnotationID != nil else { return }
        selectedTextAnnotationID = nil
        needsDisplay = true
        
        if currentTool == .text, editingTextAnnotation == nil {
            publishTextStyleState()
        }
    }
    
    func commitActiveTextIfNeeded(selectCommittedText: Bool) {
        guard let textView = editingTextView,
              let textAnnotation = editingTextAnnotation else { return }
        
        let text = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalSnapshot = editingOriginalTextSnapshot
        
        if !text.isEmpty {
            textAnnotation.text = text
            if let containerWidth = textView.textContainer?.containerSize.width {
                textAnnotation.maxWidth = containerWidth
            }
            defaultTextStyle = textAnnotation.style
            
            if let originalSnapshot {
                let newSnapshot = TextAnnotationSnapshot(annotation: textAnnotation)
                addAnnotation(textAnnotation, recordCommand: false)
                
                if !textAnnotationMatches(snapshot: originalSnapshot, annotation: textAnnotation) {
                    let command = EditTextAnnotationCommand(
                        annotation: textAnnotation,
                        oldSnapshot: originalSnapshot,
                        newSnapshot: newSnapshot,
                        canvas: self
                    )
                    historyManager.record(command)
                }
            } else {
                addAnnotation(textAnnotation)
            }
            
            selectedTextAnnotationID = selectCommittedText ? textAnnotation.id : nil
        } else if let originalSnapshot {
            textAnnotation.apply(snapshot: originalSnapshot)
            let command = RemoveAnnotationCommand(annotation: textAnnotation, canvas: self)
            historyManager.record(command)
            selectedTextAnnotationID = nil
        } else if !selectCommittedText {
            selectedTextAnnotationID = nil
        }
        
        if window?.firstResponder === textView {
            window?.makeFirstResponder(nil)
        }
        textView.removeFromSuperview()
        editingTextView = nil
        editingTextAnnotation = nil
        editingOriginalTextSnapshot = nil
        
        needsDisplay = true
        if currentTool == .text {
            publishTextStyleState()
        }
    }
    
    private func cancelActiveTextEditing() {
        guard let textView = editingTextView else { return }
        
        if let originalSnapshot = editingOriginalTextSnapshot,
           let textAnnotation = editingTextAnnotation {
            textAnnotation.apply(snapshot: originalSnapshot)
            addAnnotation(textAnnotation, recordCommand: false)
        }
        
        if window?.firstResponder === textView {
            window?.makeFirstResponder(nil)
        }
        
        textView.removeFromSuperview()
        editingTextView = nil
        editingTextAnnotation = nil
        editingOriginalTextSnapshot = nil
        selectedTextAnnotationID = nil
        needsDisplay = true
        
        if currentTool == .text {
            publishTextStyleState()
        }
    }
    
    private func createTextView(at position: CGPoint, style: TextAnnotationStyle, existingText: String) -> NSTextView {
        let textView = NSTextView()
        textView.frame = CGRect(x: position.x, y: position.y - 2, width: 300, height: 100)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textColor = style.color.withAlphaComponent(style.opacity)
        textView.font = .systemFont(ofSize: style.fontSize, weight: .medium)
        textView.isRichText = false
        textView.insertionPointColor = style.color
        textView.delegate = self
        textView.string = existingText
        
        // 多行支持
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = CGSize(width: 300, height: CGFloat.greatestFiniteMagnitude)
        
        return textView
    }
    
    private func publishTextStyleState() {
        if let textAnnotation = editingTextAnnotation {
            defaultTextStyle = textAnnotation.style
            currentColor = textAnnotation.style.color
            onTextStyleChanged?(textAnnotation.style, true)
            return
        }
        
        if let textAnnotation = selectedTextAnnotation {
            defaultTextStyle = textAnnotation.style
            currentColor = textAnnotation.style.color
            onTextStyleChanged?(textAnnotation.style, false)
            return
        }
        
        onTextStyleChanged?(defaultTextStyle, false)
    }

    private func applyTextStyle(_ style: TextAnnotationStyle) {
        defaultTextStyle = style
        currentColor = style.color

        if let textAnnotation = editingTextAnnotation {
            textAnnotation.style = style
            updateEditingTextViewStyle(style)
            needsDisplay = true
            publishTextStyleState()
            return
        }

        if let textAnnotation = selectedTextAnnotation {
            let oldSnapshot = TextAnnotationSnapshot(annotation: textAnnotation)
            textAnnotation.style = style
            let newSnapshot = TextAnnotationSnapshot(annotation: textAnnotation)
            if !textAnnotationMatches(snapshot: oldSnapshot, annotation: textAnnotation) {
                let command = EditTextAnnotationCommand(
                    annotation: textAnnotation,
                    oldSnapshot: oldSnapshot,
                    newSnapshot: newSnapshot,
                    canvas: self,
                    restoresSelection: true
                )
                historyManager.record(command)
            }
            needsDisplay = true
            onAnnotationsChanged?()
            publishTextStyleState()
            return
        }

        publishTextStyleState()
    }

    func selectedTextDecorationRect(for annotation: Annotation) -> CGRect? {
        guard currentTool == .text,
              let textAnnotation = annotation as? TextAnnotation,
              selectedTextAnnotation?.id == textAnnotation.id else {
            return nil
        }

        let textRect = textAnnotation.boundingRect()
        guard !textRect.isEmpty else { return nil }

        return textRect.insetBy(
            dx: -DesignTokens.Spacing.sm,
            dy: -DesignTokens.Spacing.xs
        )
    }

    private func updateEditingTextViewStyle(_ style: TextAnnotationStyle) {
        guard let textView = editingTextView else { return }
        textView.textColor = style.color.withAlphaComponent(style.opacity)
        textView.font = .systemFont(ofSize: style.fontSize, weight: .medium)
        textView.insertionPointColor = style.color
        if !textView.string.isEmpty {
            textView.textStorage?.setAttributes(
                [
                    .font: NSFont.systemFont(ofSize: style.fontSize, weight: .medium),
                    .foregroundColor: style.color.withAlphaComponent(style.opacity)
                ],
                range: NSRange(location: 0, length: textView.string.utf16.count)
            )
        }
    }

    func restoreTextSelection(_ annotationID: UUID?) {
        selectedTextAnnotationID = annotationID
        needsDisplay = true
    }

    func syncTextStyleStateAfterHistoryChange() {
        if currentTool == .text {
            publishTextStyleState()
        } else if selectedTextAnnotation == nil {
            currentColor = defaultTextStyle.color
        }
    }
    
    private func textAnnotationMatches(snapshot: TextAnnotationSnapshot, annotation: TextAnnotation) -> Bool {
        snapshot.text == annotation.text &&
        snapshot.position == annotation.position &&
        snapshot.maxWidth == annotation.maxWidth &&
        snapshot.style.fontSize == annotation.style.fontSize &&
        snapshot.style.color == annotation.style.color &&
        snapshot.style.opacity == annotation.style.opacity
    }

    private func drawSelectedTextDecoration(in rect: CGRect, context: CGContext) {
        let path = NSBezierPath(
            roundedRect: rect,
            xRadius: DesignTokens.CornerRadius.md,
            yRadius: DesignTokens.CornerRadius.md
        )
        path.lineJoinStyle = .round

        context.saveGState()
        context.setShadow(
            offset: .zero,
            blur: 10,
            color: DesignTokens.Colors.NS.selectionShadow.cgColor
        )
        DesignTokens.Colors.NS.glowHoverShadow.withAlphaComponent(0.9).setStroke()
        path.lineWidth = 3
        path.stroke()
        context.restoreGState()

        DesignTokens.Colors.NS.accentInfo.setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }
    
    // MARK: - Scroll Wheel (Adjust Brush Size)
    
    override func scrollWheel(with event: NSEvent) {
        if currentTool == .text, selectedTextAnnotation != nil {
            if event.hasPreciseScrollingDeltas, abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) {
                adjustSelectedTextOpacity(by: event.scrollingDeltaX * 0.003)
            } else if event.scrollingDeltaY != 0 {
                applyTextFontSizeStep(event.scrollingDeltaY > 0 ? 2 : -2)
            }
            return
        }

        guard currentTool == .pen || currentTool == .marker else {
            super.scrollWheel(with: event)
            return
        }
        
        let delta = event.scrollingDeltaY
        guard delta != 0 else { return }

        let change = delta > 0 ? 1.0 : -1.0
        currentBrushSize = min(max(currentBrushSize + change, 1.0), 100.0)
        updateCursor()
        window?.invalidateCursorRects(for: self)
    }

    // MARK: - Cursor
    
    func resolvedCursorStyle(hasInteractiveTarget: Bool) -> CursorStyle {
        if currentTool == .eraser {
            return hasInteractiveTarget ? .eraser : .arrow
        }

        if hasInteractiveTarget {
            return .openHand
        }

        switch currentTool {
        case .none: return .arrow
        case .arrow: return .crosshair
        case .pen, .marker: return .brush
        case .text: return .iBeam
        case .eraser: return .arrow
        }
    }

    private func applyCursorStyle(_ style: CursorStyle) {
        let cursor: NSCursor
        switch style {
        case .arrow: cursor = .arrow
        case .crosshair: cursor = .crosshair
        case .iBeam: cursor = .iBeam
        case .brush: cursor = createBrushCursor(size: currentBrushSize, color: currentColor)
        case .openHand: cursor = .openHand
        case .eraser: cursor = eraserCursor
        }
        cursor.set()
    }

    private func updateCursor() {
        applyCursorStyle(resolvedCursorStyle(hasInteractiveTarget: false))
    }
    
    private func createBrushCursor(size: CGFloat, color: NSColor) -> NSCursor {
        // 光标大小至少为 4，以免看不见
        let cursorSize = max(size, 4)
        // 增加一点 padding 避免边缘被切
        let imageSize = CGSize(width: cursorSize + 4, height: cursorSize + 4)
        let image = NSImage(size: imageSize)
        
        image.lockFocus()
        let context = NSGraphicsContext.current!.cgContext
        
        let rect = CGRect(x: 2, y: 2, width: cursorSize, height: cursorSize)
        
        // 绘制空心圆
        context.setStrokeColor(DesignTokens.Colors.NS.inkLight.cgColor)
        context.setLineWidth(1)
        context.strokeEllipse(in: rect.insetBy(dx: -0.5, dy: -0.5)) // 外白边（增加对比度）
        
        context.setStrokeColor(DesignTokens.Colors.NS.inkDark.cgColor)
        context.setLineWidth(1)
        context.strokeEllipse(in: rect) // 内黑边
        
        // 如果需要显示当前颜色的实心点（可选，用户只需要圆点）
        // context.setFillColor(color.withAlphaComponent(0.5).cgColor)
        // context.fillEllipse(in: rect)
        
        image.unlockFocus()
        
        return NSCursor(image: image, hotSpot: NSPoint(x: imageSize.width / 2, y: imageSize.height / 2))
    }
    
    private func createEraserCursor() -> NSCursor {
        let size = NSSize(width: 24, height: 24)
        let image = NSImage(size: size)

        image.lockFocus()

        let bounds = CGRect(origin: .zero, size: size)
        let backgroundRect = bounds.insetBy(dx: 2, dy: 2)

        DesignTokens.Colors.NS.overlayStrong.withAlphaComponent(0.92).setFill()
        NSBezierPath(ovalIn: backgroundRect).fill()

        DesignTokens.Colors.NS.inkLight.withAlphaComponent(0.95).setStroke()
        let ring = NSBezierPath(ovalIn: backgroundRect)
        ring.lineWidth = 1.5
        ring.stroke()

        var transform = AffineTransform(rotationByDegrees: -28)
        transform.translate(x: -2, y: 5)

        let body = NSBezierPath(
            roundedRect: NSRect(x: 7, y: 7, width: 10, height: 7),
            xRadius: 2,
            yRadius: 2
        )
        body.transform(using: transform)
        DesignTokens.Colors.NS.inkLight.setFill()
        body.fill()

        let edge = NSBezierPath()
        edge.move(to: CGPoint(x: 9, y: 8))
        edge.line(to: CGPoint(x: 15, y: 15))
        DesignTokens.Colors.NS.inkDark.withAlphaComponent(0.65).setStroke()
        edge.lineWidth = 1.5
        edge.stroke()

        image.unlockFocus()

        return NSCursor(image: image, hotSpot: NSPoint(x: size.width / 2, y: size.height / 2))
    }
    
    override func resetCursorRects() {
        super.resetCursorRects()

        let cursor: NSCursor
        switch resolvedCursorStyle(hasInteractiveTarget: false) {
        case .arrow: cursor = .arrow
        case .crosshair: cursor = .crosshair
        case .iBeam: cursor = .iBeam
        case .brush: cursor = createBrushCursor(size: currentBrushSize, color: currentColor)
        case .openHand: cursor = .openHand
        case .eraser: cursor = eraserCursor
        }

        addCursorRect(bounds, cursor: cursor)
    }
}

// MARK: - NSTextViewDelegate

extension AnnotationCanvasView: NSTextViewDelegate {
    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            // 检查 Shift 键
            if NSEvent.modifierFlags.contains(.shift) {
                // Shift+Enter = 换行
                textView.insertNewlineIgnoringFieldEditor(nil)
                return true
            }
            // Enter = 确认
            commitActiveTextIfNeeded(selectCommittedText: false)
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            // ESC = 取消
            cancelActiveTextEditing()
            return true
        }
        return false
    }
}
