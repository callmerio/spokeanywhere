import AppKit
import VisionKit

// MARK: - Screenshot Content View (Pure AppKit)

/// 纯 AppKit 实现的截图内容视图
/// 避免 NSHostingView 的约束循环问题
final class ScreenshotContentView: NSView, ImageAnalysisOverlayViewDelegate {
    
    // MARK: - Properties
    
    let item: ScreenshotItem
    private let imageView: NSImageView
    private var actionBar: ActionBarView?
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var hideActionBarWorkItem: DispatchWorkItem?
    
    /// ActionBar 最小宽度（小于此宽度时隐藏）
    private let actionBarMinWidth: CGFloat = 200
    
    // MARK: - Live Text (macOS 13+)
    
    /// Live Text 覆盖层，支持图片中文字选择
    @available(macOS 13.0, *)
    private lazy var liveTextOverlay: ImageAnalysisOverlayView = {
        let overlay = ImageAnalysisOverlayView()
        overlay.autoresizingMask = [.width, .height]
        return overlay
    }()
    
    /// 图片分析器
    @available(macOS 13.0, *)
    private lazy var imageAnalyzer = ImageAnalyzer()
    
    /// Live Text 是否已分析完成
    private var isLiveTextReady = false
    
    /// Live Text 是否已启用（点击 OCR 后启用）
    private(set) var isLiveTextEnabled = false
    
    // MARK: - Init
    
