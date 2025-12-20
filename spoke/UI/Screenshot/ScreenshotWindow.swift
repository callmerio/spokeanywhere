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
    
    
    /// 当前是否 hover 状态
    private(set) var isHovered: Bool = false
    
    // MARK: - Override
    
    /// 允许窗口成为 key window，以支持 Live Text 的键盘快捷键（如 Cmd+C）
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    /// 处理键盘快捷键（Cmd+C 复制 Live Text 选中文本）
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "c" {
            // Live Text Copy (Cmd+C)
            if screenshotContentView != nil, #available(macOS 13.0, *) {
                // 尝试让 Live Text 处理复制（选中状态）
                if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self) {
                    return true
                }
            }
        }
        return super.performKeyEquivalent(with: event)
    }
    
    override func keyDown(with event: NSEvent) {
        // 忽略带有修饰键的事件（除了 CapsLock和Function），交给系统/菜单处理
        let meaningfulModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
        if !event.modifierFlags.intersection(meaningfulModifiers).isEmpty {
            super.keyDown(with: event)
            return
        }
        
        guard let char = event.charactersIgnoringModifiers?.lowercased().first else {
            super.keyDown(with: event)
            return
        }
        
        // 单键快捷键映射
        switch char {
        case "p": // P -> Pin
            screenshotContentView?.performPinAction()
            
        case "m": // M -> Mark
            screenshotContentView?.performMarkAction()
            
        case "a": // A -> Ask (Quick Ask)
            screenshotContentView?.triggerQuickAsk()
            
        case "c": // C -> Copy Image
            ScreenshotManager.shared.copyToClipboard(item)
            // 可选：添加简单的视觉反馈（如闪烁一下）
            flashFeedback()
            
        case "t": // T -> Copy Text (Live Text / OCR)
            copyRecognizedText()
            
        case "q": // Q -> Quit/Close
            ScreenshotManager.shared.close(item)
            
        default:
            super.keyDown(with: event)
        }
    }
    
    private func copyRecognizedText() {
        // 尝试获取 Live Text 文本
        if let text = screenshotContentView?.getRecognizedText(), !text.isEmpty {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            flashFeedback()
        } else {
            // Fallback: 如果没有 Live Text，尝试触发 OCR (仅旧版需要，新版通常已经有了 Live Text)
            // 这里简单处理：如果拿不到就不复制，或者提示
            NSSound.beep()
        }
    }
    
    // 简单的视觉反馈
    private func flashFeedback() {
        guard let contentView = contentView else { return }
        let flash = NSView(frame: contentView.bounds)
        flash.wantsLayer = true
        flash.layer?.backgroundColor = NSColor.white.cgColor
        flash.alphaValue = 0.3
        contentView.addSubview(flash)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            flash.animator().alphaValue = 0
        } completionHandler: {
            flash.removeFromSuperview()
        }
    }
    
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
        // 禁用系统阴影，使用 ScreenshotContentView 内部的 glowLayer 实现自定义光晕
        // 避免系统阴影与自定义光晕冲突，且系统阴影无法调整颜色
        hasShadow = false
        animationBehavior = .utilityWindow
        hidesOnDeactivate = false
        
        // 初始状态：跟随所有 Space
        updateCollectionBehavior()
        
        // 统一设置窗口透明度（影响所有子视图：图片+光晕）
        alphaValue = item.opacity
        
        // 可拖动（除非 Locked）
        isMovableByWindowBackground = !item.isLocked
        
        // 🔑 使用纯 AppKit 内容视图，避免 NSHostingView 约束循环崩溃
        let contentView = ScreenshotContentView(item: item)
        contentView.autoresizingMask = [.width, .height]
        self.contentView = contentView
        self.screenshotContentView = contentView
        
        // 设置光晕层
        setupGlowLayer()
        
        // 设置 window 级别的 tracking area
        setupWindowTrackingArea()
        
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
        
        // 开启鼠标移动事件以检测 hover
        acceptsMouseMovedEvents = true
    }
    
    // MARK: - Mouse Tracking (Window 级别)
    
    private var windowTrackingArea: NSTrackingArea?
    
    private func setupWindowTrackingArea() {
        guard let cv = contentView else { return }
        
        // 移除旧的 tracking area
        if let existing = windowTrackingArea {
            cv.removeTrackingArea(existing)
        }
        
        // 创建新的 tracking area
        let trackingArea = NSTrackingArea(
            rect: cv.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        cv.addTrackingArea(trackingArea)
        windowTrackingArea = trackingArea
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateGlow(hovered: true)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateGlow(hovered: false)
    }
    
    
    // MARK: - Glow Effect
    
    private func setupGlowLayer() {
        // 光晕效果通过 screenshotContentView 的 imageView.layer 实现
        // 初始化光晕状态
        updateGlow()
    }
    
    /// 更新光晕效果
    /// - Parameter hovered: 是否 hover 状态（蓝色光晕）
    func updateGlow(hovered: Bool? = nil) {
        if let h = hovered {
            isHovered = h
        }
        
        // 通知 contentView 更新光晕
        screenshotContentView?.updateGlow(isHovered: isHovered, isMarked: item.isMarked)
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
        
        // 优先处理绝对值较大的方向
        if abs(deltaX) > abs(deltaY) {
            handleOpacityChange(with: event)
        } else {
            handleSizeChange(with: event)
        }
    }
    
    /// 处理透明度调整（双指左右滑动）
    private func handleOpacityChange(with event: NSEvent) {
        let deltaX = event.scrollingDeltaX
        
        // 阈值过滤，避免误触
        guard abs(deltaX) > 2 else { return }
        
        // 右滑(deltaX > 0) = 更不透明, 左滑(deltaX < 0) = 更透明
        // 灵敏度：0.003
        let opacityDelta = deltaX * 0.003
        let newOpacity = max(0.3, min(1.0, item.opacity + opacityDelta))
        
        item.opacity = newOpacity
        alphaValue = newOpacity
        
        // 移除 redundant 的 contentView 调用
        // screenshotContentView?.updateOpacity(newOpacity)
        
        ScreenshotManager.shared.saveAll()
    }
    
    /// 处理大小调整（双指上下滑动）
    private func handleSizeChange(with event: NSEvent) {
        let deltaY = event.scrollingDeltaY
        
        // 阈值过滤，避免误触
        guard abs(deltaY) > 2 else { return }
        
        // 上滑(deltaY > 0) = 放大, 下滑(deltaY < 0) = 缩小
        let scaleFactor = 1.0 + (deltaY * 0.003)
        
        // 考虑 padding (Window Padding = Content Padding * 2)
        let padding = ScreenshotContentView.paddingPerSide * 2
        
        // 计算当前内容尺寸
        let currentContentWidth = max(1, frame.width - padding)
        
        // 基于内容尺寸缩放
        let newContentWidth = currentContentWidth * scaleFactor
        
        // 保持原始图片宽高比
        let aspectRatio = item.originalSize.width / item.originalSize.height
        let newContentHeight = newContentWidth / aspectRatio
        
        // 加上 padding 得到新的窗口尺寸
        var newWidth = newContentWidth + padding
        var newHeight = newContentHeight + padding
        
        // 限制大小范围
        // 最小尺寸 = padding + 最小内容尺寸(40)
        let minDim: CGFloat = padding + 40
        let maxDim: CGFloat = 3000 // 最大限制
        
        let currentMin = min(frame.width, frame.height)
        let currentMax = max(frame.width, frame.height)
        
        // 边界检查：已经达到极限则不再处理
        if deltaY < 0 && currentMin <= minDim { return }
        if deltaY > 0 && currentMax >= maxDim { return }
        
        // 应用尺寸限制并重新计算宽高以保持比例
        if newWidth < minDim {
            newWidth = minDim
            let contentW = newWidth - padding
            newHeight = (contentW / aspectRatio) + padding
        } else if newWidth > maxDim {
            newWidth = maxDim
            let contentW = newWidth - padding
            newHeight = (contentW / aspectRatio) + padding
        }
        
        // 高度检查（虽然宽度限制通常足够，但为了保险起见）
        if newHeight < minDim {
            newHeight = minDim
            let contentH = newHeight - padding
            newWidth = (contentH * aspectRatio) + padding
        } else if newHeight > maxDim {
            newHeight = maxDim
            let contentH = newHeight - padding
            newWidth = (contentH * aspectRatio) + padding
        }
        
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
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
