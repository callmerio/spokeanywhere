import AppKit

// MARK: - Screenshot Content View (Pure AppKit)

/// 纯 AppKit 实现的截图内容视图
/// 避免 NSHostingView 的约束循环问题
final class ScreenshotContentView: NSView {
    
    // MARK: - Properties
    
    let item: ScreenshotItem
    private let imageView: NSImageView
    private var actionBar: ActionBarView?
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var hideActionBarWorkItem: DispatchWorkItem?
    
    /// ActionBar 最小宽度（小于此宽度时隐藏）
    private let actionBarMinWidth: CGFloat = 200
    
    // MARK: - Init
    
    init(item: ScreenshotItem) {
        self.item = item
        self.imageView = NSImageView()
        
        super.init(frame: .zero)
        
        setupImageView()
        setupActionBar()
        setupContextMenu()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupImageView() {
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 8
        imageView.layer?.masksToBounds = true
        
        // 加载图片
        if let image = item.loadImage() {
            imageView.image = image
        }
        
        // 设置透明度
        imageView.alphaValue = item.opacity
        
        addSubview(imageView)
    }
    
    private func setupActionBar() {
        let bar = ActionBarView(item: item)
        bar.isHidden = true  // 初始隐藏
        bar.alphaValue = 0
        addSubview(bar)
        self.actionBar = bar
    }
    
    private func setupContextMenu() {
        let menu = NSMenu()
        
        // Pin/Unpin
        let pinItem = NSMenuItem(
            title: item.isPinned ? "Unpin" : "Pin to Space",
            action: #selector(togglePin),
            keyEquivalent: ""
        )
        pinItem.image = NSImage(systemSymbolName: item.isPinned ? "pin.slash" : "pin", accessibilityDescription: nil)
        pinItem.target = self
        menu.addItem(pinItem)
        
        // Lock/Unlock
        let lockItem = NSMenuItem(
            title: item.isLocked ? "Unlock" : "Lock",
            action: #selector(toggleLock),
            keyEquivalent: ""
        )
        lockItem.image = NSImage(systemSymbolName: item.isLocked ? "lock.open" : "lock", accessibilityDescription: nil)
        lockItem.target = self
        menu.addItem(lockItem)
        
        menu.addItem(.separator())
        
        // Copy
        let copyItem = NSMenuItem(title: "Copy Image", action: #selector(copyImage), keyEquivalent: "c")
        copyItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        copyItem.target = self
        menu.addItem(copyItem)
        
        // OCR
        let ocrItem = NSMenuItem(title: "OCR", action: #selector(performOCR), keyEquivalent: "")
        ocrItem.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: nil)
        ocrItem.target = self
        menu.addItem(ocrItem)
        
        // Quick Ask
        let quickAskItem = NSMenuItem(title: "Quick Ask", action: #selector(openQuickAsk), keyEquivalent: "")
        quickAskItem.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
        quickAskItem.target = self
        menu.addItem(quickAskItem)
        
        menu.addItem(.separator())
        
        // Close
        let closeItem = NSMenuItem(title: "Close", action: #selector(closeWindow), keyEquivalent: "w")
        closeItem.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: nil)
        closeItem.target = self
        menu.addItem(closeItem)
        
        self.menu = menu
    }
    
    // MARK: - Layout
    
    override func layout() {
        super.layout()
        imageView.frame = bounds
        
        // ActionBar 布局（底部居中）
        if let bar = actionBar {
            let barSize = bar.intrinsicContentSize
            bar.frame = CGRect(
                x: (bounds.width - barSize.width) / 2,
                y: 12,  // 距离底部 12pt
                width: barSize.width,
                height: barSize.height
            )
        }
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // 只在 trackingArea 为空或 bounds 变化时重建，减少不必要的重建
        if let existing = trackingArea {
            if existing.rect == bounds { return }
            removeTrackingArea(existing)
        }
        
        // 使用 inVisibleRect 自动跟随可见区域
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
        // 取消待执行的隐藏
        hideActionBarWorkItem?.cancel()
        hideActionBarWorkItem = nil
        
        isHovered = true
        updateActionBarVisibility(animated: true)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        
        // 防抖：延迟隐藏，避免闪烁
        hideActionBarWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.isHovered = false
            self.updateActionBarVisibility(animated: true)
        }
        hideActionBarWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }
    
    // MARK: - Drag Support
    
    override func mouseDown(with event: NSEvent) {
        // 检查点击位置是否在 ActionBar 上
        if let bar = actionBar, !bar.isHidden {
            let locationInBar = bar.convert(event.locationInWindow, from: nil)
            if bar.bounds.contains(locationInBar) {
                // 点击在 ActionBar 上，交给子视图处理
                super.mouseDown(with: event)
                return
            }
        }
        
        // 未锁定时支持拖动窗口
        if !item.isLocked {
            window?.performDrag(with: event)
        } else {
            super.mouseDown(with: event)
        }
    }
    
    private func updateActionBarVisibility(animated: Bool) {
        guard let bar = actionBar else { return }
        
        // 宽度不足时始终隐藏
        let shouldShow = isHovered && bounds.width >= actionBarMinWidth
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                bar.animator().alphaValue = shouldShow ? 1 : 0
            } completionHandler: {
                bar.isHidden = !shouldShow
            }
        } else {
            bar.alphaValue = shouldShow ? 1 : 0
            bar.isHidden = !shouldShow
        }
    }
    
