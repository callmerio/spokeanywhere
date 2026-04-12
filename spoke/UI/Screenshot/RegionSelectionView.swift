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

    @MainActor
    private enum Design {
        static let overlayColor = DesignTokens.Colors.NS.overlayLight

        // Cursor
        static let crosshairSize: CGFloat = 14
        static let crosshairColor = NSColor.white
        static let crosshairThickness: CGFloat = 1.5
        static let crosshairShadowColor = NSColor.black.withAlphaComponent(0.5)

        static let borderColor = DesignTokens.Colors.NS.accentPrimary
        static let borderWidth: CGFloat = 1.0

        // Handles
        static let handleSize: CGFloat = 8
        static let handleHitSize: CGFloat = 14
        static let handleColor = NSColor.white
        static let handleBorderColor = DesignTokens.Colors.NS.accentPrimary

        static let sizeTagFont = NSFont.systemFont(ofSize: 12, weight: .medium)
        static let sizeTagPadding: CGFloat = 6
        static let sizeTagCornerRadius: CGFloat = 4
        static let sizeTagBackgroundColor = DesignTokens.Colors.NS.overlayStrong
        static let sizeTagTextColor = DesignTokens.Colors.NS.textPrimary
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
    
    /// 当前鼠标下的颜色
    private var currentColor: NSColor?
    /// 缓存的位图数据，用于快速取色
    private var bitmapRep: NSBitmapImageRep?

    /// 背景图片（全屏截图）
    var backgroundImage: NSImage? {
        didSet {
            needsDisplay = true
            if let image = backgroundImage {
                // 尝试获取或创建 bitmapRep
                if let existingRep = image.representations.first(where: { $0 is NSBitmapImageRep }) as? NSBitmapImageRep {
                    bitmapRep = existingRep
                } else if let tiff = image.tiffRepresentation {
                    bitmapRep = NSBitmapImageRep(data: tiff)
                }
            }
        }
    }

    /// 标注历史变更回调
    private var annotationHistoryChangedHandler: ((Bool, Bool) -> Void)?
    
    // MARK: - Callbacks
    
    /// 选区完成回调（框选完成，进入编辑模式）
    var onSelectionComplete: ((CGRect) -> Void)?
    
    /// 取消回调
    var onCancel: (() -> Void)?
    
    /// 确认回调（用户点击确认按钮）
    var onConfirm: ((CGRect) -> Void)?
    
    /// 选区变化回调（编辑模式下选区移动/调整大小）
    var onSelectionChanged: ((CGRect) -> Void)?

    /// 文字样式变化回调
    var onTextStyleChanged: ((TextAnnotationStyle, Bool) -> Void)?
    
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
            self?.annotationHistoryChangedHandler?(canUndo, canRedo)
        }
        canvas.onTextStyleChanged = { [weak self] style, hasSelectedText in
            self?.onTextStyleChanged?(style, hasSelectedText)
        }
    }
    
    /// 更新标注画布位置（选区调整时）
    private func updateAnnotationCanvasFrame() {
        annotationCanvas?.frame = selectionRect
    }
}

extension RegionSelectionView {
    
    // MARK: - Public API
    
    /// 进入编辑模式
    func enterEditMode() {
        guard selectionRect.width > Design.minSelectionSize,
              selectionRect.height > Design.minSelectionSize else { return }
        state = .editing
        needsDisplay = true
    }

    /// 复制当前光标下的颜色到剪贴板
    func copyCurrentColor() {
        guard let color = currentColor else { return }

        let r = Int(color.redComponent * 255)
        let g = Int(color.greenComponent * 255)
        let b = Int(color.blueComponent * 255)
        let hex = String(format: "#%02X%02X%02X", r, g, b)

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(hex, forType: .string)
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
        // 恢复系统光标
        NSCursor.unhide()
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

    func adjustTextFontSize(by delta: CGFloat) {
        annotationCanvas?.applyTextFontSizeStep(delta)
    }

    func applyTextColor(_ color: NSColor) {
        annotationCanvas?.applyTextColor(color)
    }
    
    /// 获取 Undo/Redo 状态
    var canUndoAnnotation: Bool { annotationCanvas?.canUndo ?? false }
    var canRedoAnnotation: Bool { annotationCanvas?.canRedo ?? false }
    
    /// 获取带标注的图片
    func getAnnotatedImage() -> NSImage? {
        guard let bgImage = backgroundImage else { return nil }
        annotationCanvas?.commitActiveTextIfNeeded(selectCommittedText: false)
        
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
        get { annotationHistoryChangedHandler }
        set { annotationHistoryChangedHandler = newValue }
    }
}

extension RegionSelectionView {
    
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
        
