import AppKit

// MARK: - Action Bar View (Pure AppKit)

/// 纯 AppKit 实现的操作条（无背景小按钮样式，类似系统 Live Text 按钮）
@MainActor
final class ActionBarView: NSView {
    
    // MARK: - Properties
    
    private let item: ScreenshotItem
    private let dependencies: ScreenshotActionDependencies
    private var actionButtons: [ActionBarButton] = []
    
    private let buttonSize: CGFloat = 24
    private let buttonSpacing: CGFloat = 2
    
    // MARK: - Init
    
    init(
        item: ScreenshotItem,
        dependencies: ScreenshotActionDependencies
    ) {
        self.item = item
        self.dependencies = dependencies
        super.init(frame: .zero)
        
        wantsLayer = true
        setupButtons()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    convenience init(item: ScreenshotItem) {
        self.init(item: item, dependencies: .live)
    }
    
    private func setupButtons() {
        // 右上角只放两个按钮：AI + Pin（OCR 单独在右下角）
        
        // Quick Ask 按钮 (AI)
        let quickAskButton = ActionBarButton(
            icon: "sparkles",
            activeColor: DesignTokens.Colors.NS.accentInfo
        ) { [weak self] in self?.openQuickAsk() }
        quickAskButton.toolTip = "Quick Ask"
        
        // Pin 按钮 (Cmd+P)
        let pinButton = ActionBarButton(
            icon: item.isPinned ? "pin.fill" : "pin",
            activeColor: DesignTokens.Colors.NS.warning,
            isActive: item.isPinned
        ) { [weak self] in self?.togglePin() }
        pinButton.toolTip = item.isPinned ? "Unpin (⌘P)" : "Pin to Space (⌘P)"
        
        actionButtons = [quickAskButton, pinButton]  // AI, Pin
        
        for (index, button) in actionButtons.enumerated() {
            button.frame = CGRect(
                x: CGFloat(index) * (buttonSize + buttonSpacing),
                y: 0,
                width: buttonSize,
                height: buttonSize
            )
            addSubview(button)
        }
    }
    
    // MARK: - Layout
    
    override var intrinsicContentSize: NSSize {
        let width = CGFloat(actionButtons.count) * buttonSize + CGFloat(actionButtons.count - 1) * buttonSpacing
        return NSSize(width: width, height: buttonSize)
    }
    
    // MARK: - Actions
    
    private func togglePin() {
        dependencies.togglePin(item)
        
        if let window = window as? ScreenshotWindow {
            window.updateCollectionBehavior()
        }
        refreshButtons()
    }
    
    private func toggleLock() {
        dependencies.toggleLock(item)
        
        if let window = window as? ScreenshotWindow {
            window.updateMovable()
        }
        refreshButtons()
    }
    
    private func copyImage(button: ActionBarButton) {
        // 通过 window 获取 ScreenshotContentView 的增强图片
        let enhancedImage = (window as? ScreenshotWindow)?.screenshotContentView?.getCurrentDisplayImage()
        dependencies.copyImage(item, enhancedImage)
        button.showFeedback()
    }
    
    private func performOCR(button: ActionBarButton) {
        guard let image = item.loadImage(),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }
        
        button.startSpinner()
        
        Task.detached {
            let text = await ScreenshotContentView.extractText(from: cgImage)
            await MainActor.run {
                button.stopSpinner()
                if !text.isEmpty {
                    self.dependencies.copyText(text)
                    button.showFeedback()
                }
            }
        }
    }
    
    private func openQuickAsk() {
        guard let image = item.loadImage() else { return }
        
        // 点击后短暂变色（AI 按钮是索引 0）
        actionButtons[0].flashActive()
        
        dependencies.startQuickAsk(image)
    }
    
    private func closeWindow() {
        dependencies.closeWindow(item)
    }
    
    func refreshButtons() {
        // 布局: AI(0), Pin(1)
        // 更新 Pin 按钮（索引 1）
        actionButtons[1].updateIcon(item.isPinned ? "pin.fill" : "pin")
        actionButtons[1].setActive(item.isPinned, animated: true)
        actionButtons[1].toolTip = item.isPinned ? "Unpin (⌘P)" : "Pin to Space (⌘P)"
        
        // 同步更新右键菜单
        if let contentView = superview as? ScreenshotContentView {
            contentView.refreshMenuItems()
        }
    }
}

// MARK: - Action Bar Button

/// 带 hover 和动画效果的操作按钮
final class ActionBarButton: NSView {
    
    // MARK: - Properties
    
    private let iconView: NSImageView
    private let backgroundView: NSView
    private var spinnerView: NSProgressIndicator?
    private var trackingArea: NSTrackingArea?
    
    private let defaultIcon: String
    private let feedbackIcon: String?
    private let activeColor: NSColor
    private let showSpinnerOnAction: Bool
    private var isActive: Bool = false
    private var isHovered: Bool = false
    
    private var actionHandler: ((ActionBarButton) -> Void)?
    private var simpleActionHandler: (() -> Void)?
    
    private let animationDuration: TimeInterval = 0.25
    
    // MARK: - Init
    
    init(icon: String, activeColor: NSColor = DesignTokens.Colors.NS.textPrimary, feedbackIcon: String? = nil, showSpinner: Bool = false, isActive: Bool = false, action: @escaping () -> Void) {
        self.defaultIcon = icon
        self.feedbackIcon = feedbackIcon
        self.activeColor = activeColor
        self.showSpinnerOnAction = showSpinner
        self.isActive = isActive
        self.simpleActionHandler = action
        
        self.iconView = NSImageView()
        self.backgroundView = NSView()
        
        super.init(frame: .zero)
        setup()
    }
    
