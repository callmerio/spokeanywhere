import AppKit

// MARK: - Screenshot Window

/// 截图窗口
/// 不抢夺焦点的悬浮窗口，支持 Pin to Space
/// 使用纯 AppKit 实现避免 NSHostingView 约束循环问题
final class ScreenshotWindow: NSPanel {
    
    // MARK: - Properties
    
    let item: ScreenshotItem
    private let dependencies: ScreenshotActionDependencies
    
    /// 窗口移动回调
    var onFrameChanged: ((CGRect) -> Void)?
    
    /// 内容视图（纯 AppKit）
    private(set) var screenshotContentView: ScreenshotContentView?
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
        if !event.modifierFlags.isDisjoint(with: meaningfulModifiers) {
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
            dependencies.copyImage(item, screenshotContentView?.getCurrentDisplayImage())
            // 可选：添加简单的视觉反馈（如闪烁一下）
            flashFeedback()
            
        case "t": // T -> Copy Text (Live Text / OCR)
            copyRecognizedText()
            
        case "q": // Q -> Quit/Close
            dependencies.closeWindow(item)
            
        default:
            super.keyDown(with: event)
        }
    }
    
    private func copyRecognizedText() {
        // 尝试获取 Live Text 文本
        if let text = screenshotContentView?.getRecognizedText(), !text.isEmpty {
            dependencies.copyText(text)
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
        flash.layer?.backgroundColor = DesignTokens.Colors.NS.inkLight.cgColor
        flash.alphaValue = 0.3
        contentView.addSubview(flash)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            flash.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated {
                flash.removeFromSuperview()
            }
        }
    }
    
    // MARK: - Init
    
    init(
        item: ScreenshotItem,
        dependencies: ScreenshotActionDependencies
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

    @MainActor
    convenience init(item: ScreenshotItem) {
        self.init(item: item, dependencies: .live)
    }
    
    // MARK: - Configuration
    
    private func configure() {
        identifier = NSUserInterfaceItemIdentifier(UITestIdentifiers.Window.screenshot)
        setAccessibilityIdentifier(UITestIdentifiers.Window.screenshot)
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
        let contentView = ScreenshotContentView(item: item, dependencies: dependencies)
        contentView.identifier = NSUserInterfaceItemIdentifier(UITestIdentifiers.Element.screenshotContent)
        contentView.setAccessibilityIdentifier(UITestIdentifiers.Element.screenshotContent)
        contentView.autoresizingMask = [.width, .height]
        self.contentView = contentView
        self.screenshotContentView = contentView
        
        // 设置光晕层
        setupGlowLayer()
        
        // Window 级别 tracking area 已移除，由 ContentView 接管
        
        // 监听窗口移动
        dependencies.notificationCenter.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: self
        )
        
        dependencies.notificationCenter.addObserver(
            self,
            selector: #selector(windowDidResize),
            name: NSWindow.didResizeNotification,
            object: self
        )
        
        // 开启鼠标移动事件以检测 hover
        acceptsMouseMovedEvents = true
    }
    
    // MARK: - Mouse Tracking (Window 级别 - 已移除，统一由 ContentView 管理)
    
    // 移除 Window 级别的 TrackingArea，避免与 ContentView 的逻辑冲突（Duplicate Source of Truth）
    // 参考: ContentView 已经实现了完善的 bounds 检查和防抖逻辑

    // MARK: - Glow Effect
    
    private func setupGlowLayer() {
        // 光晕效果通过 screenshotContentView 的 imageView.layer 实现
        // 初始化光晕状态
        updateGlow()
    }
    
    /// 更新光晕效果
    /// - Parameter hovered: 是否 hover 状态（蓝色光晕）
    func updateGlow(hovered: Bool? = nil) {
        if let hoveredValue = hovered {
            isHovered = hoveredValue
        }
        
        // 通知 contentView 更新光晕（传入 isPinned 以支持 Pin 状态的黑色光晕）
        screenshotContentView?.updateGlow(isHovered: isHovered, isMarked: item.isMarked, isPinned: item.isPinned)
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
    // MARK: - Scroll Wheel (双指手势 / 鼠标滚轮)
    
    /// 用于锁定当前滚动也就是是否为透明度模式
    /// 一旦在滚动过程中按下了 Shift，该次滚动余下的部分将一直保持为透明度调整，防止回跳
    private var isOpacityScrollLocked: Bool = false
    
    /// 调整大小和透明度的统一入口
    override func scrollWheel(with event: NSEvent) {
        // 1. 手势生命周期管理
        if event.phase == .began {
            // 新手势开始，重置锁定状态
            // 但如果一开始就按着 Shift，直接锁定
            isOpacityScrollLocked = event.modifierFlags.contains(.shift)
        } else if event.phase == .changed || event.phase == [] {
            // 手势进行中：如果检测到 Shift 按下，立即“升级”并锁定为透明度模式
            if event.modifierFlags.contains(.shift) {
                isOpacityScrollLocked = true
            }
        }
        
        // 2. 状态重置 (手势结束或取消)
        if event.phase == .ended || event.phase == .cancelled {
            isOpacityScrollLocked = false
            // 惯性阶段如果需要也可以在此处理，通常此处重置即可
        }
        
        // 3. 执行逻辑分发
        // 只要被锁定 (isOpacityScrollLocked)，或者当前正按着 Shift，就强制走透明度逻辑
        if isOpacityScrollLocked || event.modifierFlags.contains(.shift) {
            
            // --- 透明度模式 (锁定或 Shift 按下) ---
            let deltaY = event.scrollingDeltaY
            
            let sensitivity: CGFloat = event.hasPreciseScrollingDeltas ? 0.003 : 0.05
            let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 1.0 : 0.0
            
            if abs(deltaY) > threshold {
                // 向上(正) = 增加不透明度, 向下(负) = 减少不透明度
                handleOpacityChange(delta: deltaY, sensitivity: sensitivity)
            }
            return
        }
        
        // --- 默认模式 (无 Shift 且 未锁定) ---
        if event.hasPreciseScrollingDeltas {
            // [触控板]
            // 左右滑 -> 透明度
            // 上下滑 -> 大小
            
            let deltaX = event.scrollingDeltaX
            let deltaY = event.scrollingDeltaY
            
            if abs(deltaX) > abs(deltaY) {
                // 横向主导 -> 透明度
                if abs(deltaX) > 1 {
                    handleOpacityChange(delta: deltaX, sensitivity: 0.003)
                }
            } else {
                // 纵向主导 -> 大小
                if abs(deltaY) > 1 {
                    handleSizeChange(delta: deltaY, sensitivity: 0.003, event: event)
                }
            }
        } else {
            // [鼠标滚轮]
            // 默认 -> 大小
            handleSizeChange(delta: event.scrollingDeltaY, sensitivity: 0.05, event: event)
        }
    }
    
    /// 处理透明度调整
    private func handleOpacityChange(delta: CGFloat, sensitivity: CGFloat) {
        // Delta > 0 = 更不透明, Delta < 0 = 更透明
        let opacityDelta = delta * sensitivity
        let newOpacity = max(0.3, min(1.0, item.opacity + opacityDelta))
        
        // 只有变化时才更新，减少开销
        if abs(item.opacity - newOpacity) > 0.001 {
            item.opacity = newOpacity
            alphaValue = newOpacity
            dependencies.saveWindowState()
        }
    }
    
    /// 处理大小调整
    /// 处理大小调整
    private func handleSizeChange(delta: CGFloat, sensitivity: CGFloat, event: NSEvent) {
        // Delta > 0 = 放大, Delta < 0 = 缩小
        let scaleFactor = 1.0 + (delta * sensitivity)
        
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
        if delta < 0 && currentMin <= minDim { return }
        if delta > 0 && currentMax >= maxDim { return }
        
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
        
        // 高度检查
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
        dependencies.saveWindowState()
        
        // 触发图片增强（带防抖）
        // 传递内容区域尺寸（不含 glow padding）
        let contentPadding = ScreenshotContentView.paddingPerSide * 2
        let contentSize = CGSize(width: newWidth - contentPadding, height: newHeight - contentPadding)
        (contentView as? ScreenshotContentView)?.updateImageQuality(targetSize: contentSize)
    }
    
    deinit {
        dependencies.notificationCenter.removeObserver(self)
    }
}
