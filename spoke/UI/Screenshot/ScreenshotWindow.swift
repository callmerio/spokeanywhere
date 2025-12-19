import AppKit

// MARK: - Screenshot Window

/// 截图窗口
/// 不抢夺焦点的悬浮窗口，支持 Pin to Space
/// 使用纯 AppKit 实现避免 NSHostingView 约束循环问题
final class ScreenshotWindow: NSPanel {
    
    // MARK: - Properties
    
    let item: ScreenshotItem
    
    /// 窗口移动回调
    var onFrameChanged: ((CGRect) -> Void)?
    
    /// 内容视图（纯 AppKit）
    private var screenshotContentView: ScreenshotContentView?
    
    // MARK: - Override
    
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    
    // MARK: - Init
    
    init(item: ScreenshotItem) {
        self.item = item
        
        super.init(
            contentRect: item.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        configure()
    }
    
    // MARK: - Configuration
    
    private func configure() {
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        animationBehavior = .utilityWindow
        hidesOnDeactivate = false
        
        // 初始状态：跟随所有 Space
        updateCollectionBehavior()
        
        // 可拖动（除非 Locked）
        isMovableByWindowBackground = !item.isLocked
        
        // 🔑 使用纯 AppKit 内容视图，避免 NSHostingView 约束循环崩溃
        let contentView = ScreenshotContentView(item: item)
        contentView.autoresizingMask = [.width, .height]
        self.contentView = contentView
        self.screenshotContentView = contentView
        
        // 监听窗口移动
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: self
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResize),
            name: NSWindow.didResizeNotification,
            object: self
        )
    }
    
    // MARK: - Public
    
    /// 更新 collectionBehavior（Pin/Unpin 切换时调用）
    func updateCollectionBehavior() {
        if item.isPinned {
            collectionBehavior = []
        } else {
            collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        }
    }
    
    /// 更新可拖动状态（Lock/Unlock 切换时调用）
    func updateMovable() {
        isMovableByWindowBackground = !item.isLocked
    }
    
    // MARK: - Notifications
    
    @objc private func windowDidMove(_ notification: Notification) {
        onFrameChanged?(frame)
    }
    
    @objc private func windowDidResize(_ notification: Notification) {
        onFrameChanged?(frame)
    }
    
    // MARK: - Scroll Wheel (双指手势)
    
    /// 双指左右滑动：调整透明度
    /// 双指上下滑动：调整大小
    override func scrollWheel(with event: NSEvent) {
        // 只在 Pinned 状态下响应
        guard item.isPinned else {
            super.scrollWheel(with: event)
            return
        }
        
        let deltaX = event.scrollingDeltaX
        let deltaY = event.scrollingDeltaY
        
        // 透明度调整（左右滑动）
        // 右滑(deltaX > 0) = 更不透明, 左滑(deltaX < 0) = 更透明
        // 灵敏度降低：0.01 → 0.003，最低透明度 20% → 30%
        if abs(deltaX) > abs(deltaY) && abs(deltaX) > 2 {
            let opacityDelta = deltaX * 0.003
            let newOpacity = max(0.3, min(1.0, item.opacity + opacityDelta))
            item.opacity = newOpacity
            alphaValue = newOpacity
            screenshotContentView?.updateOpacity(newOpacity)
            ScreenshotManager.shared.saveAll()
        }
        
        // 大小调整（上下滑动）- 保持宽高比
        // 上滑(deltaY > 0) = 放大, 下滑(deltaY < 0) = 缩小
        // 锚点根据 hover 位置动态选择：左1/4→左锚点，中间1/2→中心锚点，右1/4→右锚点
        if abs(deltaY) > abs(deltaX) && abs(deltaY) > 2 {
            let scaleFactor = 1.0 + (deltaY * 0.003)
            
            // 保持原始宽高比缩放
            let aspectRatio = item.originalSize.width / item.originalSize.height
            var newWidth = frame.width * scaleFactor
            var newHeight = newWidth / aspectRatio
            
            // 限制大小范围 (40 ~ 2000)
            let minDim: CGFloat = 40
            let maxDim: CGFloat = 2000
            
            // 检查是否已达到限制，避免无效 setFrame 导致位置漂移
            let currentMin = min(frame.width, frame.height)
            let currentMax = max(frame.width, frame.height)
            if deltaY < 0 && currentMin <= minDim { return }  // 已经最小，不能再缩小
            if deltaY > 0 && currentMax >= maxDim { return }  // 已经最大，不能再放大
            
            // 应用尺寸限制
            if newWidth < minDim { newWidth = minDim; newHeight = newWidth / aspectRatio }
            if newHeight < minDim { newHeight = minDim; newWidth = newHeight * aspectRatio }
            if newWidth > maxDim { newWidth = maxDim; newHeight = newWidth / aspectRatio }
            if newHeight > maxDim { newHeight = maxDim; newWidth = newHeight * aspectRatio }
            
            // 根据 hover 位置选择缩放锚点
            let mouseLocationInWindow = event.locationInWindow
            let relativeX = mouseLocationInWindow.x / frame.width
            
            let newX: CGFloat
            let newY = frame.midY - newHeight / 2  // Y 轴始终中心缩放
            
            if relativeX < 0.25 {
                // 左 1/4：左边锚点（左边位置不变）
                newX = frame.minX
            } else if relativeX > 0.75 {
                // 右 1/4：右边锚点（右边位置不变）
                newX = frame.maxX - newWidth
            } else {
                // 中间 1/2：中心锚点
                newX = frame.midX - newWidth / 2
            }
            
            let newFrame = CGRect(x: newX, y: newY, width: newWidth, height: newHeight)
            
            setFrame(newFrame, display: true, animate: false)
            item.frame = newFrame
            ScreenshotManager.shared.saveAll()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