    init(icon: String, activeColor: NSColor = DesignTokens.Colors.NS.textPrimary, feedbackIcon: String? = nil, showSpinner: Bool = false, isActive: Bool = false, action: @escaping (ActionBarButton) -> Void) {
        self.defaultIcon = icon
        self.feedbackIcon = feedbackIcon
        self.activeColor = activeColor
        self.showSpinnerOnAction = showSpinner
        self.isActive = isActive
        self.actionHandler = action
        
        self.iconView = NSImageView()
        self.backgroundView = NSView()
        
        super.init(frame: .zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setup() {
        wantsLayer = true
        
        // 背景（默认显示半透明，hover 时更亮）
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 6  // 小圆角正方形
        backgroundView.layer?.backgroundColor = DesignTokens.Colors.NS.overlayBase.cgColor
        backgroundView.alphaValue = 1  // 默认显示，确保可见度
        addSubview(backgroundView)
        
        // 图标
        iconView.imageScaling = .scaleProportionallyDown
        iconView.image = NSImage(systemSymbolName: defaultIcon, accessibilityDescription: nil)
        iconView.contentTintColor = isActive ? activeColor : DesignTokens.Colors.NS.textPrimary
        iconView.wantsLayer = true
        iconView.layer?.zPosition = 10 // 确保在最上层
        addSubview(iconView)
        
        // Spinner（可选）
        if showSpinnerOnAction {
            let spinner = NSProgressIndicator()
            spinner.style = .spinning
            spinner.isIndeterminate = true
            spinner.controlSize = .small
            spinner.isHidden = true
            addSubview(spinner)
            self.spinnerView = spinner
        }
    }
    
    // MARK: - Layout
    
    override func layout() {
        super.layout()
        backgroundView.frame = bounds
        iconView.frame = bounds.insetBy(dx: 4, dy: 4)
        spinnerView?.frame = bounds.insetBy(dx: 6, dy: 6)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // 只在 trackingArea 为空或 bounds 变化时重建
        if let existing = trackingArea {
            if existing.rect == bounds { return }
            removeTrackingArea(existing)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    // MARK: - Mouse Events
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovered = true
        updateHoverState(animated: true)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        
        // 安全检查：如果鼠标实际上还在视图范围内（包括在子视图如 ActionBar 上），就不视为离开
        // 这能修复从按钮移出时 ActionBar 意外消失的问题
        let location = convert(event.locationInWindow, from: nil)
        if bounds.contains(location) {
            return
        }
        
        isHovered = false
        updateHoverState(animated: true)
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // 按下时背景更亮
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            backgroundView.animator().layer?.backgroundColor = DesignTokens.Colors.NS.buttonPressed.cgColor
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        
        // 恢复 hover 状态
        updateHoverState(animated: true)
        
        // 检查是否在按钮范围内
        let location = convert(event.locationInWindow, from: nil)
        if bounds.contains(location) {
            if let handler = actionHandler {
                handler(self)
            } else {
                simpleActionHandler?()
            }
        }
    }
    
    private func updateHoverState(animated: Bool) {
        // 默认半透明黑色，hover 时更深（增加对比度）
        let bgColor = isHovered
            ? DesignTokens.Colors.NS.overlayStrong.cgColor  // Hover: 深黑 (0.8)
            : DesignTokens.Colors.NS.overlayBase.cgColor  // Normal: 半透黑 (0.5)
        
        // 确保图标颜色正确（非 active 时始终为白色）
        let iconColor = isActive ? activeColor : DesignTokens.Colors.NS.textPrimary
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                backgroundView.animator().layer?.backgroundColor = bgColor
                iconView.animator().contentTintColor = iconColor
            }
        } else {
            backgroundView.layer?.backgroundColor = bgColor
            iconView.contentTintColor = iconColor
        }
    }
    
    // MARK: - Public
    
    func updateIcon(_ icon: String) {
        // 确保使用 template image 以便支持着色
        let image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        image?.isTemplate = true
        iconView.image = image
    }
    
    func setActive(_ active: Bool, animated: Bool) {
        isActive = active
        // 触发状态更新以应用颜色
        updateHoverState(animated: animated)
    }
    
    func flashActive() {
        // 短暂变色后恢复
        NSAnimationContext.runAnimationGroup { context in
            context.duration = animationDuration
            iconView.animator().contentTintColor = activeColor
        } completionHandler: {
            MainActor.assumeIsolated {
                self.updateHoverState(animated: true)
            }
        }
    }
    
    func startSpinner() {
        iconView.isHidden = true
        spinnerView?.isHidden = false
        spinnerView?.startAnimation(nil)
    }
    
    func stopSpinner() {
        spinnerView?.stopAnimation(nil)
        spinnerView?.isHidden = true
        iconView.isHidden = false
    }
    
    func showFeedback() {
        guard let feedbackIcon = feedbackIcon else { return }
        
        // 切换到反馈图标
        let originalIcon = iconView.image
        iconView.image = NSImage(systemSymbolName: feedbackIcon, accessibilityDescription: nil)
        iconView.contentTintColor = .green
        
        // 1.5秒后恢复
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            self.iconView.image = originalIcon
            // 恢复 hover 状态（会自动设置正确的颜色）
            self.updateHoverState(animated: true)
        }
    }
}
