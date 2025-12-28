import AppKit

// MARK: - Annotation Canvas Protocol

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
    
    // MARK: - Properties
    
    private(set) var annotations: [Annotation] = []
    private let historyManager = AnnotationHistoryManager()
    
    var currentTool: Tool = .none {
        didSet {
            // 切换工具时重置笔刷大小（如果需要）
            // 这里我们保留笔刷大小，或者为不同工具设置默认值
            switch currentTool {
            case .pen: currentBrushSize = 3
            case .marker: currentBrushSize = 20
            default: break
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
        needsDisplay = true
    }
    
    func redo() {
        historyManager.redo()
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
        
        // 双击检测：编辑文字
        if event.clickCount == 2 {
            if let textAnnotation = annotations.last(where: { $0.hitTest(point: location) }) as? TextAnnotation {
                editExistingText(textAnnotation)
                return
            }
        }
        
        // 检查是否点击了现有标注（用于拖动）
        if currentTool == .none || currentTool == .text {
            if let annotation = findAnnotation(at: location) {
                // 单击标注开始拖动
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
            showTextInput(at: location)
            
        case .eraser:
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
        if findAnnotation(at: location) != nil {
            NSCursor.openHand.set()
        } else {
            updateCursor()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        hoveredAnnotation = nil
    }
    
    private func editExistingText(_ textAnnotation: TextAnnotation) {
        // 移除原标注
        annotations.removeAll { $0.id == textAnnotation.id }
        needsDisplay = true
        
        // 显示编辑框
        editingTextAnnotation = textAnnotation
        
        let textView = createTextView(at: textAnnotation.position, existingText: textAnnotation.text)
        addSubview(textView)
        editingTextView = textView
        
        window?.makeFirstResponder(textView)
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
    
    // MARK: - Text Input
    
    private func showTextInput(at position: CGPoint) {
        finishTextEditing()
        
        let textAnnotation = TextAnnotation(position: position, text: "", color: currentColor)
        editingTextAnnotation = textAnnotation
        
        let textView = createTextView(at: position, existingText: "")
        addSubview(textView)
        editingTextView = textView
        
        window?.makeFirstResponder(textView)
    }
    
    private func createTextView(at position: CGPoint, existingText: String) -> NSTextView {
        let textView = NSTextView()
        textView.frame = CGRect(x: position.x, y: position.y - 2, width: 300, height: 100)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textColor = currentColor
        textView.font = .systemFont(ofSize: 16, weight: .medium)
        textView.isRichText = false
        textView.insertionPointColor = currentColor
        textView.delegate = self
        textView.string = existingText
        
        // 多行支持
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = CGSize(width: 300, height: CGFloat.greatestFiniteMagnitude)
        
        return textView
    }
    
    private func finishTextEditing() {
        guard let textView = editingTextView,
              let textAnnotation = editingTextAnnotation else { return }
        
        let text = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !text.isEmpty {
            textAnnotation.text = text
            // 保持输入时的换行宽度
            if let containerWidth = textView.textContainer?.containerSize.width {
                textAnnotation.maxWidth = containerWidth
            }
            addAnnotation(textAnnotation)
        }
        
        textView.removeFromSuperview()
        editingTextView = nil
        editingTextAnnotation = nil
        
        needsDisplay = true
    }
    
    // MARK: - Scroll Wheel (Adjust Brush Size)
    
    override func scrollWheel(with event: NSEvent) {
        guard currentTool == .pen || currentTool == .marker else {
            super.scrollWheel(with: event)
            return
        }
        
        let delta = event.scrollingDeltaY
        if delta == 0 { return }
        
        // 向上滚动 (delta > 0) -> 变大，向下滚动 (delta < 0) -> 变小
        let change = delta > 0 ? 1.0 : -1.0
        let newSize = currentBrushSize + CGFloat(change)
        
        // 限制范围
        currentBrushSize = min(max(newSize, 1.0), 100.0)
        
        // 刷新光标
        updateCursor()
        window?.invalidateCursorRects(for: self)
    }

    // MARK: - Cursor
    
    private func updateCursor() {
        let cursor: NSCursor
        switch currentTool {
        case .none: cursor = .arrow
        case .arrow: cursor = .crosshair
        case .pen, .marker: cursor = createBrushCursor(size: currentBrushSize, color: currentColor)
        case .text: cursor = .iBeam
        case .eraser: cursor = eraserCursor
        }
        cursor.set()
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
        let size: CGFloat = 24
        let image = NSImage(size: NSSize(width: size, height: size))
        
        image.lockFocus()
        
        let context = NSGraphicsContext.current!.cgContext
        
        // 白色圆形背景
        context.setFillColor(DesignTokens.Colors.NS.inkLight.cgColor)
        context.fillEllipse(in: CGRect(x: 2, y: 2, width: size - 4, height: size - 4))
        
        // 灰色边框
        context.setStrokeColor(DesignTokens.Colors.NS.inkMuted.cgColor)
        context.setLineWidth(2)
        context.strokeEllipse(in: CGRect(x: 2, y: 2, width: size - 4, height: size - 4))
        
        // 红色斜线（禁止符号）
        context.setStrokeColor(DesignTokens.Colors.NS.error.cgColor)
        context.setLineWidth(2.5)
        context.move(to: CGPoint(x: 6, y: size - 6))
        context.addLine(to: CGPoint(x: size - 6, y: 6))
        context.strokePath()
        
        image.unlockFocus()
        
        return NSCursor(image: image, hotSpot: NSPoint(x: size / 2, y: size / 2))
    }
    
    override func resetCursorRects() {
        super.resetCursorRects()
        
        let cursor: NSCursor
        switch currentTool {
        case .none: cursor = .arrow
        case .arrow: cursor = .crosshair
        case .pen, .marker: cursor = createBrushCursor(size: currentBrushSize, color: currentColor)
        case .text: cursor = .iBeam
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
            finishTextEditing()
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            // ESC = 取消
            editingTextView?.removeFromSuperview()
            editingTextView = nil
            editingTextAnnotation = nil
            return true
        }
        return false
    }
}