    init(item: ScreenshotItem) {
        self.item = item
        self.imageView = NSImageView()
        
        super.init(frame: .zero)
        
        setupImageView()
        setupLiveText()
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
    
    /// 设置 Live Text 覆盖层 (macOS 13+)
    /// 默认禁用交互，点击 OCR 按钮后启用
    private func setupLiveText() {
        guard #available(macOS 13.0, *) else { return }
        
        liveTextOverlay.frame = imageView.bounds
        liveTextOverlay.trackingImageView = imageView
        liveTextOverlay.delegate = self  // 设置 delegate 以扩展右键菜单
        // 默认禁用交互（图片模式），点击 OCR 按钮后启用
        liveTextOverlay.preferredInteractionTypes = []
        addSubview(liveTextOverlay)
        
        // 后台预分析图片
        Task {
            await preanalyzeLiveText()
        }
    }
    
    // MARK: - ImageAnalysisOverlayViewDelegate
    
    /// 在系统菜单基础上添加自定义菜单项
    @available(macOS 13.0, *)
    func overlayView(_ overlayView: ImageAnalysisOverlayView, updatedMenuFor menu: NSMenu, for event: NSEvent, at point: CGPoint) -> NSMenu {
        // 添加分隔线
        menu.addItem(NSMenuItem.separator())
        
        // Pin 菜单项
        let pinTitle = item.isPinned ? "Unpin (⌘P)" : "Pin to Space (⌘P)"
        let pinItem = NSMenuItem(title: pinTitle, action: #selector(togglePin), keyEquivalent: "p")
        pinItem.target = self
        menu.addItem(pinItem)
        
        // AI 菜单项
        let aiItem = NSMenuItem(title: "Quick Ask", action: #selector(openQuickAsk), keyEquivalent: "")
        aiItem.target = self
        menu.addItem(aiItem)
        
        // 分隔线
        menu.addItem(NSMenuItem.separator())
        
        // Close 菜单项
        let closeItem = NSMenuItem(title: "Close (⌘W)", action: #selector(closeWindow), keyEquivalent: "w")
        closeItem.target = self
        menu.addItem(closeItem)
        
        return menu
    }
    
    /// 预分析图片中的文字 (macOS 13+)
    /// 只分析不启用交互，等待用户点击 OCR 按钮
    @available(macOS 13.0, *)
    private func preanalyzeLiveText() async {
        guard let image = imageView.image else { return }
        
        let config = ImageAnalyzer.Configuration([.text])
        do {
            let analysis = try await imageAnalyzer.analyze(image, orientation: .up, configuration: config)
            // 只保存分析结果，不启用交互
            liveTextOverlay.analysis = analysis
            isLiveTextReady = true
        } catch {
            // 分析失败静默处理（图片可能没有文字）
        }
    }
    
    /// 启用 Live Text 交互 (macOS 13+)
    @available(macOS 13.0, *)
    func enableLiveText() {
        guard isLiveTextReady else { return }
        liveTextOverlay.preferredInteractionTypes = .textSelection
        isLiveTextEnabled = true
    }
    
    /// 禁用 Live Text 交互 (macOS 13+)
    @available(macOS 13.0, *)
    func disableLiveText() {
        liveTextOverlay.preferredInteractionTypes = []
        isLiveTextEnabled = false
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
        
        // Copy Image (Cmd+C)
        let copyItem = NSMenuItem(title: "Copy Image", action: #selector(copyImage), keyEquivalent: "c")
        copyItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        copyItem.target = self
        menu.addItem(copyItem)
        
        menu.addItem(.separator())
        
        // Pin/Unpin (Cmd+P)
        let pinItem = NSMenuItem(
            title: item.isPinned ? "Unpin" : "Pin to Space",
            action: #selector(togglePin),
            keyEquivalent: "p"
        )
        pinItem.image = NSImage(systemSymbolName: item.isPinned ? "pin.slash" : "pin", accessibilityDescription: nil)
        pinItem.target = self
        menu.addItem(pinItem)
        
        // OCR (Cmd+O)
        let ocrItem = NSMenuItem(title: "OCR", action: #selector(performOCR), keyEquivalent: "o")
        ocrItem.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: nil)
        ocrItem.target = self
        menu.addItem(ocrItem)
        
        // Quick Ask
        let quickAskItem = NSMenuItem(title: "Quick Ask", action: #selector(openQuickAsk), keyEquivalent: "")
        quickAskItem.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
        quickAskItem.target = self
        menu.addItem(quickAskItem)
        
        menu.addItem(.separator())
        
        // Close (Cmd+W)
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
        
        // Live Text 覆盖层布局 (macOS 13+)
        if #available(macOS 13.0, *) {
            liveTextOverlay.frame = bounds
        }
        
        // ActionBar 布局（右下角）
        if let bar = actionBar {
            let barSize = bar.intrinsicContentSize
            bar.frame = CGRect(
                x: bounds.width - barSize.width - 8,  // 距离右边 8pt
                y: 8,  // 距离底部 8pt
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
    
    // MARK: - Mouse Events
    
    /// 鼠标按下位置（用于判断是否拖动选择）
    private var mouseDownLocation: CGPoint = .zero
    
    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = event.locationInWindow
        
        // 检查是否点击在 ActionBar 上
        if let bar = actionBar, !bar.isHidden {
            let locationInBar = bar.convert(event.locationInWindow, from: nil)
            if bar.bounds.contains(locationInBar) {
                super.mouseDown(with: event)
                return
            }
        }
        
        // 未锁定时支持拖动窗口（Live Text 区域外）
        if !item.isLocked {
            window?.performDrag(with: event)
        } else {
            super.mouseDown(with: event)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        
        // 检查是否是拖动选择（移动距离大于阈值）
        let mouseUpLocation = event.locationInWindow
        let distance = hypot(mouseUpLocation.x - mouseDownLocation.x,
                            mouseUpLocation.y - mouseDownLocation.y)
        
        // 如果是拖动选择，延迟检查 Live Text 选中状态
        if distance > 5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.checkLiveTextSelection(at: mouseUpLocation)
            }
        }
    }
    
    /// 检查 Live Text 选中状态，如果有选中文本则显示 SelectionToolbar
    @available(macOS 13.0, *)
    private func checkLiveTextSelection(at location: CGPoint) {
        // 检查 Live Text 是否有活跃的文本选择
        guard liveTextOverlay.hasActiveTextSelection else { return }
        
        // 获取选中的文本
        let selectedText = liveTextOverlay.selectedText
        guard !selectedText.isEmpty else { return }
        
        // 转换坐标：窗口坐标 → 屏幕坐标
        guard let window = self.window else { return }
        let screenPoint = window.convertPoint(toScreen: location)
        
        // 创建选择上下文
        let context = SelectionContext(
            selectedText: selectedText,
            selectionBounds: CGRect(x: screenPoint.x - 50, y: screenPoint.y, width: 100, height: 20),
            sourceAppBundleId: Bundle.main.bundleIdentifier ?? "",
            sourceAppName: "SpokenAnyWhere"
        )
        
        // 显示工具栏
        SelectionToolbarState.shared.show(with: context)
        SelectionToolbarManager.shared.show(at: screenPoint)
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
        // macOS 13+ 使用 Live Text 交互模式
        if #available(macOS 13.0, *) {
            if isLiveTextEnabled {
                // 已启用，点击退出 OCR 模式
                disableLiveText()
            } else {
                // 启用 Live Text 交互
                enableLiveText()
            }
            return
        }
        
        // macOS 12 及以下使用传统 OCR（复制全部文字到剪贴板）
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

/// 纯 AppKit 实现的操作条（无背景小按钮样式，类似系统 Live Text 按钮）
final class ActionBarView: NSView {
    
    // MARK: - Properties
    
    private let item: ScreenshotItem
    private var actionButtons: [ActionBarButton] = []
    
    private let buttonSize: CGFloat = 24
    private let buttonSpacing: CGFloat = 2
    
    // MARK: - Init
    
    init(item: ScreenshotItem) {
        self.item = item
        super.init(frame: .zero)
        
        wantsLayer = true
        setupButtons()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupButtons() {
        // 三个按钮：AI (左) + Pin (中) + OCR (右下角)
        
        // Quick Ask 按钮 (AI)
        let quickAskButton = ActionBarButton(
            icon: "sparkles",
            activeColor: .systemBlue
        ) { [weak self] in self?.openQuickAsk() }
        quickAskButton.toolTip = "Quick Ask"
        
        // Pin 按钮 (Cmd+P)
        let pinButton = ActionBarButton(
            icon: item.isPinned ? "pin.fill" : "pin",
            activeColor: .orange,
            isActive: item.isPinned
        ) { [weak self] in self?.togglePin() }
        pinButton.toolTip = item.isPinned ? "Unpin (⌘P)" : "Pin to Space (⌘P)"
        
        // OCR 按钮 - 切换文字选择模式
        let ocrButton = ActionBarButton(
            icon: "text.viewfinder",
            activeColor: .systemGreen
        ) { [weak self] in self?.toggleOCRMode() }
        ocrButton.toolTip = "OCR Mode (⌘O)"
        
        actionButtons = [quickAskButton, pinButton, ocrButton]  // AI, Pin, OCR
        
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
        
        // 点击后短暂变色（AI 按钮是索引 0）
        actionButtons[0].flashActive()
        
        QuickAskService.shared.startSession()
        QuickAskService.shared.state.addScreenshot(image)
    }
    
    private func closeWindow() {
        ScreenshotManager.shared.close(item)
    }
    
    /// 切换 OCR 模式（启用/禁用 Live Text 交互）
    private func toggleOCRMode() {
        guard let contentView = superview as? ScreenshotContentView else { return }
        
        if #available(macOS 13.0, *) {
            if contentView.isLiveTextEnabled {
                // 退出 OCR 模式
                contentView.disableLiveText()
                actionButtons[2].setActive(false, animated: true)
            } else {
                // 进入 OCR 模式
                contentView.enableLiveText()
                actionButtons[2].setActive(true, animated: true)
            }
        }
    }
    
    private func refreshButtons() {
        // 布局: AI(0), Pin(1), OCR(2)
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
        
        // 背景（默认显示半透明，hover 时更亮）
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 6  // 小圆角正方形
        backgroundView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        backgroundView.alphaValue = 1  // 默认显示，确保可见度
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
        // 默认半透明黑色，hover 时更亮
        let bgColor = isHovered 
            ? NSColor.white.withAlphaComponent(0.25).cgColor 
            : NSColor.black.withAlphaComponent(0.5).cgColor
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                backgroundView.animator().layer?.backgroundColor = bgColor
            }
        } else {
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
