import AppKit
import ApplicationServices
import Combine
import OSLog

private let logger = Logger(subsystem: "com.spokeanywhere", category: "SelectionMonitor")

@MainActor
struct SelectionMonitorServiceDependencies {
    let workspace: NSWorkspace
    let hasAccessibilityPermission: () -> Bool
    let requestAccessibilityPermission: () -> Bool
    let toolbarWindow: () -> NSPanel?
    let hideToolbar: (_ force: Bool) -> Void
}

private enum MouseMonitorSource {
    case global
    case local

    var doubleClickSource: String {
        switch self {
        case .global:
            "Global doubleClick"
        case .local:
            "Local doubleClick"
        }
    }

    var mouseUpSource: String {
        switch self {
        case .global:
            "Global mouseUp"
        case .local:
            "Local mouseUp"
        }
    }

    var shouldForceHideToolbar: Bool {
        self == .local
    }

    var shouldIgnoreToolbarClicks: Bool {
        self == .local
    }
}

/// 全局文本选择监听服务
/// 使用 macOS Accessibility API 监听系统范围内的文本选择
@MainActor
final class SelectionMonitorService {
    
    // MARK: - Singleton
    
    static let shared = SelectionMonitorService(dependencies: .makeLive())
    
    // MARK: - Properties
    private let dependencies: SelectionMonitorServiceDependencies
    
    /// 是否正在监听
    private(set) var isMonitoring = false
    
    /// 是否已授权辅助功能权限
    var isAccessibilityEnabled: Bool {
        dependencies.hasAccessibilityPermission()
    }
    
    /// 选中文本变化回调
    var onSelectionChanged: ((SelectionContext) -> Void)?
    
    /// 防抖定时器
    private var debounceTimer: Timer?
    
    /// 防抖延迟 (秒)
    private let debounceDelay: TimeInterval = 0.15
    
    /// 最小选中文本长度
    private let minSelectionLength = 1
    
    /// 最大选中文本长度
    private let maxSelectionLength = 10000
    
    /// 上次选中的文本 (用于去重)
    private var lastSelectedText: String?
    
    /// AX 通知防抖时间戳 (用于去重连续通知)
    private var lastAXNotificationTime: CFAbsoluteTime = 0
    
    /// AX 通知防抖阈值 (秒) - 同一时间窗口内的重复通知会被忽略
    private let axNotificationDebounceThreshold: CFAbsoluteTime = 0.05
    
    /// 全局鼠标事件监听器
    private var mouseEventMonitor: Any?
    
    /// 键盘事件监听器
    private var keyEventMonitor: Any?
    
    /// 鼠标按下监听器 (Global)
    private var mouseDownMonitor: Any?
    
    /// 鼠标按下监听器 (Local - 自身 App)
    private var localMouseDownMonitor: Any?
    
    /// 鼠标抬起监听器 (Local - 自身 App)
    private var localMouseUpMonitor: Any?
    
    /// 鼠标是否按下 (用于判断是否在选择过程中)
    private var isMouseDown = false
    
    /// 鼠标按下位置 (用于区分拖动选择和单击)
    private var mouseDownLocation: CGPoint = .zero
    
    /// 判定为拖动的最小距离 (像素)
    private let dragThreshold: CGFloat = 5
    
    /// 🔥 最后一次点击的 clickCount (用于过滤双击)
    private var lastClickCount: Int = 0
    
    /// 🔥 最后一次点击的时间戳
    private var lastClickTime: CFAbsoluteTime = 0
    
    /// 🔥 双击冷却期阈值 (秒) - 双击后这段时间内忽略 AX 通知
    private let doubleClickCooldownThreshold: CFAbsoluteTime = 0.5
    
    /// 🔥 是否刚发生了鼠标拖动选择 (用于过滤打字触发的 AX 通知)
    private var didRecentMouseDrag: Bool = false
    
    /// 🔥 鼠标拖动选择的有效时间窗口 (秒) - 超过此时间的 AX 通知将被忽略
    private let mouseDragValidWindow: CFAbsoluteTime = 0.3
    
    /// 🔥 最后一次鼠标拖动选择的时间
    private var lastMouseDragTime: CFAbsoluteTime = 0
    
    /// AXObserver 实例 (用于监听选择变化通知)
    private var axObserver: AXObserver?
    
    /// 当前监听的应用 PID
    private var currentObservedPid: pid_t = 0
    
    /// 应用切换观察者
    private var appActivationObserver: NSObjectProtocol?
    
