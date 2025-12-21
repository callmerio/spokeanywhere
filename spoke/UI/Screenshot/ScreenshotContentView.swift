import AppKit
import Vision
import VisionKit

// MARK: - Screenshot Content View (Pure AppKit)

/// 纯 AppKit 实现的截图内容视图
/// 避免 NSHostingView 的约束循环问题
final class ScreenshotContentView: NSView, ImageAnalysisOverlayViewDelegate {
    
    // MARK: - Constants
    
    static let glowPadding: CGFloat = 40
    
    /// 光晕内缩距离（每侧），用于预留阴影扩散空间
    static let paddingPerSide: CGFloat = 30
    
    // MARK: - Properties
    
    let item: ScreenshotItem
    private let imageView: NSImageView
    private var actionBar: ActionBarView?      // 右上角：AI + Pin
    private let glowLayer = CAShapeLayer()  // 光晕专用层（使用 ShapeLayer 支持路径绘制）
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var hideActionBarWorkItem: DispatchWorkItem?
    
    // 菜单事件代理，解决 Responder Chain 问题
    private var menuActionProxy: MenuActionProxy?
    
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
        wantsLayer = true
        layer?.masksToBounds = false // 确保容器不裁剪超出边界的内容（如阴影）
        
        // 光晕层用于显示 border 和 shadow
        // 使用 CAShapeLayer 绘制圆角矩形路径，确保 shadow 正确显示
        glowLayer.fillColor = NSColor.clear.cgColor
        glowLayer.strokeColor = nil
        glowLayer.lineWidth = 0
        glowLayer.zPosition = -1 // 确保在最底层
        layer?.addSublayer(glowLayer)
        
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 10
        imageView.layer?.masksToBounds = true
        
        // 加载图片
        if let image = item.loadImage() {
            imageView.image = image
        }
        
        // 移除单独的 alpha 设置，由 Window 统一管理
        // imageView.alphaValue = item.opacity
        