        // 3. 绘制选区边框、控制点和尺寸标签
        if selectionRect.width > 0 && selectionRect.height > 0 {
            drawSelectionBorder(context: context)
            drawSizeTag(context: context)

            // 编辑模式下绘制控制点
            if state == .editing {
                drawResizeHandles(context: context)
            }
        }

        // 4. 绘制放大镜和自定义光标
        // 仅在 Idle 或 Selecting 状态下显示自定义光标
        // Editing 状态下显示系统光标
        if state != .editing {
            drawMagnifierAndCursor(context: context)
        }
    }

    /// 绘制选区边框
    private func drawSelectionBorder(context: CGContext) {
        let borderPath = NSBezierPath(rect: selectionRect)

        // 外部阴影/描边以增强对比度
        NSColor.black.withAlphaComponent(0.3).setStroke()
        borderPath.lineWidth = Design.borderWidth + 2
        borderPath.stroke()

        // 主边框
        Design.borderColor.setStroke()
        borderPath.lineWidth = Design.borderWidth
        borderPath.stroke()
    }

    /// 绘制 8 个控制点
    private func drawResizeHandles(context: CGContext) {
        let handleLength: CGFloat = 12
        let thickness: CGFloat = 3.0

        context.setStrokeColor(Design.handleBorderColor.cgColor)
        context.setLineWidth(thickness)
        context.setLineCap(.butt) // 直角端点

        for handle in ResizeHandle.allCases {
            // 注意：hitRect 返回的是以 handle center 为中心的矩形
            let rect = handle.hitRect(for: selectionRect, handleSize: Design.handleSize)
            let path = CGMutablePath()

            // 根据把手位置绘制折线
            switch handle {
            case .topLeft:
                // 左上角：maxY 是上边缘 (如果 isFlipped=false)
                path.move(to: CGPoint(x: rect.minX, y: rect.maxY - handleLength))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX + handleLength, y: rect.maxY))

            case .topCenter:
                path.move(to: CGPoint(x: rect.midX - handleLength/2, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.midX + handleLength/2, y: rect.maxY))

            case .topRight:
                path.move(to: CGPoint(x: rect.maxX - handleLength, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - handleLength))

            case .middleRight:
                path.move(to: CGPoint(x: rect.maxX, y: rect.midY - handleLength/2))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY + handleLength/2))

            case .bottomRight:
                path.move(to: CGPoint(x: rect.maxX, y: rect.minY + handleLength))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX - handleLength, y: rect.minY))

            case .bottomCenter:
                path.move(to: CGPoint(x: rect.midX - handleLength/2, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.midX + handleLength/2, y: rect.minY))

            case .bottomLeft:
                path.move(to: CGPoint(x: rect.minX + handleLength, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + handleLength))

            case .middleLeft:
                path.move(to: CGPoint(x: rect.minX, y: rect.midY - handleLength/2))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.midY + handleLength/2))
            }

            context.addPath(path)
            context.strokePath()
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
    
    /// 绘制放大镜和自定义光标
    private func drawMagnifierAndCursor(context: CGContext) {
        guard let window = window else { return }

        // 获取鼠标位置 (相对于 view)
        let mouseLoc = window.mouseLocationOutsideOfEventStream
        let point = convert(mouseLoc, from: nil)

        // 检查鼠标是否在视图内
        guard bounds.contains(point) else { return }

        context.saveGState()

        // 1. 绘制自定义光标 (十字准星)
        drawCustomCursor(context: context, at: point)

        context.restoreGState()
    }

    private func drawCustomCursor(context: CGContext, at point: CGPoint) {
        context.setStrokeColor(Design.crosshairColor.cgColor)
        context.setLineWidth(Design.crosshairThickness)
        context.setShadow(offset: .zero, blur: 1, color: Design.crosshairShadowColor.cgColor)

        let size = Design.crosshairSize
        let half = size / 2

        // 水平线
        context.move(to: CGPoint(x: point.x - half, y: point.y))
        context.addLine(to: CGPoint(x: point.x + half, y: point.y))

        // 垂直线
        context.move(to: CGPoint(x: point.x, y: point.y - half))
        context.addLine(to: CGPoint(x: point.x, y: point.y + half))

        context.strokePath()
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
}

extension RegionSelectionView {

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
                updateCursorVisibility()

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
        // 重绘以更新自定义光标位置
        if state == .idle || state == .selecting {
            needsDisplay = true
        }
    }
}

extension RegionSelectionView {
    
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
}

extension RegionSelectionView {
    
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
}

extension RegionSelectionView {
    
    // MARK: - Tracking
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateCursorVisibility()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        NSCursor.unhide()
    }

    private func updateCursorVisibility() {
        if state == .editing {
            NSCursor.unhide()
        } else {
            NSCursor.hide()
        }
    }
}
