import AppKit
import ScreenCaptureKit

// MARK: - Region Selection Window

/// 全屏透明选区窗口
/// 覆盖目标屏幕，让用户框选截图区域
/// 支持编辑模式：选区可调整 + 工具栏
@MainActor
final class RegionSelectionWindow: NSPanel {
    
    // MARK: - Types
    
    /// 确认模式
    enum ConfirmMode: CustomStringConvertible {
        case temporary      // 确认（临时状态，暖白光晕）
        case pin            // 直接 Pin（持久化，无光晕）
        case copy           // 复制到剪贴板，不显示截图
        
        var description: String {
            switch self {
            case .temporary: return "temporary"
            case .pin: return "pin"
            case .copy: return "copy"
            }
        }
    }
    
    // MARK: - Properties
    
    /// 选区视图
    private let selectionView: RegionSelectionView
    
    /// 工具栏
    private var toolbarView: ScreenshotToolbarView?
    
    /// 完成回调 (选区坐标, 裁剪后的图片, 确认模式)
    var onComplete: ((CGRect, NSImage, ConfirmMode) -> Void)?
    
    /// 取消回调
    var onCancel: (() -> Void)?
    
    /// 全屏截图（作为背景）
    private var fullScreenImage: NSImage?
    
    /// 目标屏幕的 frame
    private var screenFrame: CGRect = .zero
    
    /// 工具栏与选区的间距
    private let toolbarSpacing: CGFloat = 8
    
    // MARK: - Init
    
    init(screenFrame: CGRect) {
        self.screenFrame = screenFrame
        selectionView = RegionSelectionView(frame: CGRect(origin: .zero, size: screenFrame.size))
        
        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        configure()
        setupSelectionView()
        setupToolbar()
    }
    
    /// 便捷初始化：默认使用鼠标所在屏幕
    convenience init() {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
                     ?? NSScreen.main
                     ?? NSScreen.screens.first!
        self.init(screenFrame: screen.frame)
    }
    
    // MARK: - Configuration
    
    private func configure() {
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        animationBehavior = .none

        // 禁止此窗口被屏幕截图捕获（解决 Ghost 问题）
        sharingType = .none

        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        acceptsMouseMovedEvents = true
        initialFirstResponder = selectionView
    }
    
    private func setupSelectionView() {
        selectionView.autoresizingMask = [.width, .height]
        contentView = selectionView
        
        // 框选完成，进入编辑模式
        selectionView.onSelectionComplete = { [weak self] _ in
            self?.showToolbar()
            self?.setupAnnotationHistoryCallback()
        }
        
        // 选区变化，更新工具栏位置
        selectionView.onSelectionChanged = { [weak self] _ in
            self?.updateToolbarPosition()
        }
        
        // ESC 取消
        selectionView.onCancel = { [weak self] in
            self?.handleCancel()
        }
        
        // Enter 确认
        selectionView.onConfirm = { [weak self] _ in
            self?.handleConfirm(mode: .temporary)
        }
    }
    
    private func setupAnnotationHistoryCallback() {
        selectionView.onAnnotationHistoryChanged = { [weak self] canUndo, canRedo in
            self?.toolbarView?.updateHistoryButtons(canUndo: canUndo, canRedo: canRedo)
        }
    }
    
    private func setupToolbar() {
        let toolbar = ScreenshotToolbarView()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.isHidden = true
        
        toolbar.onAction = { [weak self] action in
            self?.handleToolbarAction(action)
        }
        
        // 添加到 contentView
        contentView?.addSubview(toolbar)
        toolbarView = toolbar
    }
    
    // MARK: - Public API
    
    /// 设置全屏截图作为背景
    func setBackgroundImage(_ image: NSImage) {
        self.fullScreenImage = image
        selectionView.backgroundImage = image
        selectionView.needsDisplay = true
        selectionView.displayIfNeeded()
    }
    