        addSubview(imageView)
    }
    
    /// 设置 Live Text 覆盖层 (macOS 13+)
    /// 使用 .automatic 让系统自动控制 OCR 按钮和交互
    private func setupLiveText() {
        guard #available(macOS 13.0, *) else { return }
        
        liveTextOverlay.frame = imageView.bounds
        liveTextOverlay.trackingImageView = imageView
        liveTextOverlay.delegate = self  // 设置 delegate 以扩展右键菜单
        // 使用 .automatic：系统自动控制 OCR 按钮显示和交互
        liveTextOverlay.preferredInteractionTypes = .automatic
        // 隐藏系统辅助界面（Translate 按钮等），只保留 Copy All
        liveTextOverlay.isSupplementaryInterfaceHidden = true
        addSubview(liveTextOverlay)
        
        // 后台预分析图片
        Task {
            await preanalyzeLiveText()
        }
    }
    
    /// 获取识别的文本内容
    func getRecognizedText() -> String? {
        if #available(macOS 13.0, *),
           let analysis = liveTextOverlay.analysis {
            return analysis.transcript
        }
        return nil
    }
    
    // MARK: - ImageAnalysisOverlayViewDelegate
    
    /// 在系统菜单基础上添加自定义菜单项
    @available(macOS 13.0, *)
    func overlayView(_ overlayView: ImageAnalysisOverlayView, updatedMenuFor menu: NSMenu, for event: NSEvent, at point: CGPoint) -> NSMenu {
        // 创建 Proxy 并持有
        self.menuActionProxy = MenuActionProxy(view: self)
        
        // 移除系统的 Translate 菜单项，只保留 Copy All
        for item in menu.items.reversed() {
            let title = item.title.lowercased()
            let actionName = item.action?.description.lowercased() ?? ""
            if title.contains("translate") || title.contains("翻译") ||
               actionName.contains("translate") ||
               item.identifier?.rawValue.lowercased().contains("translate") == true {
                menu.removeItem(item)
            }
        }
        
        // 添加分隔线
        menu.addItem(NSMenuItem.separator())
        
        // 1. Copy Image (C)
        let copyImgItem = NSMenuItem(title: "Copy Image (C)", action: #selector(MenuActionProxy.performCopyImage), keyEquivalent: "c")
        copyImgItem.keyEquivalentModifierMask = [] 
        copyImgItem.target = menuActionProxy
        menu.addItem(copyImgItem)
        
        // 2. Copy Text (T)
        if let text = getRecognizedText(), !text.isEmpty {
            let copyTextItem = NSMenuItem(title: "Copy [T]ext", action: #selector(MenuActionProxy.performCopyText), keyEquivalent: "t")
            copyTextItem.keyEquivalentModifierMask = []
            copyTextItem.target = menuActionProxy
            menu.addItem(copyTextItem)
        }
        
        // 分隔线
        menu.addItem(NSMenuItem.separator())
        
        // 3. Pin to Space (P)
        let pinTitle = item.isPinned ? "Unpin (P)" : "Pin to Space (P)"
        let pinItem = NSMenuItem(title: pinTitle, action: #selector(MenuActionProxy.performPinAction), keyEquivalent: "p")
        pinItem.keyEquivalentModifierMask = []
        pinItem.target = menuActionProxy
        menu.addItem(pinItem)
        
        // 4. Quick Ask (A)
        let aiItem = NSMenuItem(title: "Quick Ask (A)", action: #selector(MenuActionProxy.performQuickAsk), keyEquivalent: "a")
        aiItem.keyEquivalentModifierMask = []
        aiItem.target = menuActionProxy
        menu.addItem(aiItem)
        
        // 分隔线
        menu.addItem(NSMenuItem.separator())
        
        // 5. Mark (M)
        let markTitle = item.isMarked ? "Unmark (M)" : "Mark (M)"
        let markItem = NSMenuItem(title: markTitle, action: #selector(MenuActionProxy.performMarkAction), keyEquivalent: "m")
        markItem.keyEquivalentModifierMask = []
        markItem.target = menuActionProxy
        menu.addItem(markItem)
        
        // 6. Close (Q)
        let closeItem = NSMenuItem(title: "Close (Q)", action: #selector(MenuActionProxy.performCloseAction), keyEquivalent: "q")
        closeItem.keyEquivalentModifierMask = []
        closeItem.target = menuActionProxy
        menu.addItem(closeItem)
        
        return menu
    }
    
    // MARK: - Validation
    

    
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
    
    private func setupActionBar() {
        // 右上角：AI + Pin 按钮组
        let bar = ActionBarView(item: item)
        bar.isHidden = true
        bar.alphaValue = 0
        addSubview(bar)
        self.actionBar = bar
    }
    
    private func setupContextMenu() {
        let menu = NSMenu()
        
        // Copy Image (Cmd+C)
        let copyItem = NSMenuItem(title: "Copy Image", action: #selector(performCopyImage), keyEquivalent: "c")
        copyItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        copyItem.target = self
        menu.addItem(copyItem)
        
        menu.addItem(.separator())
        
        // Pin/Unpin (Cmd+P)
        let pinItem = NSMenuItem(
            title: item.isPinned ? "Unpin" : "Pin to Space",
            action: #selector(performPinAction),
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
        let quickAskItem = NSMenuItem(title: "Quick Ask", action: #selector(performQuickAsk), keyEquivalent: "")
        quickAskItem.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
        quickAskItem.target = self
        menu.addItem(quickAskItem)
        
        menu.addItem(.separator())
        
        // Mark/Unmark (Cmd+M)
        let markItem = NSMenuItem(
            title: item.isMarked ? "Unmark" : "Mark",
            action: #selector(performMarkAction),
            keyEquivalent: "m"
        )
        markItem.image = NSImage(systemSymbolName: item.isMarked ? "bookmark.slash" : "bookmark", accessibilityDescription: nil)
        markItem.target = self
        menu.addItem(markItem)
        
        menu.addItem(.separator())
        
        // Close (Cmd+W)
        let closeItem = NSMenuItem(title: "Close", action: #selector(performCloseAction), keyEquivalent: "w")
        closeItem.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: nil)
        closeItem.target = self
        menu.addItem(closeItem)
        
        self.menu = menu
    }
    
    // MARK: - Layout
    
    override func layout() {
        super.layout()
        
        // 增加 padding，防止光晕和圆角被裁剪
        // 父窗口可能裁剪 content view，所以在这里做内缩
        // 阴影半径约为 20px，预留 30px padding 确保完全显示
        let padding = Self.paddingPerSide
        let contentFrame = bounds.insetBy(dx: padding, dy: padding)
        
        imageView.frame = contentFrame
        
        // 更新 glowLayer 的 frame 和 path（确保光晕圆角正确）
        glowLayer.frame = bounds // glowLayer 使用全尺寸，利用 padding 区域显示光晕
        
        // path 基于 contentFrame，但转换为 glowLayer 的坐标系
        // 向外扩展 1px，确保 border 不被 imageView 遮挡（stroke 是居中绘制的）
        let pathRect = CGRect(x: padding, y: padding, width: contentFrame.width, height: contentFrame.height).insetBy(dx: -1, dy: -1)
        let path = CGPath(roundedRect: pathRect, cornerWidth: 10, cornerHeight: 10, transform: nil)
        glowLayer.path = path
        glowLayer.shadowPath = path
        
        // Live Text 覆盖层布局 (macOS 13+)
        if #available(macOS 13.0, *) {
            liveTextOverlay.frame = contentFrame
        }
        
        // ActionBar 布局（右上角：AI + Pin）
        if let bar = actionBar {
            let barSize = bar.intrinsicContentSize
            bar.frame = CGRect(
                x: bounds.width - barSize.width - 8 - padding,  // 距离右边 8pt + padding
                y: bounds.height - barSize.height - 8 - padding,  // 距离顶部 8pt + padding
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
        
        // 通知窗口显示蓝色光晕
        (window as? ScreenshotWindow)?.updateGlow(hovered: true)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        
        // 防抖：延迟隐藏，避免闪烁
        hideActionBarWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // Double Check: 只有当鼠标真正在视图外部时才执行隐藏
            // 这解决了从子视图（按钮）移回父视图时可能误触 Exited 的问题
            if let window = self.window {
                let mouseLocation = window.mouseLocationOutsideOfEventStream
                let localPoint = self.convert(mouseLocation, from: nil)
                if self.bounds.contains(localPoint) {
                    // 鼠标其实还在里面，恢复状态并取消隐藏
                    self.isHovered = true
                    self.updateActionBarVisibility(animated: true)
                    (self.window as? ScreenshotWindow)?.updateGlow(hovered: true)
                    return
                }
            }
            
            self.isHovered = false
            self.updateActionBarVisibility(animated: true)
            // 通知窗口隐藏蓝色光晕
            (self.window as? ScreenshotWindow)?.updateGlow(hovered: false)
        }
        hideActionBarWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }
    
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
        
        // Live Text 有活跃选择时，让系统处理事件（不拖动窗口）
        if #available(macOS 13.0, *) {
            if liveTextOverlay.hasActiveTextSelection {
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
        // 宽度不足时始终隐藏
        let shouldShow = isHovered && bounds.width >= actionBarMinWidth
        
        // ActionBar（右上角：AI + Pin）
        if let bar = actionBar {
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
    }
    
    // MARK: - Drawing
    
    // 移除 wantsUpdateLayer 和 updateLayer
    // 直接在 setup 和 layout 中管理 layer 属性
    
    // MARK: - Update
    
    // 移除 updateOpacity，透明度由 Window 统一控制
    
    /// 更新光晕效果（由 ScreenshotWindow 调用）
    /// 使用 CAShapeLayer 的 strokeColor 绘制边框，shadow 实现光晕
    /// 颜色优先级：Mark(橙) > Hover(蓝) > 非Pin(奶白) > 无
    func updateGlow(isHovered: Bool, isMarked: Bool, isPinned: Bool) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.25)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        
        if isMarked {
            // 橙色光晕 (Mark 状态 - 持久) - 柔和版本
            glowLayer.strokeColor = NSColor(red: 0.95, green: 0.6, blue: 0.2, alpha: 0.4).cgColor
            glowLayer.lineWidth = 1.5
            glowLayer.shadowColor = NSColor(red: 0.95, green: 0.55, blue: 0.2, alpha: 1.0).cgColor
            glowLayer.shadowRadius = 12
            glowLayer.shadowOffset = .zero
            glowLayer.shadowOpacity = 0.5
        } else if isHovered {
            // 蓝色光晕 (Hover/Select 状态 - 临时) - 柔和版本
            glowLayer.strokeColor = NSColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 0.4).cgColor
            glowLayer.lineWidth = 1.5
            glowLayer.shadowColor = NSColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1.0).cgColor
            glowLayer.shadowRadius = 10
            glowLayer.shadowOffset = .zero
            glowLayer.shadowOpacity = 0.45
        } else if !isPinned {
            // 奶白色光晕 (非 Pin 状态) - 帮助用户定位新截图
            // #E7D8AF -> RGB(231, 216, 175)
            let creamColor = NSColor(red: 231/255.0, green: 216/255.0, blue: 175/255.0, alpha: 1.0)
            glowLayer.strokeColor = creamColor.withAlphaComponent(0.5).cgColor
            glowLayer.lineWidth = 1.5
            glowLayer.shadowColor = creamColor.cgColor
            glowLayer.shadowRadius = 10
            glowLayer.shadowOffset = .zero
            glowLayer.shadowOpacity = 0.6
        } else {
            // 无光晕 (Pin 状态且非 hover/mark)
            glowLayer.strokeColor = nil
            glowLayer.lineWidth = 0
            glowLayer.shadowColor = nil
            glowLayer.shadowOpacity = 0
        }
        
        CATransaction.commit()
    }
    
    func refreshMenuItems() {
        setupContextMenu()
    }
    
    
    // MARK: - Actions
    
    @objc func performPinAction() {
        if item.isPinned {
            ScreenshotManager.shared.unpin(item)
        } else {
            ScreenshotManager.shared.pin(item)
        }
        
        if let window = window as? ScreenshotWindow {
            window.updateCollectionBehavior()
        }
        refreshMenuItems()
        // 刷新 ActionBar 的 Pin 图标状态
        actionBar?.refreshButtons()
    }
    
    @objc func performLockAction() {
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
    
    @objc func performCopyImage() {
        ScreenshotManager.shared.copyToClipboard(item)
    }
    
    @objc func performOCR() {
        // Legacy OCR method for macOS 12
        if #available(macOS 13.0, *) { return }
        guard let image = item.loadImage(),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
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
    
    @objc func performCopyText() {
        if let text = getRecognizedText(), !text.isEmpty {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
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
    
    @objc func performQuickAsk() {
        guard let image = item.loadImage() else { return }
        QuickAskService.shared.startSession()
        QuickAskService.shared.state.addScreenshot(image)
    }
    
    // 公开给 Window 调用，支持快捷键 A 触发
    func triggerQuickAsk() {
        performQuickAsk()
    }
    
    @objc func performCloseAction() {
        ScreenshotManager.shared.close(item)
    }
    
    @objc func performMarkAction() {
        if item.isMarked {
            ScreenshotManager.shared.unmark(item)
        } else {
            ScreenshotManager.shared.mark(item)
        }
        setupContextMenu()
        // 刷新光晕效果
        updateGlow(isHovered: isHovered, isMarked: item.isMarked, isPinned: item.isPinned)
        // 刷新 ActionBar Pin 按钮状态（Mark 会自动 Pin）
        actionBar?.refreshButtons()
    }
    
}

// MARK: - Menu Action Proxy

/// 专用 Target 类，绕过 View Responder Chain 问题
/// 将菜单事件转发给 View 处理
@objc class MenuActionProxy: NSObject {
    weak var view: ScreenshotContentView?
    
    init(view: ScreenshotContentView) {
        self.view = view
    }
    
    @objc func performPinAction() { 
        view?.performPinAction() 
    }
    @objc func performMarkAction() { view?.performMarkAction() }
    @objc func performCopyImage() { view?.performCopyImage() }
    @objc func performCopyText() { view?.performCopyText() }
    @objc func performQuickAsk() { view?.performQuickAsk() }
    @objc func performCloseAction() { view?.performCloseAction() }

}

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
        // 右上角只放两个按钮：AI + Pin（OCR 单独在右下角）
        
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
        // 默认半透明黑色，hover 时更深（增加对比度）
        let bgColor = isHovered 
            ? NSColor.black.withAlphaComponent(0.8).cgColor  // Hover: 深黑 (0.8)
            : NSColor.black.withAlphaComponent(0.5).cgColor  // Normal: 半透黑 (0.5)
            
        // 确保图标颜色正确（非 active 时始终为白色）
        let iconColor = isActive ? activeColor : .white
        
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
            self.updateHoverState(animated: true)
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
