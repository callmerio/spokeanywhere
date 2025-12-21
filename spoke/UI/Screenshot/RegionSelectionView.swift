import AppKit

// MARK: - Region Selection View

/// 选区交互视图
/// 处理鼠标拖拽框选、绘制选区边框、显示尺寸标签
/// 支持编辑模式：选区可移动和调整大小
final class RegionSelectionView: NSView {
    
    // MARK: - Types
    
    /// 视图状态机
    enum State {
        case idle           // 初始状态，等待用户开始框选
        case selecting      // 正在框选
        case editing        // 编辑模式：选区可调整
    }
    
    /// 控制点定义
    enum ResizeHandle: CaseIterable {
        case topLeft, topCenter, topRight
        case middleLeft, middleRight
        case bottomLeft, bottomCenter, bottomRight
        
        /// 获取控制点的命中区域
        func hitRect(for bounds: CGRect, handleSize: CGFloat = 10) -> CGRect {
            let half = handleSize / 2
            let center: CGPoint
            
            switch self {
            case .topLeft:      center = CGPoint(x: bounds.minX, y: bounds.maxY)
            case .topCenter:    center = CGPoint(x: bounds.midX, y: bounds.maxY)
            case .topRight:     center = CGPoint(x: bounds.maxX, y: bounds.maxY)
            case .middleLeft:   center = CGPoint(x: bounds.minX, y: bounds.midY)
            case .middleRight:  center = CGPoint(x: bounds.maxX, y: bounds.midY)
            case .bottomLeft:   center = CGPoint(x: bounds.minX, y: bounds.minY)
            case .bottomCenter: center = CGPoint(x: bounds.midX, y: bounds.minY)
            case .bottomRight:  center = CGPoint(x: bounds.maxX, y: bounds.minY)
            }
            
            return CGRect(x: center.x - half, y: center.y - half, width: handleSize, height: handleSize)
        }
        
        /// 获取对应的光标
        func cursor() -> NSCursor {
            switch self {
            case .topLeft, .bottomRight: return .crosshair // 或自定义对角光标
            case .topRight, .bottomLeft: return .crosshair
            case .topCenter, .bottomCenter: return .resizeUpDown
            case .middleLeft, .middleRight: return .resizeLeftRight
            }
        }
    }
    
    // MARK: - Constants
    
    private enum Design {
        static let overlayColor = NSColor.black.withAlphaComponent(0.4)
        static let borderColor = NSColor.systemBlue
        static let borderWidth: CGFloat = 2
        static let handleSize: CGFloat = 8
        static let handleHitSize: CGFloat = 14 // 命中检测区域更大
        static let sizeTagFont = NSFont.systemFont(ofSize: 12, weight: .medium)
        static let sizeTagPadding: CGFloat = 6
        static let sizeTagCornerRadius: CGFloat = 4
        static let sizeTagBackgroundColor = NSColor.black.withAlphaComponent(0.7)
        static let sizeTagTextColor = NSColor.white
        static let minSelectionSize: CGFloat = 20
    }
    
    // MARK: - State
    
    private(set) var state: State = .idle
    private(set) var selectionRect: CGRect = .zero
    
    /// 拖拽起点
    private var dragStartPoint: CGPoint = .zero
    /// 拖拽开始时的选区
    private var dragStartRect: CGRect = .zero
    /// 当前拖拽的控制点
    private var activeHandle: ResizeHandle?
    /// 是否正在拖拽选区
    private var isDraggingSelection: Bool = false
    
    /// 标注画布
    private(set) var annotationCanvas: AnnotationCanvasView?
    
    /// 当前标注工具
    var currentAnnotationTool: AnnotationCanvasView.Tool = .none {
        didSet {
            annotationCanvas?.currentTool = currentAnnotationTool
            // 标注模式下禁用选区调整
            if currentAnnotationTool != .none {
                activeHandle = nil
                isDraggingSelection = false
            }
        }
    }
    
    /// 背景图片（全屏截图）
    var backgroundImage: NSImage? {
        didSet { needsDisplay = true }
    }
    