    /// 显示选区窗口
    func show() {
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        NSAnimationContext.endGrouping()
        
        selectionView.needsDisplay = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.makeKey()
            self.makeFirstResponder(self.selectionView)
        }
    }
    
    /// 关闭选区窗口
    func dismiss() {
        hideToolbar()
        selectionView.reset()
        orderOut(nil)
        // 确保系统光标恢复
        NSCursor.unhide()
    }
    
    // MARK: - Toolbar Management
    
    private func showToolbar() {
        guard let toolbar = toolbarView else { return }
        
        toolbar.isHidden = false
        toolbar.invalidateIntrinsicContentSize()
        
        // 计算工具栏尺寸
        let toolbarSize = toolbar.intrinsicContentSize
        toolbar.frame.size = toolbarSize
        
        updateToolbarPosition()
        
        // 淡入动画
        toolbar.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            toolbar.animator().alphaValue = 1
        }
    }
    
    private func hideToolbar() {
        toolbarView?.isHidden = true
    }
    
    private func updateToolbarPosition() {
        guard let toolbar = toolbarView else { return }
        guard selectionView.selectionRect.width > 0 else { return }
        
        let rect = selectionView.selectionRect
        let toolbarSize = toolbar.frame.size
        
        // 默认位置：选区下方居中
        var toolbarX = rect.midX - toolbarSize.width / 2
        var toolbarY = rect.minY - toolbarSpacing - toolbarSize.height
        
        // 边界检查：如果下方空间不够，放到上方
        if toolbarY < toolbarSpacing {
            toolbarY = rect.maxY + toolbarSpacing
        }
        
        // 水平边界检查
        if toolbarX < toolbarSpacing {
            toolbarX = toolbarSpacing
        } else if toolbarX + toolbarSize.width > frame.width - toolbarSpacing {
            toolbarX = frame.width - toolbarSpacing - toolbarSize.width
        }
        
        toolbar.frame.origin = CGPoint(x: toolbarX, y: toolbarY)
    }
    
    // MARK: - Toolbar Actions
    
    private func handleToolbarAction(_ action: ScreenshotToolbarView.ToolbarAction) {
        switch action {
        // 标注工具
        case .arrow:
            selectTool(.arrow, action: action)
            
        case .pen:
            selectTool(.pen, action: action)
            
        case .marker:
            selectTool(.marker, action: action)
            
        case .text:
            selectTool(.text, action: action)
            
        case .eraser:
            selectTool(.eraser, action: action)
            
        // 历史
        case .undo:
            selectionView.undoAnnotation()
            
        case .redo:
            selectionView.redoAnnotation()
            
        // 操作
        case .cancel:
            handleCancel()
            
        case .confirm:
            handleConfirm(mode: .temporary)
            
        case .pin:
            handleConfirm(mode: .pin)
            
        case .copy:
            handleConfirm(mode: .copy)
        }
    }
    
    /// 选择标注工具
    private func selectTool(_ tool: AnnotationCanvasView.Tool, action: ScreenshotToolbarView.ToolbarAction) {
        let currentTool = selectionView.currentAnnotationTool
        
        if currentTool == tool {
            // 再次点击相同工具，取消选择
            selectionView.setAnnotationTool(.none)
            toolbarView?.deselectAllTools()
        } else {
            // 选择新工具
            selectionView.setAnnotationTool(tool)
            toolbarView?.setSelected(action, selected: true)
        }
    }
    
    // MARK: - Selection Handling
    
    private func handleConfirm(mode: ConfirmMode) {
        let rect = selectionView.selectionRect
        guard rect.width > 10 && rect.height > 10 else {
            handleCancel()
            return
        }
        
        // 获取带标注的图片
        guard let annotatedImage = selectionView.getAnnotatedImage() else {
            // 回退到普通裁剪
            guard let bgImage = fullScreenImage else {
                handleCancel()
                return
            }
            let croppedImage = cropImage(bgImage, to: rect)
            dismiss()
            onComplete?(rect, croppedImage, mode)
            return
        }
        
        dismiss()
        onComplete?(rect, annotatedImage, mode)
    }
    
    private func handleCancel() {
        dismiss()
        onCancel?()
    }
    
    /// 裁剪图片
    private func cropImage(_ image: NSImage, to viewRect: CGRect) -> NSImage {
        let imageRect = viewRect
        
        let croppedImage = NSImage(size: viewRect.size)
        croppedImage.lockFocus()
        
        image.draw(
            in: CGRect(origin: .zero, size: viewRect.size),
            from: imageRect,
            operation: .copy,
            fraction: 1.0
        )
        
        croppedImage.unlockFocus()
        return croppedImage
    }
    
    // MARK: - Key Events
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    // 快捷键支持
    override func keyDown(with event: NSEvent) {
        let hasCmd = event.modifierFlags.contains(.command)
        let hasShift = event.modifierFlags.contains(.shift)
        let char = event.charactersIgnoringModifiers?.lowercased()
        
        // Cmd+Z = Undo
        if hasCmd && !hasShift && char == "z" {
            selectionView.undoAnnotation()
            return
        }
        
        // Cmd+Shift+Z = Redo
        if hasCmd && hasShift && char == "z" {
            selectionView.redoAnnotation()
            return
        }
        
        // Cmd+P = Pin
        if hasCmd && char == "p" {
            handleConfirm(mode: .pin)
            return
        }
        
        // Cmd+C = Copy
        if hasCmd && char == "c" {
            handleConfirm(mode: .copy)
            return
        }

        // C (No modifiers) = Copy Color
        if !hasCmd && !hasShift && char == "c" {
            selectionView.copyCurrentColor()
            return
        }

        // 标注工具快捷键 (无修饰键)
        if !hasCmd && !hasShift {
            switch char {
            case "a":
                selectTool(.arrow, action: .arrow)
                return
            case "b":
                selectTool(.pen, action: .pen)
                return
            case "m":
                selectTool(.marker, action: .marker)
                return
            case "t":
                selectTool(.text, action: .text)
                return
            case "e":
                selectTool(.eraser, action: .eraser)
                return
            default:
                break
            }
        }
        
        super.keyDown(with: event)
    }
}