    // MARK: - Drawing
    
    override var wantsUpdateLayer: Bool { true }
    
    override func updateLayer() {
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        
        // 阴影
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.3
        layer?.shadowOffset = CGSize(width: 0, height: -4)
        layer?.shadowRadius = 8
    }
    
    // MARK: - Update
    
    func updateOpacity(_ opacity: Double) {
        imageView.alphaValue = opacity
    }
    
    func refreshMenuItems() {
        setupContextMenu()
    }
    
    // MARK: - Actions
    
    @objc private func togglePin() {
        if item.isPinned {
            ScreenshotManager.shared.unpin(item)
        } else {
            ScreenshotManager.shared.pin(item)
        }
        
        if let window = window as? ScreenshotWindow {
            window.updateCollectionBehavior()
        }
        refreshMenuItems()
    }
    
    @objc private func toggleLock() {
        if item.isLocked {
            ScreenshotManager.shared.unlock(item)
        } else {
            ScreenshotManager.shared.lock(item)
        }
        
        if let window = window as? ScreenshotWindow {
            window.updateMovable()
        }
        refreshMenuItems()
    }
    
    @objc private func copyImage() {
        ScreenshotManager.shared.copyToClipboard(item)
    }
    
    @objc private func performOCR() {
        guard let image = item.loadImage(),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }
        
        Task.detached {
            let text = await Self.extractText(from: cgImage)
            await MainActor.run {
                if !text.isEmpty {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(text, forType: .string)
                }
            }
        }
    }
    
    static func extractText(from image: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
            
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try? handler.perform([request])
        }
    }
    
    @objc private func openQuickAsk() {
        guard let image = item.loadImage() else { return }
        
        QuickAskService.shared.startSession()
        QuickAskService.shared.state.addScreenshot(image)
    }
    
    @objc private func closeWindow() {
        ScreenshotManager.shared.close(item)
    }
}

// MARK: - Vision Import

import Vision

// MARK: - Action Bar View (Pure AppKit)

/// 纯 AppKit 实现的操作条
final class ActionBarView: NSView {
    
    // MARK: - Properties
    
    private let item: ScreenshotItem
    private var actionButtons: [ActionBarButton] = []
    
    private let buttonSize: CGFloat = 28
    private let buttonSpacing: CGFloat = 4
    private let padding: CGFloat = 12
    private let barHeight: CGFloat = 44
    
