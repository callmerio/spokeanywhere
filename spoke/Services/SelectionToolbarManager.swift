import AppKit
import SwiftUI
import Combine
import OSLog

private let logger = Logger(subsystem: "com.spokeanywhere", category: "SelectionToolbarManager")

/// 选择工具栏窗口管理器
@MainActor
final class SelectionToolbarManager {
    
    // MARK: - Singleton
    
    static let shared = SelectionToolbarManager()
    
    // MARK: - Properties
    
    /// 工具栏窗口
    private(set) var toolbarWindow: NSPanel?
    
    /// 结果面板窗口
    private var resultWindow: NSPanel?
    
    /// 状态管理
    private let state = SelectionToolbarState.shared
    
    /// 选择监听服务
    private let selectionMonitor = SelectionMonitorService.shared
    
    /// 订阅
    private var cancellables = Set<AnyCancellable>()
    
    /// 自动隐藏定时器
    private var autoHideTimer: Timer?
    
    /// 词典结果自动隐藏定时器（2秒无 hover 后隐藏）
    private var dictionaryAutoHideTimer: Timer?
    
    /// hover 检测定时器
    private var hoverCheckTimer: Timer?
    
    /// 点击外部监听器
    private var clickOutsideMonitor: Any?
    
    /// 🔥 显示保护期：show() 后短暂禁止 hide()，防止 localMouseUpMonitor 立即隐藏
    private var showProtectionEndTime: Date = .distantPast
    private let showProtectionDuration: TimeInterval = 0.3  // 300ms 保护期
    
    /// 🔥 动作执行中标志：执行查词等动作时阻止隐藏
    private(set) var isExecutingAction: Bool = false
    
    // MARK: - Constants
    
    private enum Layout {
        static let toolbarHeight: CGFloat = 44 // Updated to match new UI
        static let toolbarMinWidth: CGFloat = 100 // Reduced min width
        static let toolbarMaxWidth: CGFloat = 800 // Increased max width
        static let toolbarCornerRadius: CGFloat = 12
        static let toolbarOffsetY: CGFloat = 8
        static let screenEdgePadding: CGFloat = 10
    }
    
    // MARK: - Init
    
    private init() {
        setupBindings()
        setupSelectionMonitor()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // 监听状态变化
        state.$phase
            .receive(on: DispatchQueue.main)
            .sink { [weak self] phase in
                self?.handlePhaseChange(phase)
            }
            .store(in: &cancellables)
            
        // 监听配置变化，重新计算尺寸
        // 注意：SelectionToolbarState 可能需要发送通知或 publisher 当配置变化时
        // 这里暂时依赖 show(at:) 每次调用时的 resize
    }
    
    private func setupSelectionMonitor() {
        logger.info("📋 [ToolbarManager] setupSelectionMonitor() 设置回调")
        selectionMonitor.onSelectionChanged = { [weak self] context in
            logger.info("📋 [ToolbarManager] onSelectionChanged 回调触发: \(context.selectedText.prefix(30))...")
            self?.handleSelectionChanged(context)
        }
    }
    
    // MARK: - Public API
    
    /// 启动服务
    func start() {
        print("📋 [ToolbarManager] start() 被调用")
        
        // 检查辅助功能权限
        if !selectionMonitor.isAccessibilityEnabled {
            print("📋 [ToolbarManager] ❌ 未授权辅助功能权限，显示提示")
            showAccessibilityPermissionAlert()
            return
        }
        
        selectionMonitor.startMonitoring()
        print("📋 [ToolbarManager] ✅ 服务已启动")
        logger.info("📋 [ToolbarManager] 服务已启动")
    }
    
    /// 显示辅助功能权限提示
    private func showAccessibilityPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = "选择工具栏需要辅助功能权限才能检测文本选择。\n\n请在「系统设置 → 隐私与安全性 → 辅助功能」中授权 SpokenAnyWhere。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // 打开系统设置的辅助功能页面
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
            