    /// 忽略的应用 Bundle ID (不在这些应用中显示工具栏)
    private let ignoredBundleIds: Set<String> = [
        "com.apple.loginwindow",
        "com.apple.screencaptureui"
    ]
    
    /// 自身应用的 Bundle ID
    private let selfBundleId = Bundle.main.bundleIdentifier ?? AppIdentity.bundleIdentifier
    
    // MARK: - Init
    
    private init(
        dependencies: SelectionMonitorServiceDependencies
    ) {
        self.dependencies = dependencies
    }
    
    // MARK: - Public API
    
    /// 开始监听
    func startMonitoring(requestPermissionIfNeeded: Bool = false) {
        logger.info("📋 [SelectionMonitor] startMonitoring() 被调用")

        guard !isMonitoring else {
            logger.debug("📋 [SelectionMonitor] 已在监听中，跳过")
            return
        }

        // 检查辅助功能权限
        let hasPermission = isAccessibilityEnabled
        logger.info("📋 [SelectionMonitor] 辅助功能权限: \(hasPermission)")

        guard hasPermission else {
            logger.warning("📋 [SelectionMonitor] ❌ 未授权辅助功能权限")
            if requestPermissionIfNeeded {
                requestAccessibilityPermission()
            }
            return
        }

        isMonitoring = true

        // 设置鼠标和键盘监听 (作为 fallback)
        setupMouseMonitor()
        setupKeyboardMonitor()

        // 设置应用切换监听
        setupAppActivationObserver()

        // 为当前前台应用设置 AXObserver
        updateAXObserverForFrontmostApp()

        logger.info("📋 [SelectionMonitor] ✅ 开始监听文本选择 (AXObserver + 鼠标/键盘)")
    }
    
    /// 停止监听
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        
        // 移除鼠标监听 (Global)
        removeMonitor(&mouseDownMonitor)
        removeMonitor(&mouseEventMonitor)
        
        // 移除鼠标监听 (Local)
        removeMonitor(&localMouseDownMonitor)
        removeMonitor(&localMouseUpMonitor)
        
        isMouseDown = false
        
        // 移除键盘监听
        removeMonitor(&keyEventMonitor)
        
        // 移除 AXObserver
        removeCurrentAXObserver()
        
        // 移除应用切换观察者
        if let observer = appActivationObserver {
            dependencies.workspace.notificationCenter.removeObserver(observer)
            appActivationObserver = nil
        }
        
        invalidateSelectionMonitorTimer(&debounceTimer)
        
