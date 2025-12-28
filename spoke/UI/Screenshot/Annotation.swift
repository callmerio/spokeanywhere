import AppKit

// MARK: - Annotation Protocol

/// 标注对象协议
protocol Annotation: AnyObject {
    var id: UUID { get }
    var type: AnnotationType { get }
    var color: NSColor { get set }
    var lineWidth: CGFloat { get set }
    
    /// 绘制标注
    func draw(in context: CGContext)
    
    /// 命中检测
    func hitTest(point: CGPoint) -> Bool
    
    /// 移动标注
    func move(by delta: CGPoint)
    
    /// 复制
    func copy() -> Annotation
}

// MARK: - Annotation Type

enum AnnotationType: String, CaseIterable {
    case arrow
    case pen
    case marker
    case text
}

// MARK: - Arrow Annotation

/// 箭头标注
final class ArrowAnnotation: Annotation {
    let id = UUID()
    let type: AnnotationType = .arrow
    
    var startPoint: CGPoint
    var endPoint: CGPoint
    var color: NSColor
    var lineWidth: CGFloat
    
    /// 箭头头部宽度
    var headWidth: CGFloat = 16
    /// 箭头头部长度
    var headLength: CGFloat = 12
    
    init(start: CGPoint, end: CGPoint, color: NSColor = DesignTokens.Colors.NS.annotationPrimary, lineWidth: CGFloat = 3) {
        self.startPoint = start
        self.endPoint = end
        self.color = color
        self.lineWidth = lineWidth
    }
    
    func draw(in context: CGContext) {
        let path = createArrowPath()
        
        context.saveGState()
        context.setFillColor(color.cgColor)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()
    }
    
    func hitTest(point: CGPoint) -> Bool {
        let minX = min(startPoint.x, endPoint.x) - 10
        let maxX = max(startPoint.x, endPoint.x) + 10
        let minY = min(startPoint.y, endPoint.y) - 10
        let maxY = max(startPoint.y, endPoint.y) + 10
        
        return point.x >= minX && point.x <= maxX &&
               point.y >= minY && point.y <= maxY
    }
    
    func move(by delta: CGPoint) {
        startPoint.x += delta.x
        startPoint.y += delta.y
        endPoint.x += delta.x
        endPoint.y += delta.y
    }
    
    func copy() -> Annotation {
        let arrow = ArrowAnnotation(start: startPoint, end: endPoint, color: color, lineWidth: lineWidth)
        arrow.headWidth = headWidth
        arrow.headLength = headLength
        return arrow
    }
    
    // MARK: - Arrow Path
    
    private func createArrowPath() -> CGPath {
        let path = CGMutablePath()
        
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        let length = hypot(dx, dy)
        
        guard length > 0 else { return path }
        
        let angle = atan2(dy, dx)
        let tailWidth = lineWidth
        
        let points: [CGPoint] = [
            CGPoint(x: 0, y: tailWidth / 2),
            CGPoint(x: length - headLength, y: tailWidth / 2),
            CGPoint(x: length - headLength, y: headWidth / 2),
            CGPoint(x: length, y: 0),
            CGPoint(x: length - headLength, y: -headWidth / 2),
            CGPoint(x: length - headLength, y: -tailWidth / 2),
            CGPoint(x: 0, y: -tailWidth / 2)
        ]
        
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: startPoint.x, y: startPoint.y)
        transform = transform.rotated(by: angle)
        
        path.move(to: points[0].applying(transform))
        for i in 1..<points.count {
            path.addLine(to: points[i].applying(transform))
        }
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Pen Annotation

/// 画笔标注（实心，普通混合模式）
final class PenAnnotation: Annotation {
    let id = UUID()
    let type: AnnotationType = .pen
    
    var points: [CGPoint]
    var color: NSColor
    var lineWidth: CGFloat
    
    init(points: [CGPoint] = [], color: NSColor = DesignTokens.Colors.NS.annotationPrimary, lineWidth: CGFloat = 3) {
        self.points = points
        self.color = color
        self.lineWidth = lineWidth
    }
    
    func addPoint(_ point: CGPoint) {
        points.append(point)
    }
    
    func draw(in context: CGContext) {
        guard points.count >= 2 else { return }
        
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        // 正常混合模式
        context.setBlendMode(.normal)
        
        context.move(to: points[0])
        for i in 1..<points.count {
            context.addLine(to: points[i])
        }
        context.strokePath()
        context.restoreGState()
    }
    
    func hitTest(point: CGPoint) -> Bool {
        for pointValue in points {
            let distance = hypot(pointValue.x - point.x, pointValue.y - point.y)
            if distance <= lineWidth / 2 + 5 {
                return true
            }
        }
        return false
    }
    
    func move(by delta: CGPoint) {
        points = points.map { CGPoint(x: $0.x + delta.x, y: $0.y + delta.y) }
    }
    
