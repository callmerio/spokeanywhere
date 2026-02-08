import AppKit
import Foundation
import os
import Vision
import VisionKit

// MARK: - Screenshot Content View (Pure AppKit)

/// 纯 AppKit 实现的截图内容视图
/// 避免 NSHostingView 的约束循环问题
final class ScreenshotContentView: NSView, ImageAnalysisOverlayViewDelegate {
    
    // MARK: - Constants
    
    let logger = Logger(subsystem: "com.spokeanywhere", category: "ScreenshotContentView")
    
    static let glowPadding: CGFloat = 40
    
    /// 光晕内缩距离（每侧），用于预留阴影扩散空间
    static let paddingPerSide: CGFloat = 30
    
    // MARK: - Properties
    
    let item: ScreenshotItem
    let imageView: NSImageView
    private(set) var actionBar: ActionBarView?
    private let glowLayer = CAShapeLayer()
    private var trackingArea: NSTrackingArea?
    private(set) var isHovered = false
    private var hideActionBarWorkItem: DispatchWorkItem?
    private var mouseDownLocation: CGPoint = .zero
    
    // 菜单事件代理
    private var menuActionProxy: MenuActionProxy?
    
    private let actionBarMinWidth: CGFloat = 200
    
    // MARK: - Image Enhancement
    
    /// 原始图片 (1x)
    private(set) var originalImage: NSImage?
    
    /// 图片增强防抖任务 (延迟启动)
    private var enhanceDebounceTask: DispatchWorkItem?
    
    /// 当前正在执行的增强任务 (可取消)
    private var currentEnhanceTask: Task<Void, Never>?
    
    /// 上次增强时的尺寸，避免微小变动重复计算
    private var lastEnhancedSize: CGSize = .zero
    
    /// AI 增强防抖延迟 (0.3秒 - 快速响应)
    private let enhanceDebounceDelay: TimeInterval = 0.3
    
    // MARK: - AI 增强缓存 (High Resolution)
    
    /// 缓存的 4x AI 增强原图（不缩放）
    /// 只要原图不变，此缓存一直有效，可缩放到任意目标尺寸
    private var cachedHighResImage: NSImage?
    
    /// 缓存对应的原图 ID (用于验证缓存有效性)
    /// 这里使用原图内存地址或 hash 来简单判断
    private weak var cachedOriginalImage: NSImage?
    
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
}

extension ScreenshotContentView {
    
    // MARK: - Setup
    
    private func setupImageView() {
        wantsLayer = true
        layer?.masksToBounds = false
        
        glowLayer.fillColor = DesignTokens.Colors.NS.clear.cgColor
        glowLayer.strokeColor = nil
        glowLayer.lineWidth = 0
        glowLayer.zPosition = -1
        layer?.addSublayer(glowLayer)
        
        // 🔧 Fix: 使用 scaleAxesIndependently 完全填满 frame，避免居中偏移
        // 之前用 scaleProportionallyUpOrDown 会在宽高比不匹配时居中显示
        imageView.imageScaling = .scaleAxesIndependently
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 10
        imageView.layer?.masksToBounds = true
        
        // 加载图片并保存为原始图
        if let image = item.loadImage() {
            self.originalImage = image
            imageView.image = image
        }
        
        addSubview(imageView)
    }
    