        logger.info("📋 [SelectionMonitor] 停止监听")
    }
    
    /// 请求辅助功能权限
    func requestAccessibilityPermission() {
        _ = dependencies.requestAccessibilityPermission()
        logger.info("📋 [SelectionMonitor] 已请求辅助功能权限")
    }
    
    /// 手动触发检查选中文本
    /// - Parameter source: 触发来源（用于调试）
    func checkSelection(source: String = "unknown") {
        guard isMonitoring else {
            logger.debug("📋 [SelectionMonitor] checkSelection 跳过: isMonitoring=false")
            return
        }
        
        // 🔥 诊断：记录触发来源
        logger.debug("📋 [SelectionMonitor] checkSelection 触发 (source=\(source))")
        
        invalidateSelectionMonitorTimer(&debounceTimer)
        debounceTimer = makeSelectionMonitorDebounceTimer(interval: debounceDelay, owner: self) { service in
            service.performSelectionCheck()
        }
    }
    
    // MARK: - Private Methods
    
    // MARK: AXObserver 相关
    
    /// 设置应用切换监听
    private func setupAppActivationObserver() {
        appActivationObserver = dependencies.workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            runSelectionMonitorOnMain(self) { service in
                service.updateAXObserverForFrontmostApp()
            }
        }
        logger.debug("📋 [SelectionMonitor] 应用切换监听已设置")
    }
    
    /// 为当前前台应用设置 AXObserver
    private func updateAXObserverForFrontmostApp() {
        guard let frontApp = dependencies.workspace.frontmostApplication else {
            logger.debug("📋 [SelectionMonitor] 无前台应用")
            return
        }
        
        let pid = frontApp.processIdentifier
        let bundleId = frontApp.bundleIdentifier ?? ""
        
        // 如果是同一个应用，不需要重新设置
        if pid == currentObservedPid {
            return
        }
        
        // 忽略特定应用
        if ignoredBundleIds.contains(bundleId) {
            logger.debug("📋 [SelectionMonitor] 忽略应用: \(bundleId)")
            removeCurrentAXObserver()
            return
        }
        
        logger.info("📋 [SelectionMonitor] 切换到应用: \(frontApp.localizedName ?? "unknown") (pid: \(pid))")
        
        // 移除旧的观察者
        removeCurrentAXObserver()
        
        // 创建新的 AXObserver
        var observer: AXObserver?
        let error = AXObserverCreate(pid, axObserverCallback, &observer)
        
        guard error == .success, let observer = observer else {
            logger.warning("📋 [SelectionMonitor] AXObserverCreate 失败: \(error.rawValue)")
            // 某些应用可能不支持此通知，继续使用鼠标/键盘监听
            return
        }
        
        // 获取应用的 AXUIElement
        let appElement = AXUIElementCreateApplication(pid)
        
        // 添加选择变化通知监听
        let addResult = AXObserverAddNotification(
            observer,
            appElement,
            kAXSelectedTextChangedNotification as CFString,
            Unmanaged.passUnretained(self).toOpaque()
        )
        
        if addResult != .success {
            logger.warning("📋 [SelectionMonitor] AXObserverAddNotification 失败: \(addResult.rawValue)")
            // 某些应用可能不支持此通知，继续使用鼠标/键盘监听
        }
        
        // 添加到 RunLoop
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )
        
        axObserver = observer
        currentObservedPid = pid
        
        logger.info("📋 [SelectionMonitor] ✅ AXObserver 已设置 (pid: \(pid))")
    }
    
    /// 移除当前 AXObserver
    private func removeCurrentAXObserver() {
        if let observer = axObserver {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
            axObserver = nil
            currentObservedPid = 0
            logger.debug("📋 [SelectionMonitor] AXObserver 已移除")
        }
    }
    
    /// AXObserver 回调处理 (需要被回调函数访问，不能是 private)
    func handleAXNotification() {
        // 防抖：忽略短时间内的重复通知
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastAXNotificationTime > axNotificationDebounceThreshold else {
            return
        }
        lastAXNotificationTime = now
        
        // 如果鼠标正在按下 (用户正在拖动选择)，忽略此通知
        guard !isMouseDown else {
            return
        }
        
        // 🔥 核心修复：只有在最近发生了鼠标拖动选择时才响应 AX 通知
        // 这样可以过滤掉打字、键盘移动光标等导致的文本选择变化
        let timeSinceDrag = now - lastMouseDragTime
        guard didRecentMouseDrag && timeSinceDrag < mouseDragValidWindow else {
            // 没有最近的鼠标拖动，忽略此 AX 通知（可能是打字触发的）
            return
        }
        
        // 🔥 注：已在 mouseUp 中正确处理双击选中，此处不再过滤
        
        // 重置拖动标志（已处理）
        didRecentMouseDrag = false
        
        // 调用检查，标记来源
        logger.debug("📋 [SelectionMonitor] AX 通知触发 checkSelection (拖动后 \(String(format: "%.3f", timeSinceDrag))s)")
        checkSelection(source: "AX")
    }
    
    // MARK: 鼠标/键盘监听
    
    /// 设置鼠标事件监听
    private func setupMouseMonitor() {
        // === Global Monitor (监听其他 App) ===
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            runSelectionMonitorOnMain(self) { service in
                service.handleMouseDown(clickCount: event.clickCount)
            }
        }
        
        mouseEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            runSelectionMonitorOnMain(self) { service in
                service.handleMouseUp(source: .global)
            }
        }
        
        // === Local Monitor (监听自身 App) ===
        localMouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            runSelectionMonitorOnMain(self) { service in
                service.handleMouseDown(clickCount: event.clickCount)
            }
            return event
        }
        
        localMouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            runSelectionMonitorOnMain(self) { service in
                service.handleMouseUp(source: .local)
            }
            return event
        }
        
        logger.debug("🖱️ [SelectionMonitor] 鼠标监听器已设置 (Global + Local)")
    }
    
    /// 设置键盘事件监听
    private func setupKeyboardMonitor() {
        // 监听键盘事件 (Shift+方向键选择)
        keyEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyUp]) { [weak self] event in
            // 检查是否是选择相关的按键 (Shift + 方向键)
            let isShiftPressed = event.modifierFlags.contains(.shift)
            let isArrowKey = [123, 124, 125, 126].contains(Int(event.keyCode)) // 方向键
            let isSelectAll = event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "a"
            
            if isShiftPressed && isArrowKey || isSelectAll {
                runSelectionMonitorOnMain(self) { service in
                    service.checkSelection(source: "Keyboard")
                }
            }
        }
    }
    
    /// 执行选中文本检查
    private func performSelectionCheck() {
        // 获取当前聚焦的应用
        guard let frontApp = dependencies.workspace.frontmostApplication else {
            return
        }
        
        let bundleId = frontApp.bundleIdentifier ?? ""
        let appName = frontApp.localizedName
        
        // 忽略特定应用
        if ignoredBundleIds.contains(bundleId) {
            return
        }
        
        // 🔥 忽略自身应用（Dictionary Panel 等 UI 打字会触发 AX 通知）
        if bundleId == selfBundleId {
            logger.debug("📋 [SelectionMonitor] 跳过自身应用的选择检查")
            return
        }
        
        // 🔥 方案 C: 耗时的 AX 遍历移到后台线程，避免卡死主线程
        // AXUIElementCopyAttributeValue 是同步 IPC 调用，复杂 UI 应用（Chrome/Electron）会很慢
        runSelectionMonitorAXQuery(
            frontApp: frontApp,
            bundleId: bundleId,
            appName: appName,
            loadSelection: { [weak self] app in
                self?.getSelectedTextAndBounds(for: app)
            },
            onResult: { [weak self] selectedText, bounds, bundleId, appName in
                self?.handleSelectionResult(selectedText, bounds: bounds, bundleId: bundleId, appName: appName)
            }
        )
    }

    private func handleMouseDown(clickCount: Int) {
        isMouseDown = true
        mouseDownLocation = NSEvent.mouseLocation
        lastClickCount = clickCount
        lastClickTime = CFAbsoluteTimeGetCurrent()
    }

    private func handleMouseUp(source: MouseMonitorSource) {
        isMouseDown = false

        let mouseUpLocation = NSEvent.mouseLocation
        let distance = hypot(
            mouseUpLocation.x - mouseDownLocation.x,
            mouseUpLocation.y - mouseDownLocation.y
        )

        if source.shouldIgnoreToolbarClicks,
           selectionMonitorToolbarContainsMouse(
               dependencies.toolbarWindow(),
               at: mouseUpLocation
           ) {
            return
        }

        if distance < dragThreshold {
            if lastClickCount >= 2 {
                checkSelection(source: source.doubleClickSource)
            } else {
                dependencies.hideToolbar(source.shouldForceHideToolbar)
            }
            didRecentMouseDrag = false
            return
        }

        didRecentMouseDrag = true
        lastMouseDragTime = CFAbsoluteTimeGetCurrent()
        checkSelection(source: source.mouseUpSource)
    }

    private func removeMonitor(_ monitor: inout Any?) {
        guard let existingMonitor = monitor else { return }
        NSEvent.removeMonitor(existingMonitor)
        monitor = nil
    }
    
    /// 🔥 处理选中结果（主线程调用）
    private func handleSelectionResult(_ selectedText: String, bounds: CGRect, bundleId: String, appName: String?) {
        // 验证文本长度
        let trimmedText = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.count >= minSelectionLength,
              trimmedText.count <= maxSelectionLength else {
            return
        }
        
        // 🔥 方案 C: 增强内容验证 - 过滤无意义的选中内容
        // 1. 纯空白字符（空格、制表符、换行等）
        // 2. 纯标点符号
        // 3. 单个字符且非字母数字（如单个符号）
        if !isValidSelection(trimmedText) {
            logger.debug("📋 [SelectionMonitor] 跳过无意义的选中内容: '\(trimmedText.prefix(20))'")
            return
        }
        
        // 不再做去重检查，用户可能想对相同文本再次操作
        // 去重逻辑已移除，每次选择都触发工具栏
        
        // 创建上下文
        let context = SelectionContext(
            selectedText: trimmedText,
            selectionBounds: bounds,
            sourceAppBundleId: bundleId,
            sourceAppName: appName
        )
        
        logger.info("📋 [SelectionMonitor] 检测到选中文本 | 长度: \(trimmedText.count) | 应用: \(appName ?? "unknown")")
        
        // 回调
        onSelectionChanged?(context)
    }
    
    /// 使用 Accessibility API 获取选中文本和位置
    /// 🔥 nonisolated: 允许在后台线程调用
    nonisolated private func getSelectedTextAndBounds(for app: NSRunningApplication) -> (String, CGRect)? {
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        
        // 关键：为 Electron/Chrome 等应用启用 Accessibility
        // 这些应用默认不暴露 AX tree，需要设置特殊属性
        enableAccessibilityForApp(appElement)

        guard let axElement = focusedElement(for: appElement) else {
            return nil
        }

        guard let text = selectedText(from: axElement), !text.isEmpty else {
            return nil
        }

        let bounds = selectionBounds(for: axElement) ?? fallbackSelectionBounds()
        return (text, bounds)
    }

    nonisolated private func focusedElement(for appElement: AXUIElement) -> AXUIElement? {
        focusedElementFromSystemWide() ?? focusedElementFromApplication(appElement)
    }

    nonisolated private func focusedElementFromSystemWide() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        let appResult = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        guard appResult == .success,
              let appElement = asAXUIElement(focusedApp) else {
            return nil
        }

        return focusedUIElement(from: appElement)
    }

    nonisolated private func focusedElementFromApplication(_ appElement: AXUIElement) -> AXUIElement? {
        focusedUIElement(from: appElement)
    }

    nonisolated private func focusedUIElement(from appElement: AXUIElement) -> AXUIElement? {
        var focusedUIElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedUIElement
        )
        guard result == .success else { return nil }
        return asAXUIElement(focusedUIElement)
    }

    nonisolated private func selectedText(from axElement: AXUIElement) -> String? {
        selectedTextFromDirectAttribute(axElement)
            ?? selectedTextFromParameterizedRange(axElement)
            ?? selectedTextFromValueRange(axElement)
            ?? selectedTextFromParent(axElement)
            ?? findSelectedTextInChildren(axElement, depth: 0)
    }

    nonisolated private func selectedTextFromDirectAttribute(_ axElement: AXUIElement) -> String? {
        var selectedTextValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axElement, kAXSelectedTextAttribute as CFString, &selectedTextValue)
        guard result == .success,
              let text = selectedTextValue as? String,
              !text.isEmpty else {
            return nil
        }
        return text
    }

    nonisolated private func selectedTextFromParameterizedRange(_ axElement: AXUIElement) -> String? {
        guard let rangeValue = selectedRangeValue(from: axElement),
              let range = cfRange(from: rangeValue),
              range.length > 0 else {
            return nil
        }

        var stringForRangeValue: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(
            axElement,
            kAXStringForRangeParameterizedAttribute as CFString,
            rangeValue,
            &stringForRangeValue
        )
        guard result == .success,
              let text = stringForRangeValue as? String,
              !text.isEmpty else {
            return nil
        }
        return text
    }

    nonisolated private func selectedTextFromValueRange(_ axElement: AXUIElement) -> String? {
        var valueRef: CFTypeRef?
        let valueResult = AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &valueRef)
        guard valueResult == .success,
              let fullText = valueRef as? String,
              !fullText.isEmpty,
              let rangeValue = selectedRangeValue(from: axElement),
              let range = cfRange(from: rangeValue) else {
            return nil
        }

        let utf16Count = fullText.utf16.count
        guard range.length > 0, range.location + range.length <= utf16Count else {
            return nil
        }

        let start = String.Index(utf16Offset: range.location, in: fullText)
        let end = String.Index(utf16Offset: range.location + range.length, in: fullText)
        return String(fullText[start..<end])
    }

    nonisolated private func selectedTextFromParent(_ axElement: AXUIElement) -> String? {
        var parent: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axElement, kAXParentAttribute as CFString, &parent)
        guard result == .success,
              let parentElement = asAXUIElement(parent) else {
            return nil
        }

        return selectedTextFromDirectAttribute(parentElement)
    }

    nonisolated private func selectionBounds(for axElement: AXUIElement) -> CGRect? {
        guard let rangeValue = selectedRangeValue(from: axElement) else {
            return nil
        }

        var boundsValue: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(
            axElement,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &boundsValue
        )
        guard result == .success,
              let axValue = asAXValue(boundsValue, type: .cgRect) else {
            return nil
        }

        var rect = CGRect.zero
        guard AXValueGetValue(axValue, .cgRect, &rect) else {
            return nil
        }
        return rect == .zero ? nil : rect
    }

    nonisolated private func selectedRangeValue(from axElement: AXUIElement) -> AXValue? {
        var rangeValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, &rangeValue)
        guard result == .success,
              let axValue = asAXValue(rangeValue, type: .cfRange) else {
            return nil
        }
        return axValue
    }

    nonisolated private func asAXUIElement(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    nonisolated private func asAXValue(_ value: CFTypeRef?, type: AXValueType) -> AXValue? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == type else {
            return nil
        }
        return axValue
    }

    nonisolated private func cfRange(from value: AXValue) -> CFRange? {
        guard AXValueGetType(value) == .cfRange else {
            return nil
        }
        var range = CFRange()
        guard AXValueGetValue(value, .cfRange, &range) else {
            return nil
        }
        return range
    }

    nonisolated private func fallbackSelectionBounds() -> CGRect {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.main else {
            return .zero
        }

        // NSEvent.mouseLocation 是 AppKit 坐标 (左下角原点)
        // 转换为 Quartz 坐标 (左上角原点)
        let quartzY = screen.frame.height - mouseLocation.y
        return CGRect(
            x: mouseLocation.x - 50,
            y: quartzY - 10,
            width: 100,
            height: 20
        )
    }
    
    /// 递归遍历子元素寻找选中文本 (用于某些复杂 UI 结构)
    /// 🔥 nonisolated: 允许在后台线程调用
    nonisolated private func findSelectedTextInChildren(_ element: AXUIElement, depth: Int) -> String? {
        // 限制遍历深度，避免无限循环
        guard depth < 10 else { return nil }
        
        // 获取子元素
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        guard result == .success, let childArray = children as? [AXUIElement] else {
            return nil
        }
        
        for child in childArray {
            if let text = selectedTextFromDirectAttribute(child) {
                return text
            }
            
            if let text = selectedTextFromValueRange(child) {
                return text
            }

            if let text = selectedTextFromParameterizedRange(child) {
                return text
            }
            
            // 递归遍历子元素的子元素
            if let text = findSelectedTextInChildren(child, depth: depth + 1) {
                return text
            }
        }
        
        return nil
    }
    
    /// 清除上次选中的文本记录
    func clearLastSelection() {
        lastSelectedText = nil
    }
    
    /// 🔥 方案 C: 验证选中内容是否有意义
    /// 过滤纯空白、纯标点、单个非字母数字字符等无意义选中
    private func isValidSelection(_ text: String) -> Bool {
        // 空文本无效
        guard !text.isEmpty else { return false }
        
        // 检查是否包含至少一个字母或数字（支持中文等 Unicode 字母）
        let hasAlphanumeric = text.unicodeScalars.contains { scalar in
            CharacterSet.alphanumerics.contains(scalar) ||
            // 包含中日韩字符
            (scalar.value >= 0x4E00 && scalar.value <= 0x9FFF) ||  // CJK 基本
            (scalar.value >= 0x3400 && scalar.value <= 0x4DBF) ||  // CJK 扩展 A
            (scalar.value >= 0x3040 && scalar.value <= 0x30FF)     // 平假名 + 片假名
        }
        
        // 如果没有任何字母数字字符，认为无效
        if !hasAlphanumeric {
            return false
        }
        
        // 单字符且是常见标点，无效
        if text.count == 1 {
            let singleChar = text.first!
            let punctuationSet = CharacterSet.punctuationCharacters.union(.symbols)
            if singleChar.unicodeScalars.allSatisfy({ punctuationSet.contains($0) }) {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Electron/Chrome Accessibility 支持
    
    /// 为 Electron/Chrome 等应用启用 Accessibility
    /// 这些应用默认不暴露 AX tree，需要设置特殊属性才能访问
    /// 🔥 nonisolated: 允许在后台线程调用
    nonisolated private func enableAccessibilityForApp(_ appElement: AXUIElement) {
        // AXEnhancedUserInterface: 告诉应用有辅助技术在使用
        // 这会让 Electron/Chrome 应用暴露其 accessibility tree
        let enhancedUI: CFBoolean = kCFBooleanTrue
        AXUIElementSetAttributeValue(
            appElement,
            "AXEnhancedUserInterface" as CFString,
            enhancedUI
        )
        
        // AXManualAccessibility: 另一个可能需要的属性
        AXUIElementSetAttributeValue(
            appElement,
            "AXManualAccessibility" as CFString,
            enhancedUI
        )
    }
}

// MARK: - AXObserver 回调函数

/// AXObserver 回调函数 (C 函数指针，定义在类外部)
private func axObserverCallback(
    observer: AXObserver,
    element: AXUIElement,
    notification: CFString,
    userData: UnsafeMutableRawPointer?
) {
    guard let userData = userData else { return }
    
    // 获取 SelectionMonitorService 实例
    let service = Unmanaged<SelectionMonitorService>.fromOpaque(userData).takeUnretainedValue()
    
    // 在主线程处理
    runSelectionMonitorOnMain(service) { selectionMonitor in
        selectionMonitor.handleAXNotification()
    }
}