    func copy() -> Annotation {
        let pen = PenAnnotation(points: points, color: color, lineWidth: lineWidth)
        return pen
    }
}

// MARK: - Marker Annotation

/// 马克笔标注（荧光笔效果）
final class MarkerAnnotation: Annotation {
    let id = UUID()
    let type: AnnotationType = .marker
    
    var points: [CGPoint]
    var color: NSColor
    var lineWidth: CGFloat
    
    init(points: [CGPoint] = [], color: NSColor = DesignTokens.Colors.NS.annotationHighlight, lineWidth: CGFloat = 20) {
        self.points = points
        // 确保颜色有透明度
        self.color = color.alphaComponent < 1.0 ? color : color.withAlphaComponent(0.4)
        self.lineWidth = lineWidth
    }
    
    func addPoint(_ point: CGPoint) {
        points.append(point)
    }
    
    func draw(in context: CGContext) {
        guard points.count >= 2 else { return }
        
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setBlendMode(.multiply)
        
        context.move(to: points[0])
        for i in 1..<points.count {
            context.addLine(to: points[i])
        }
        context.strokePath()
        context.restoreGState()
    }
    
    func hitTest(point: CGPoint) -> Bool {
        for pointValue in points {
            let distance = hypot(pointValue.x - point.x, pointValue.y - point.y)
            if distance <= lineWidth / 2 + 5 {
                return true
            }
        }
        return false
    }
    
    func move(by delta: CGPoint) {
        points = points.map { CGPoint(x: $0.x + delta.x, y: $0.y + delta.y) }
    }
    
    func copy() -> Annotation {
        let marker = MarkerAnnotation(points: points, color: color, lineWidth: lineWidth)
        return marker
    }
}

// MARK: - Text Annotation

/// 文字标注
final class TextAnnotation: Annotation {
    let id = UUID()
    let type: AnnotationType = .text
    
    var position: CGPoint
    var text: String
    var color: NSColor
    var lineWidth: CGFloat
    var font: NSFont
    
    /// 最大宽度（nil 表示不限制）
    var maxWidth: CGFloat?
    
    /// 缓存的文字尺寸
    private var cachedSize: CGSize = .zero
    
    init(position: CGPoint, text: String = "", color: NSColor = DesignTokens.Colors.NS.annotationText, font: NSFont = .systemFont(ofSize: 16, weight: .medium)) {
        self.position = position
        self.text = text
        self.color = color
        self.lineWidth = 1
        self.font = font
        updateCachedSize()
    }
    
    func draw(in context: CGContext) {
        guard !text.isEmpty else { return }
        
        // 段落样式（支持换行）
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = maxWidth != nil ? .byWordWrapping : .byClipping
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext
        
        if let maxW = maxWidth {
            // 有宽度限制，使用 boundingRect 计算高度后绘制
            let attrString = NSAttributedString(string: text, attributes: attributes)
            let constraintSize = CGSize(width: maxW, height: CGFloat.greatestFiniteMagnitude)
            let boundingRect = attrString.boundingRect(with: constraintSize, options: [.usesLineFragmentOrigin, .usesFontLeading])
            
            // 使用 draw(at:) 逐行绘制（更可靠）
            let drawRect = CGRect(x: position.x, y: position.y, width: maxW, height: boundingRect.height)
            attrString.draw(in: drawRect)
        } else {
            // 无限制，单行绘制
            text.draw(at: position, withAttributes: attributes)
        }
        
        NSGraphicsContext.restoreGraphicsState()
        
        updateCachedSize()
    }
    
    func hitTest(point: CGPoint) -> Bool {
        let padding: CGFloat = 10
        let width = maxWidth ?? cachedSize.width
        let rect = CGRect(
            x: position.x - padding,
            y: position.y - padding,
            width: width + padding * 2,
            height: cachedSize.height + padding * 2
        )
        return rect.contains(point)
    }
    
    func move(by delta: CGPoint) {
        position.x += delta.x
        position.y += delta.y
    }
    
    func copy() -> Annotation {
        let textAnnotation = TextAnnotation(position: position, text: text, color: color, font: font)
        textAnnotation.maxWidth = maxWidth
        return textAnnotation
    }
    
    /// 获取文字边界矩形
    func boundingRect() -> CGRect {
        let width = maxWidth ?? cachedSize.width
        return CGRect(x: position.x, y: position.y, width: width, height: cachedSize.height)
    }
    
    private func updateCachedSize() {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = maxWidth != nil ? .byWordWrapping : .byClipping
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        
        if let maxW = maxWidth {
            let constraintRect = CGSize(width: maxW, height: CGFloat.greatestFiniteMagnitude)
            cachedSize = text.boundingRect(with: constraintRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes).size
        } else {
            cachedSize = text.size(withAttributes: attributes)
        }
    }
}