            // 开始轮询检查权限状态
            startPermissionPolling()
        }
    }
    
    /// 开始轮询检查权限状态
    private func startPermissionPolling() {
        // 每秒检查一次权限，授权后自动启动
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                
                if self.selectionMonitor.isAccessibilityEnabled {
                    timer.invalidate()
                    print("📋 [ToolbarManager] ✅ 权限已授予，自动启动服务")
                    self.selectionMonitor.startMonitoring()
                }
            }
        }
    }
    
    /// 停止服务
    func stop() {
        selectionMonitor.stopMonitoring()
        hide()
        logger.info("📋 [ToolbarManager] 服务已停止")
    }
    
    /// 显示工具栏
    /// position: AppKit 坐标系下工具栏中心点的目标位置
    func show(at position: CGPoint) {
        logger.info("📋 [ToolbarManager] show(at:) 开始 | position: (\(position.x), \(position.y))")
        
        // 如果窗口不存在，创建它
        if toolbarWindow == nil {
            logger.info("📋 [ToolbarManager] 创建新窗口...")
            createToolbarWindow()
        }
        
        guard let window = toolbarWindow, let contentView = window.contentView else {
            logger.error("❌ [ToolbarManager] 窗口创建失败!")
            return
        }
        
        // 强制布局以获取正确尺寸
        contentView.needsLayout = true
        contentView.layoutSubtreeIfNeeded()
        let fittingSize = contentView.fittingSize
        
        // 确保尺寸合理
        let newSize = NSSize(
            width: max(Layout.toolbarMinWidth, min(fittingSize.width, Layout.toolbarMaxWidth)),
            height: Layout.toolbarHeight
        )
        
        if window.frame.size != newSize {
            logger.info("📋 [ToolbarManager] 调整窗口尺寸: \(String(describing: fittingSize)) -> \(String(describing: newSize))")
            window.setContentSize(newSize)
        }
        
        // 计算窗口左下角位置 (AppKit 窗口原点在左下角)
        var origin = CGPoint(
            x: position.x - newSize.width / 2,  // 水平居中
            y: position.y - newSize.height      // 工具栏顶部在目标位置
        )
        
        // 🔥 找到包含目标位置的屏幕（而非 NSScreen.main，支持多屏幕）
        let targetScreen = NSScreen.screens.first { screen in
            screen.frame.contains(position)
        } ?? NSScreen.main
        
        if let screen = targetScreen {
            let screenFrame = screen.visibleFrame
            
            // 左边界
            if origin.x < screenFrame.minX + Layout.screenEdgePadding {
                origin.x = screenFrame.minX + Layout.screenEdgePadding
            }
            // 右边界
            if origin.x + newSize.width > screenFrame.maxX - Layout.screenEdgePadding {
                origin.x = screenFrame.maxX - Layout.screenEdgePadding - newSize.width
            }
            // 下边界
            if origin.y < screenFrame.minY + Layout.screenEdgePadding {
                origin.y = screenFrame.minY + Layout.screenEdgePadding
            }
            // 上边界
            if origin.y + newSize.height > screenFrame.maxY - Layout.screenEdgePadding {
                origin.y = screenFrame.maxY - Layout.screenEdgePadding - newSize.height
            }
        }
        
        logger.info("📋 [ToolbarManager] 窗口原点: (\(origin.x), \(origin.y))")
        
        // 设置位置并显示
        window.setFrameOrigin(origin)
        window.orderFrontRegardless()
        
        logger.info("✅ [ToolbarManager] 窗口已显示 | frame: \(String(describing: window.frame))")
        
        // 🔥 设置显示保护期，防止 localMouseUpMonitor 立即触发 hide()
        showProtectionEndTime = Date().addingTimeInterval(showProtectionDuration)
        
        // 设置点击外部关闭
        setupClickOutsideMonitor()
        
        // 启动自动隐藏定时器
        startAutoHideTimer()
    }
    
    /// 隐藏工具栏
    /// - Parameter force: 是否强制隐藏（忽略保护期和动作执行状态）
    func hide(force: Bool = false) {
        // 🔥 检查保护期：如果还在保护期内且非强制隐藏，跳过
        if !force && Date() < showProtectionEndTime {
            logger.debug("📋 [ToolbarManager] 跳过隐藏（保护期内）")
            return
        }
        
        // 🔥 检查动作执行状态：如果正在执行动作且非强制隐藏，跳过
        if !force && isExecutingAction {
            logger.debug("📋 [ToolbarManager] 跳过隐藏（动作执行中）")
            return
        }
        
        // 🔥 检查词典结果显示状态：如果正在显示词典结果且非强制隐藏，跳过
        if !force && state.phase == .showingDictionary {
            logger.debug("📋 [ToolbarManager] 跳过隐藏（词典结果显示中）")
            return
        }
        
        toolbarWindow?.orderOut(nil)
        resultWindow?.orderOut(nil)
        
        removeClickOutsideMonitor()
        stopAutoHideTimer()
        
        state.hide()
        // 注意：不清空 lastSelectedText，避免相同文本再次触发工具栏
        // selectionMonitor.clearLastSelection() 只在切换应用或文本真正变化时调用
        
        logger.debug("📋 [ToolbarManager] 隐藏工具栏")
    }
    
    /// 开始执行动作（阻止隐藏）
    func beginAction() {
        isExecutingAction = true
        stopAutoHideTimer()  // 执行动作期间停止自动隐藏
        logger.debug("📋 [ToolbarManager] 开始执行动作")
    }
    
    /// 结束执行动作
    func endAction() {
        isExecutingAction = false
        logger.debug("📋 [ToolbarManager] 结束执行动作")
    }
    
    /// 获取工具栏窗口底部中心位置（用于在其下方显示面板）
    /// 返回 AppKit 坐标系下的位置（左下角原点）
    var toolbarBottomCenter: CGPoint? {
        guard let window = toolbarWindow, window.isVisible else { return nil }
        let frame = window.frame
        return CGPoint(x: frame.midX, y: frame.minY)
    }
    
    /// 检查辅助功能权限
    func checkAccessibilityPermission() -> Bool {
        return selectionMonitor.isAccessibilityEnabled
    }
    
    /// 请求辅助功能权限
    func requestAccessibilityPermission() {
        selectionMonitor.requestAccessibilityPermission()
    }
    
    // MARK: - Private Methods
    
    /// 创建工具栏窗口
    private func createToolbarWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Layout.toolbarMinWidth, height: Layout.toolbarHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false  // 禁用系统方框阴影，用 SwiftUI 自定义阴影
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        
        // 设置 SwiftUI 内容
        let contentView = SelectionToolbarView()
            .environmentObject(state)
        
        panel.contentView = NSHostingView(rootView: contentView)
        
        toolbarWindow = panel
        
        logger.debug("📋 [ToolbarManager] 工具栏窗口已创建")
    }
    
    /// 处理选中文本变化
    private func handleSelectionChanged(_ context: SelectionContext) {
        logger.info("📋 [ToolbarManager] handleSelectionChanged | bounds: \(String(describing: context.selectionBounds))")
        
        // 显示工具栏
        state.show(with: context)
        
        let position: CGPoint
        let bounds = context.selectionBounds
        
        // 优先使用选中文本位置（而非鼠标位置）
        // selectionBounds 是 Quartz 坐标系 (左上角原点, Y 向下)
        // NSPanel.show(at:) 期望 AppKit 坐标系 (左下角原点, Y 向上)
        // 注意：show(at:) 中 origin.y = position.y - height，所以 position 是工具栏顶部位置
        // 我们需要工具栏底部在选中文本上方，所以 position = selectionTop + toolbarHeight + offset
        if bounds != .zero && bounds.width > 0 && bounds.height > 0 {
            if let screen = NSScreen.main {
                // Quartz → AppKit 坐标转换
                // Quartz bounds.minY = 选中区域顶部 (距屏幕顶部的距离)
                // AppKit Y = screen.height - bounds.minY = 选中区域顶部在 AppKit 中的位置
                let selectionTopInAppKit = screen.frame.height - bounds.minY
                // 工具栏顶部位置 = 选中文本顶部 + 工具栏高度 + 间距
                // 这样工具栏底部就在选中文本上方 offset 像素处
                position = CGPoint(
                    x: bounds.midX,
                    y: selectionTopInAppKit + Layout.toolbarHeight + Layout.toolbarOffsetY
                )
                logger.info("📋 [ToolbarManager] 使用 selectionBounds | Quartz(\(bounds.midX), \(bounds.minY)) → AppKit(\(position.x), \(position.y))")
            } else {
                let mouseLocation = NSEvent.mouseLocation
                position = CGPoint(x: mouseLocation.x, y: mouseLocation.y + Layout.toolbarHeight + Layout.toolbarOffsetY)
                logger.info("📋 [ToolbarManager] 无屏幕，fallback 鼠标: (\(position.x), \(position.y))")
            }
        } else {
            // Fallback: selectionBounds 无效时使用鼠标位置
            let mouseLocation = NSEvent.mouseLocation
            position = CGPoint(x: mouseLocation.x, y: mouseLocation.y + Layout.toolbarHeight + Layout.toolbarOffsetY)
            logger.info("📋 [ToolbarManager] bounds 无效，fallback 鼠标: (\(position.x), \(position.y))")
        }
        
        show(at: position)
    }
    
    /// 处理阶段变化
    private func handlePhaseChange(_ phase: SelectionToolbarPhase) {
        switch phase {
        case .idle:
            // 隐藏窗口
            toolbarWindow?.orderOut(nil)
            resultWindow?.orderOut(nil)
            
        case .showing:
            // 工具栏已显示
            break
            
        case .executing:
            // 执行动作中，停止自动隐藏
            stopAutoHideTimer()
            
        case .showingResult:
            // 显示结果面板
            showResultPanel()
            
        case .showingDictionary:
            // 工具栏原地变换显示词典结果，启动词典自动隐藏定时器
            stopAutoHideTimer()
            startDictionaryAutoHideTimer()
        }
    }
    
    /// 显示结果面板
    private func showResultPanel() {
        // TODO: 实现结果面板
        logger.debug("📋 [ToolbarManager] 显示结果面板")
    }
    
    /// 设置点击外部关闭监听
    private func setupClickOutsideMonitor() {
        removeClickOutsideMonitor()
        
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self,
                  let window = self.toolbarWindow,
                  window.isVisible else {
                return
            }
            
            // 检查点击是否在窗口外
            let windowFrame = window.frame
            let screenLocation = NSEvent.mouseLocation
            
            if !windowFrame.contains(screenLocation) {
                Task { @MainActor in
                    self.hide(force: true)  // 🔥 点击外部强制隐藏（包括词典结果）
                }
            }
        }
    }
    
    /// 移除点击外部监听
    private func removeClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
    }
    
    /// 启动自动隐藏定时器
    private func startAutoHideTimer() {
        stopAutoHideTimer()
        
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: state.config.autoHideDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hide()
            }
        }
    }
    
    /// 停止自动隐藏定时器
    private func stopAutoHideTimer() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
    }
    
    /// 重置自动隐藏定时器
    func resetAutoHideTimer() {
        startAutoHideTimer()
    }
    
    // MARK: - Dictionary Auto Hide
    
    /// 启动词典自动隐藏定时器（2秒无 hover 后隐藏）
    private func startDictionaryAutoHideTimer() {
        stopDictionaryAutoHideTimer()
        
        // 启动 hover 检测
        startHoverCheckTimer()
        
        dictionaryAutoHideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.checkAndHideDictionary()
            }
        }
    }
    
    /// 停止词典自动隐藏定时器
    private func stopDictionaryAutoHideTimer() {
        dictionaryAutoHideTimer?.invalidate()
        dictionaryAutoHideTimer = nil
        stopHoverCheckTimer()
    }
    
    /// 启动 hover 检测定时器
    private func startHoverCheckTimer() {
        stopHoverCheckTimer()
        
        hoverCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkHoverState()
            }
        }
    }
    
    /// 停止 hover 检测定时器
    private func stopHoverCheckTimer() {
        hoverCheckTimer?.invalidate()
        hoverCheckTimer = nil
    }
    
    /// 检查 hover 状态，如果正在 hover 则重置定时器
    private func checkHoverState() {
        guard let window = toolbarWindow, window.isVisible else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        let windowFrame = window.frame
        
        // 如果鼠标在窗口内，重置词典自动隐藏定时器
        if windowFrame.contains(mouseLocation) {
            dictionaryAutoHideTimer?.invalidate()
            dictionaryAutoHideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.checkAndHideDictionary()
                }
            }
        }
    }
    
    /// 检查并隐藏词典结果
    private func checkAndHideDictionary() {
        guard let window = toolbarWindow, window.isVisible else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        let windowFrame = window.frame
        
        // 如果鼠标不在窗口内，隐藏
        if !windowFrame.contains(mouseLocation) {
            stopDictionaryAutoHideTimer()
            hide()
            logger.debug("📋 [ToolbarManager] 词典结果自动隐藏（2秒无 hover）")
        }
    }
}