    // MARK: - Callbacks
    
    /// 选区完成回调（框选完成，进入编辑模式）
    var onSelectionComplete: ((CGRect) -> Void)?
    
    /// 取消回调
    var onCancel: (() -> Void)?
    
    /// 确认回调（用户点击确认按钮）
    var onConfirm: ((CGRect) -> Void)?
    
    /// 选区变化回调（编辑模式下选区移动/调整大小）
    var onSelectionChanged: ((CGRect) -> Void)?
    
    // MARK: - Init
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        // 🔧 Fix: 设置 layerContentsRedrawPolicy 确保正确重绘
        // .onSetNeedsDisplay = 每次 needsDisplay 时重新调用 draw(_:)
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }
    
    /// 响应 backing properties 变化（屏幕切换、分辨率变化）
    /// 🔧 Fix: 使用 viewDidChangeBackingProperties 而非 viewDidMoveToWindow
    /// 参考: https://supermegaultragroovy.com/2012/10/24/coding-for-high-resolution-on-os-x-read-this/
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateContentsScale()
        // 强制重绘以使用新的 scale
        needsDisplay = true
    }
    
    /// 窗口变化时也更新（首次显示）
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateContentsScale()
    }
    
    /// 更新 layer 的 contentsScale 以匹配当前屏幕
    private func updateContentsScale() {
        guard let window = window, let layer = layer else { return }
        let scale = window.backingScaleFactor
        layer.contentsScale = scale
        // 同步更新子视图的 layer scale
        annotationCanvas?.layer?.contentsScale = scale
        #if DEBUG
        print("🔍 [RegionSelectionView] contentsScale set to \(scale)")
        #endif
    }
    
    private func setupAnnotationCanvas() {
        // 移除旧画布
        annotationCanvas?.removeFromSuperview()
        
        // 创建新画布，覆盖选区
        let canvas = AnnotationCanvasView(frame: selectionRect)
        canvas.autoresizingMask = []
        addSubview(canvas)
        annotationCanvas = canvas
        
        // 监听历史变化
        canvas.onHistoryChanged = { [weak self] canUndo, canRedo in
            self?.onAnnotationHistoryChanged?(canUndo, canRedo)
        }
    }
    
    /// 更新标注画布位置（选区调整时）
    private func updateAnnotationCanvasFrame() {
        annotationCanvas?.frame = selectionRect
    }
    
    // MARK: - Public API
    
    /// 进入编辑模式
    func enterEditMode() {
        guard selectionRect.width > Design.minSelectionSize,
              selectionRect.height > Design.minSelectionSize else { return }
        state = .editing
        needsDisplay = true
    }
    
    /// 重置状态
    func reset() {
        state = .idle
        selectionRect = .zero
        activeHandle = nil
        isDraggingSelection = false
        currentAnnotationTool = .none
        annotationCanvas?.removeFromSuperview()
        annotationCanvas = nil
        needsDisplay = true
    }
    
    /// 设置标注工具
    func setAnnotationTool(_ tool: AnnotationCanvasView.Tool) {
        currentAnnotationTool = tool
    }
    
    /// 撤销标注
    func undoAnnotation() {
        annotationCanvas?.undo()
    }
    
    /// 重做标注
    func redoAnnotation() {
        annotationCanvas?.redo()
    }
    
    /// 获取 Undo/Redo 状态
    var canUndoAnnotation: Bool { annotationCanvas?.canUndo ?? false }
    var canRedoAnnotation: Bool { annotationCanvas?.canRedo ?? false }
    
    /// 获取带标注的图片
    func getAnnotatedImage() -> NSImage? {
        guard let bgImage = backgroundImage else { return nil }
        
        // 从 NSImage 获取 CGImage representation
        guard let cgImage = bgImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        // 🔧 Fix: 使用 CGImage 的实际像素尺寸计算 scale，而非 window.backingScaleFactor
        // 这样可以正确处理不同屏幕的不同 DPI
        let imagePixelWidth = CGFloat(cgImage.width)
        let imagePixelHeight = CGFloat(cgImage.height)
        
        // 计算实际 scale (像素/点)
        // bounds 是视图的点尺寸，imagePixel 是图片的像素尺寸
        let scaleX = imagePixelWidth / bounds.width
        let scaleY = imagePixelHeight / bounds.height
        
        // 使用 X/Y 的平均值（通常两者相等）
        let scale = (scaleX + scaleY) / 2.0
        
        // 计算像素级别的裁剪区域
        // CGImage 坐标系是左上角原点，需要从 AppKit 的左下角原点转换
        let pixelRect = CGRect(
            x: selectionRect.origin.x * scale,
            y: (bounds.height - selectionRect.maxY) * scale, // 翻转 Y 坐标
            width: selectionRect.width * scale,
            height: selectionRect.height * scale
        )
        
        // 裁剪 CGImage
        guard let croppedCGImage = cgImage.cropping(to: pixelRect) else {
            return nil
        }
        
        // 创建高分辨率 NSImage，使用选区的点尺寸
        let croppedImage = NSImage(cgImage: croppedCGImage, size: selectionRect.size)
        
        // 叠加标注
        if let canvas = annotationCanvas, !canvas.annotations.isEmpty {
            return canvas.renderAnnotations(on: croppedImage)
        }
        
        return croppedImage
    }
    
    /// 设置标注历史回调
    var onAnnotationHistoryChanged: ((Bool, Bool) -> Void)? {
        get { annotationCanvas?.onHistoryChanged }
        set { annotationCanvas?.onHistoryChanged = newValue }
    }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // 设置高质量插值，避免 Retina 屏幕模糊
        context.interpolationQuality = .high
        
        // 1. 绘制背景图片
        if let image = backgroundImage {
            // 使用 draw(in:from:operation:fraction:respectFlipped:hints:) 获得更好的质量
            image.draw(in: bounds,
                      from: NSRect(origin: .zero, size: image.size),
                      operation: .copy,
                      fraction: 1.0,
                      respectFlipped: true,
                      hints: [.interpolation: NSImageInterpolation.high])
        }
        
        // 2. 绘制半透明遮罩（选区外部变暗）
        drawOverlay(context: context)
        
        // 3. 绘制选区边框和控制点
        if selectionRect.width > 0 && selectionRect.height > 0 {
            drawSelectionBorder(context: context)
            drawSizeTag(context: context)
            
            // 编辑模式下绘制 8 个控制点
            if state == .editing {
                drawResizeHandles(context: context)
            }
        }
        
        // 4. 绘制十字准星（仅初始状态）
        if state == .idle && selectionRect.isEmpty {
            drawCrosshair(context: context)
        }
    }
    
    /// 绘制遮罩层（选区外部变暗）
    private func drawOverlay(context: CGContext) {
        context.saveGState()
        
        Design.overlayColor.setFill()
        
        if selectionRect.width > 0 && selectionRect.height > 0 {
            // 挖空选区
            let path = NSBezierPath(rect: bounds)
            path.append(NSBezierPath(rect: selectionRect).reversed)
            path.fill()
        } else {
            bounds.fill()
        }
        
        context.restoreGState()
    }
    
    /// 绘制选区边框
    private func drawSelectionBorder(context: CGContext) {
        let borderPath = NSBezierPath(rect: selectionRect)
        
        // 白色外边框
        NSColor.white.withAlphaComponent(0.5).setStroke()
        borderPath.lineWidth = Design.borderWidth + 2
        borderPath.stroke()
        
        // 蓝色主边框
        Design.borderColor.setStroke()
        borderPath.lineWidth = Design.borderWidth
        borderPath.stroke()
    }
    
    /// 绘制 8 个控制点
    private func drawResizeHandles(context: CGContext) {
        for handle in ResizeHandle.allCases {
            let rect = handle.hitRect(for: selectionRect, handleSize: Design.handleSize)
            
            // 白色填充
            NSColor.white.setFill()
            let path = NSBezierPath(ovalIn: rect)
            path.fill()
            
            // 蓝色边框
            Design.borderColor.setStroke()
            path.lineWidth = 1.5
            path.stroke()
        }
    }
    
    /// 绘制尺寸标签
    private func drawSizeTag(context: CGContext) {
        let width = Int(selectionRect.width)
        let height = Int(selectionRect.height)
        let sizeText = "\(width) × \(height) pt"
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Design.sizeTagFont,
            .foregroundColor: Design.sizeTagTextColor
        ]
        
        let textSize = sizeText.size(withAttributes: attributes)
        let tagSize = CGSize(
            width: textSize.width + Design.sizeTagPadding * 2,
            height: textSize.height + Design.sizeTagPadding
        )
        
        // 标签位置：选区左上角上方
        var tagOrigin = CGPoint(
            x: selectionRect.minX,
            y: selectionRect.maxY + 8
        )
        
        // 边界检查
        if tagOrigin.y + tagSize.height > bounds.maxY - 10 {
            tagOrigin.y = selectionRect.minY - tagSize.height - 8
        }
        
        let tagRect = CGRect(origin: tagOrigin, size: tagSize)
        
        // 背景
        let bgPath = NSBezierPath(roundedRect: tagRect, xRadius: Design.sizeTagCornerRadius, yRadius: Design.sizeTagCornerRadius)
        Design.sizeTagBackgroundColor.setFill()
        bgPath.fill()
        
        // 文字
        let textOrigin = CGPoint(
            x: tagRect.minX + Design.sizeTagPadding,
            y: tagRect.minY + Design.sizeTagPadding / 2
        )
        sizeText.draw(at: textOrigin, withAttributes: attributes)
    }
    
    /// 绘制十字准星
    private func drawCrosshair(context: CGContext) {
        guard let mouseLocation = window?.mouseLocationOutsideOfEventStream else { return }
        let point = convert(mouseLocation, from: nil)
        
        context.saveGState()
        
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [5, 5])
        
        // 水平线
        context.move(to: CGPoint(x: 0, y: point.y))
        context.addLine(to: CGPoint(x: bounds.width, y: point.y))
        
        // 垂直线
        context.move(to: CGPoint(x: point.x, y: 0))
        context.addLine(to: CGPoint(x: point.x, y: bounds.height))
        
        context.strokePath()
        context.restoreGState()
    }
    
    // MARK: - Hit Testing
    
    /// 检测点击位置对应的控制点
    private func hitTestHandle(at point: CGPoint) -> ResizeHandle? {
        for handle in ResizeHandle.allCases {
            let hitRect = handle.hitRect(for: selectionRect, handleSize: Design.handleHitSize)
            if hitRect.contains(point) {
                return handle
            }
        }
        return nil
    }
    
    // MARK: - Mouse Events
    
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        dragStartPoint = location
        dragStartRect = selectionRect
        
        switch state {
        case .idle:
            // 开始框选
            selectionRect = .zero
            state = .selecting
            
        case .selecting:
            // 不应该到这里
            break
            
        case .editing:
            // 检查是否点击了控制点
            if let handle = hitTestHandle(at: location) {
                activeHandle = handle
            } else if selectionRect.contains(location) {
                // 点击选区内部，开始拖拽
                isDraggingSelection = true
            }
            // 点击选区外部：不做任何事（不重新框选）
        }
        
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        let currentPoint = convert(event.locationInWindow, from: nil)
        
        switch state {
        case .idle:
            break
            
        case .selecting:
            // 计算选区矩形
            let minX = min(dragStartPoint.x, currentPoint.x)
            let minY = min(dragStartPoint.y, currentPoint.y)
            let width = abs(currentPoint.x - dragStartPoint.x)
            let height = abs(currentPoint.y - dragStartPoint.y)
            
            selectionRect = CGRect(x: minX, y: minY, width: width, height: height)
            
        case .editing:
            if let handle = activeHandle {
                // 调整选区大小
                resizeSelection(to: currentPoint, using: handle)
            } else if isDraggingSelection {
                // 移动选区
                let deltaX = currentPoint.x - dragStartPoint.x
                let deltaY = currentPoint.y - dragStartPoint.y
                
                var newRect = dragStartRect.offsetBy(dx: deltaX, dy: deltaY)
                
                // 边界限制
                newRect.origin.x = max(0, min(newRect.origin.x, bounds.width - newRect.width))
                newRect.origin.y = max(0, min(newRect.origin.y, bounds.height - newRect.height))
                
                selectionRect = newRect
            }
            
            onSelectionChanged?(selectionRect)
        }
        
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        switch state {
        case .idle:
            break
            
        case .selecting:
            if selectionRect.width > Design.minSelectionSize && selectionRect.height > Design.minSelectionSize {
                // 框选完成，进入编辑模式
                state = .editing
                
                // 创建标注画布
                setupAnnotationCanvas()
                
                onSelectionComplete?(selectionRect)
            } else {
                // 选区太小，重置
                selectionRect = .zero
                state = .idle
            }
            
        case .editing:
            activeHandle = nil
            isDraggingSelection = false
        }
        
        needsDisplay = true
    }
    
    override func mouseMoved(with event: NSEvent) {
        if state == .idle {
            needsDisplay = true
        }
    }
    
    // MARK: - Resize Logic
    
    private func resizeSelection(to point: CGPoint, using handle: ResizeHandle) {
        var newRect = dragStartRect
        
        switch handle {
        case .topLeft:
            newRect.origin.x = min(point.x, dragStartRect.maxX - Design.minSelectionSize)
            newRect.size.width = dragStartRect.maxX - newRect.origin.x
            newRect.size.height = max(Design.minSelectionSize, point.y - dragStartRect.minY)
            
        case .topCenter:
            newRect.size.height = max(Design.minSelectionSize, point.y - dragStartRect.minY)
            
        case .topRight:
            newRect.size.width = max(Design.minSelectionSize, point.x - dragStartRect.minX)
            newRect.size.height = max(Design.minSelectionSize, point.y - dragStartRect.minY)
            
        case .middleLeft:
            newRect.origin.x = min(point.x, dragStartRect.maxX - Design.minSelectionSize)
            newRect.size.width = dragStartRect.maxX - newRect.origin.x
            
        case .middleRight:
            newRect.size.width = max(Design.minSelectionSize, point.x - dragStartRect.minX)
            
        case .bottomLeft:
            newRect.origin.x = min(point.x, dragStartRect.maxX - Design.minSelectionSize)
            newRect.size.width = dragStartRect.maxX - newRect.origin.x
            newRect.origin.y = min(point.y, dragStartRect.maxY - Design.minSelectionSize)
            newRect.size.height = dragStartRect.maxY - newRect.origin.y
            
        case .bottomCenter:
            newRect.origin.y = min(point.y, dragStartRect.maxY - Design.minSelectionSize)
            newRect.size.height = dragStartRect.maxY - newRect.origin.y
            
        case .bottomRight:
            newRect.size.width = max(Design.minSelectionSize, point.x - dragStartRect.minX)
            newRect.origin.y = min(point.y, dragStartRect.maxY - Design.minSelectionSize)
            newRect.size.height = dragStartRect.maxY - newRect.origin.y
        }
        
        // 边界限制
        newRect.origin.x = max(0, newRect.origin.x)
        newRect.origin.y = max(0, newRect.origin.y)
        if newRect.maxX > bounds.width {
            newRect.size.width = bounds.width - newRect.origin.x
        }
        if newRect.maxY > bounds.height {
            newRect.size.height = bounds.height - newRect.origin.y
        }
        
        selectionRect = newRect
    }
    
    // MARK: - Keyboard Events
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53:  // ESC
            if state == .editing {
                reset()
            }
            onCancel?()
            
        case 36:  // Enter
            if state == .editing && selectionRect.width > Design.minSelectionSize && selectionRect.height > Design.minSelectionSize {
                onConfirm?(selectionRect)
            }
            
        default:
            super.keyDown(with: event)
        }
    }
    
    // MARK: - Tracking
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }
}