    /// 更新图片质量（响应缩放）
    /// - Parameter targetSize: 目标显示尺寸
    /// 
    /// 策略：
    /// 1. 检查是否存在 4x HighRes 缓存 ? 直接 Downscale 显示
    /// 2. 否则 -> 异步生成 Basic 增强（中间态）
    /// 3. 并行 -> 异步执行 AI 增强 -> 完成后显示并缓存 4x HighRes
    func updateImageQuality(targetSize: CGSize) {
        // 1. 取消此前的任务
        enhanceDebounceTask?.cancel()
        enhanceDebounceTask = nil
        currentEnhanceTask?.cancel()
        currentEnhanceTask = nil
        
        guard let original = originalImage else { return }
        
        // 2. 清理失效缓存
        if cachedOriginalImage !== original {
            cachedHighResImage = nil
            cachedOriginalImage = original
            logger.debug("🧹 Cache cleared (new image loaded)")
        }
        
        // 3. 计算缩放比例
        let scale = targetSize.width / original.size.width
        
        // 4. 如果缩放比例 < 1.1，使用原图
        if scale < 1.1 {
            if imageView.image !== original {
                imageView.image = original
                lastEnhancedSize = .zero
                logger.debug("Restore original (scale < 1.1)")
            }
            return
        }
        
        // 5. 忽略微小变化 (除非是首次放大)
        if abs(targetSize.width - lastEnhancedSize.width) < 10 && lastEnhancedSize != .zero {
            return
        }
        
        // 6. [Case A] 缓存命中 (HighRes 4x 存在)
        // 直接从 4x 大图 downscale 到 targetSize (非常快)
        if let highRes = cachedHighResImage {
            logger.info("⚡ HighRes Cache Hit! Downscaling to \(targetSize.width)x\(targetSize.height)")
            
            // 异步执行 downscale 避免卡顿
            Task {
                let backingScale = await MainActor.run { NSScreen.main?.backingScaleFactor ?? 2.0 }
                if let downscaled = ImageEnhancementService.shared.scaleNSImage(highRes, to: targetSize, backingScale: backingScale) {
                    await MainActor.run {
                        self.imageView.image = downscaled
                        self.lastEnhancedSize = targetSize
                    }
                }
            }
            return
        }
        
        // 7. [Case B] 无缓存 - 启动增强流程
        
        // ======================================================
        // 🎯 Step 1: 立即执行 Basic 增强（不等 debounce！）
        // 用户放大的瞬间就能看到锐化后的图片
        // ======================================================
        Task { [weak self] in
            guard let self = self else { return }
            
            let basic = await Task.detached(priority: .userInitiated) {
                ImageEnhancementService.shared.enhanceBasic(original, to: targetSize)
            }.value
            
            if let basic = basic {
                await MainActor.run {
                    // 只有当前没有更好的结果时才显示 Basic
                    // 避免 AI 结果已出来后被 Basic 覆盖
                    if self.lastEnhancedSize != targetSize {
                        self.imageView.image = basic
                        self.logger.info("🎯 Immediate Basic enhancement shown")
                    }
                }
            }
        }
        
        // ======================================================
        // 🚀 Step 2: Debounce 后执行 AI 增强
        // 等用户停止缩放操作后再启动 AI，节省资源
        // ======================================================
        let debounceTask = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            self.currentEnhanceTask = Task { [weak self] in
                guard let self = self else { return }
                
                // 启动 AI 增强 (High Res)
                let aiTask = Task.detached(priority: .userInitiated) {
                    return await ImageEnhancementService.shared.enhanceAIHighResAsync(original)
                }
                
                // 等待 AI 结果
                if let highResResult = await aiTask.value {
                    if !Task.isCancelled {
                        // 缓存 4x 大图
                        await MainActor.run {
                            self.cachedHighResImage = highResResult
                            self.cachedOriginalImage = original
                            self.logger.info("💾 Cached HighRes AI result")
                        }
                        
                        // Downscale 到当前需要的尺寸
                        let backingScale = await MainActor.run { NSScreen.main?.backingScaleFactor ?? 2.0 }
                        if let finalResult = ImageEnhancementService.shared.scaleNSImage(highResResult, to: targetSize, backingScale: backingScale) {
                            await MainActor.run {
                                self.imageView.image = finalResult
                                self.lastEnhancedSize = targetSize
                                self.logger.info("✅ Final AI result shown")
                            }
                        }
                    }
                }
            }
        }
        
        self.enhanceDebounceTask = debounceTask
        DispatchQueue.main.asyncAfter(deadline: .now() + enhanceDebounceDelay, execute: debounceTask)
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
        
        // 1.5 Copy Enhanced Image (仅当 upscalingMode != .none 时显示)
        if ScreenshotSettings.shared.upscalingMode != .none {
            let copyEnhancedItem = NSMenuItem(title: "Copy Enhanced Image", action: #selector(MenuActionProxy.performCopyEnhancedImage), keyEquivalent: "")
            copyEnhancedItem.target = menuActionProxy
            menu.addItem(copyEnhancedItem)
        }
        
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
    
    func setupContextMenu() {
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
}

extension ScreenshotContentView {
    
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
}

extension ScreenshotContentView {
    
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
    
    /// 允许非活跃窗口响应首次点击（单击直接拖拽，无需先激活窗口）
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
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
}

extension ScreenshotContentView {
    
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
            glowLayer.strokeColor = DesignTokens.Colors.NS.glowMarkStroke.cgColor
            glowLayer.lineWidth = 1.5
            glowLayer.shadowColor = DesignTokens.Colors.NS.glowMarkShadow.cgColor
            glowLayer.shadowRadius = 12
            glowLayer.shadowOffset = .zero
            glowLayer.shadowOpacity = 0.5
        } else if isHovered {
            // 蓝色光晕 (Hover/Select 状态 - 临时) - 柔和版本
            glowLayer.strokeColor = DesignTokens.Colors.NS.glowHoverStroke.cgColor
            glowLayer.lineWidth = 1.5
            glowLayer.shadowColor = DesignTokens.Colors.NS.glowHoverShadow.cgColor
            glowLayer.shadowRadius = 10
            glowLayer.shadowOffset = .zero
            glowLayer.shadowOpacity = 0.45
        } else if !isPinned {
            // 奶白色光晕 (非 Pin 状态) - 帮助用户定位新截图
            // #E7D8AF -> RGB(231, 216, 175)
            glowLayer.strokeColor = DesignTokens.Colors.NS.glowIdle.withAlphaComponent(0.5).cgColor
            glowLayer.lineWidth = 1.5
            glowLayer.shadowColor = DesignTokens.Colors.NS.glowIdle.cgColor
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
}