    // MARK: - Init
    
    init(item: ScreenshotItem) {
        self.item = item
        super.init(frame: .zero)
        
        wantsLayer = true
        setupAppearance()
        setupButtons()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupAppearance() {
        layer?.cornerRadius = barHeight / 2
        layer?.masksToBounds = true
        
        // 毛玻璃效果
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = barHeight / 2
        visualEffect.autoresizingMask = [.width, .height]
        addSubview(visualEffect)
    }
    
    private func setupButtons() {
        // Pin 按钮
        let pinButton = ActionBarButton(
            icon: item.isPinned ? "pin.fill" : "pin",
            activeColor: .orange,
            isActive: item.isPinned
        ) { [weak self] in self?.togglePin() }
        pinButton.toolTip = item.isPinned ? "Unpin" : "Pin to Space"
        
        // Lock 按钮
        let lockButton = ActionBarButton(
            icon: item.isLocked ? "lock.fill" : "lock",
            activeColor: .systemBlue,
            isActive: item.isLocked
        ) { [weak self] in self?.toggleLock() }
        lockButton.toolTip = item.isLocked ? "Unlock" : "Lock"
        
        // Copy 按钮
        let copyButton = ActionBarButton(
            icon: "doc.on.doc",
            feedbackIcon: "checkmark"
        ) { [weak self] button in self?.copyImage(button: button) }
        copyButton.toolTip = "Copy Image"
        
        // OCR 按钮
        let ocrButton = ActionBarButton(
            icon: "text.viewfinder",
            feedbackIcon: "checkmark",
            showSpinner: true
        ) { [weak self] button in self?.performOCR(button: button) }
        ocrButton.toolTip = "OCR"
        
        // Quick Ask 按钮
        let quickAskButton = ActionBarButton(
            icon: "sparkles",
            activeColor: .systemBlue
        ) { [weak self] in self?.openQuickAsk() }
        quickAskButton.toolTip = "Quick Ask"
        
        // Close 按钮
        let closeButton = ActionBarButton(
            icon: "xmark",
            activeColor: .systemRed
        ) { [weak self] in self?.closeWindow() }
        closeButton.toolTip = "Close"
        
        actionButtons = [pinButton, lockButton, copyButton, ocrButton, quickAskButton, closeButton]
        
        for (index, button) in actionButtons.enumerated() {
            button.frame = CGRect(
                x: padding + CGFloat(index) * (buttonSize + buttonSpacing),
                y: (barHeight - buttonSize) / 2,
                width: buttonSize,
                height: buttonSize
            )
            addSubview(button)
        }
    }
    
    // MARK: - Layout
    
    override var intrinsicContentSize: NSSize {
        let width = padding * 2 + CGFloat(actionButtons.count) * buttonSize + CGFloat(actionButtons.count - 1) * buttonSpacing
        return NSSize(width: width, height: barHeight)
    }
    
    // MARK: - Actions
    
    private func togglePin() {
        if item.isPinned {
            ScreenshotManager.shared.unpin(item)
        } else {
            ScreenshotManager.shared.pin(item)
        }
        
        if let window = window as? ScreenshotWindow {
            window.updateCollectionBehavior()
        }
        refreshButtons()
    }
    
    private func toggleLock() {
        if item.isLocked {
            ScreenshotManager.shared.unlock(item)
        } else {
            ScreenshotManager.shared.lock(item)
        }
        
        if let window = window as? ScreenshotWindow {
            window.updateMovable()
        }
        refreshButtons()
    }
    
    private func copyImage(button: ActionBarButton) {
        ScreenshotManager.shared.copyToClipboard(item)
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
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(text, forType: .string)
                    button.showFeedback()
                }
            }
        }
    }
    
    private func openQuickAsk() {
        guard let image = item.loadImage() else { return }
        
        // 点击后短暂变色
        actionButtons[4].flashActive()
        
        QuickAskService.shared.startSession()
        QuickAskService.shared.state.addScreenshot(image)
    }
    
    private func closeWindow() {
        ScreenshotManager.shared.close(item)
    }
    
    private func refreshButtons() {
        // 更新 Pin 按钮
        actionButtons[0].updateIcon(item.isPinned ? "pin.fill" : "pin")
        actionButtons[0].setActive(item.isPinned, animated: true)
        actionButtons[0].toolTip = item.isPinned ? "Unpin" : "Pin to Space"
        
        // 更新 Lock 按钮
        actionButtons[1].updateIcon(item.isLocked ? "lock.fill" : "lock")
        actionButtons[1].setActive(item.isLocked, animated: true)
        actionButtons[1].toolTip = item.isLocked ? "Unlock" : "Lock"
        
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
    
    init(icon: String, activeColor: NSColor = .white, feedbackIcon: String? = nil, showSpinner: Bool = false, isActive: Bool = false, action: @escaping () -> Void) {
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
    
    init(icon: String, activeColor: NSColor = .white, feedbackIcon: String? = nil, showSpinner: Bool = false, isActive: Bool = false, action: @escaping (ActionBarButton) -> Void) {
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
        
        // 背景（hover 时显示）
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 6  // 小圆角正方形
        backgroundView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
        backgroundView.alphaValue = 0
        addSubview(backgroundView)
        
        // 图标
        iconView.imageScaling = .scaleProportionallyDown
        iconView.image = NSImage(systemSymbolName: defaultIcon, accessibilityDescription: nil)
        iconView.contentTintColor = isActive ? activeColor : .white
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
        isHovered = false
        updateHoverState(animated: true)
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // 按下时背景更亮
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            backgroundView.animator().layer?.backgroundColor = NSColor.white.withAlphaComponent(0.3).cgColor
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
        let targetAlpha: CGFloat = isHovered ? 1 : 0
        let bgColor = NSColor.white.withAlphaComponent(0.15).cgColor
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                backgroundView.animator().alphaValue = targetAlpha
                backgroundView.animator().layer?.backgroundColor = bgColor
            }
        } else {
            backgroundView.alphaValue = targetAlpha
            backgroundView.layer?.backgroundColor = bgColor
        }
    }
    
    // MARK: - Public
    
    func updateIcon(_ icon: String) {
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
    }
    
    func setActive(_ active: Bool, animated: Bool) {
        isActive = active
        let color = active ? activeColor : .white
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = animationDuration
                iconView.animator().contentTintColor = color
            }
        } else {
            iconView.contentTintColor = color
        }
    }
    
    func flashActive() {
        // 短暂变色后恢复
        NSAnimationContext.runAnimationGroup { context in
            context.duration = animationDuration
            iconView.animator().contentTintColor = activeColor
        } completionHandler: { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = self.animationDuration
                    self.iconView.animator().contentTintColor = .white
                }
            }
        }
    }
    
    func showFeedback() {
        guard let feedbackIcon = feedbackIcon else { return }
        
        // 变为勾
        NSAnimationContext.runAnimationGroup { context in
            context.duration = animationDuration
            iconView.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self = self else { return }
            self.iconView.image = NSImage(systemSymbolName: feedbackIcon, accessibilityDescription: nil)
            self.iconView.contentTintColor = .systemGreen
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = self.animationDuration
                self.iconView.animator().alphaValue = 1
            } completionHandler: {
                // 恢复原图标
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    guard let self = self else { return }
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = self.animationDuration
                        self.iconView.animator().alphaValue = 0
                    } completionHandler: {
                        self.iconView.image = NSImage(systemSymbolName: self.defaultIcon, accessibilityDescription: nil)
                        self.iconView.contentTintColor = .white
                        NSAnimationContext.runAnimationGroup { context in
                            context.duration = self.animationDuration
                            self.iconView.animator().alphaValue = 1
                        }
                    }
                }
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
}
