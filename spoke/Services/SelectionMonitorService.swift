import AppKit
import ApplicationServices
import Combine
import OSLog

private let logger = Logger(subsystem: "com.spokeanywhere", category: "SelectionMonitor")

/// 全局文本选择监听服务
/// 使用 macOS Accessibility API 监听系统范围内的文本选择
@MainActor
final class SelectionMonitorService {
    
    // MARK: - Singleton
    
    static let shared = SelectionMonitorService()
    
    // MARK: - Properties
    
    /// 是否正在监听
    private(set) var isMonitoring = false
    
    /// 是否已授权辅助功能权限
    var isAccessibilityEnabled: Bool {
        AXIsProcessTrusted()
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
    
    /// AXObserver 实例 (用于监听选择变化通知)
    private var axObserver: AXObserver?
    
    /// 当前监听的应用 PID
    private var currentObservedPid: pid_t = 0
    
    /// 应用切换观察者
    private var appActivationObserver: NSObjectProtocol?
    
    /// 忽略的应用 Bundle ID (不在这些应用中显示工具栏)
    private let ignoredBundleIds: Set<String> = [
        "com.apple.loginwindow",
        "com.apple.screencaptureui",
    ]
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Public API
    
    /// 开始监听
    func startMonitoring() {
        logger.info("📋 [SelectionMonitor] startMonitoring() 被调用")
        print("📋 [SelectionMonitor] startMonitoring() 被调用")
        
        guard !isMonitoring else {
            logger.debug("📋 [SelectionMonitor] 已在监听中，跳过")
            print("📋 [SelectionMonitor] 已在监听中，跳过")
            return
        }
        
        // 检查辅助功能权限
        let hasPermission = isAccessibilityEnabled
        logger.info("📋 [SelectionMonitor] 辅助功能权限: \(hasPermission)")
        print("📋 [SelectionMonitor] 辅助功能权限: \(hasPermission)")
        
        guard hasPermission else {
            logger.warning("📋 [SelectionMonitor] ❌ 未授权辅助功能权限，请求授权...")
            print("📋 [SelectionMonitor] ❌ 未授权辅助功能权限! 请在 系统设置 → 隐私与安全性 → 辅助功能 中授权")
            requestAccessibilityPermission()
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
        print("📋 [SelectionMonitor] ✅ 开始监听文本选择成功!")
    }
    
    /// 停止监听
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        
        // 移除鼠标监听 (Global)
        if let monitor = mouseDownMonitor {
            NSEvent.removeMonitor(monitor)
            mouseDownMonitor = nil
        }
        if let monitor = mouseEventMonitor {
            NSEvent.removeMonitor(monitor)
            mouseEventMonitor = nil
        }
        
        // 移除鼠标监听 (Local)
        if let monitor = localMouseDownMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseDownMonitor = nil
        }
        if let monitor = localMouseUpMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseUpMonitor = nil
        }
        
        isMouseDown = false
        
        // 移除键盘监听
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
        
        // 移除 AXObserver
        removeCurrentAXObserver()
        
        // 移除应用切换观察者
        if let observer = appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            appActivationObserver = nil
        }
        
        debounceTimer?.invalidate()
        debounceTimer = nil
        
        logger.info("📋 [SelectionMonitor] 停止监听")
    }
    
    /// 请求辅助功能权限
    func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let _ = AXIsProcessTrustedWithOptions(options)
        
        logger.info("📋 [SelectionMonitor] 已请求辅助功能权限")
    }
    
    /// 手动触发检查选中文本
    func checkSelection() {
        guard isMonitoring else { return }
        
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceDelay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performSelectionCheck()
            }
        }
    }
    
    // MARK: - Private Methods
    
    // MARK: AXObserver 相关
    
    /// 设置应用切换监听
    private func setupAppActivationObserver() {
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.updateAXObserverForFrontmostApp()
            }
        }
        logger.debug("📋 [SelectionMonitor] 应用切换监听已设置")
    }
    
    /// 为当前前台应用设置 AXObserver
    private func updateAXObserverForFrontmostApp() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
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
        
        // 直接调用检查，不打日志（避免打字时刷屏）
        checkSelection()
    }
    
    // MARK: 鼠标/键盘监听
    
    /// 设置鼠标事件监听
    private func setupMouseMonitor() {
        // === Global Monitor (监听其他 App) ===
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isMouseDown = true
            }
        }
        
        mouseEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isMouseDown = false
                self?.checkSelection()
            }
        }
        
        // === Local Monitor (监听自身 App) ===
        localMouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.isMouseDown = true
            }
            return event
        }
        
        localMouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.isMouseDown = false
                self?.checkSelection()
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
                Task { @MainActor [weak self] in
                    self?.checkSelection()
                }
            }
        }
    }
    
    /// 执行选中文本检查
    private func performSelectionCheck() {
        // 获取当前聚焦的应用
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return
        }
        
        let bundleId = frontApp.bundleIdentifier ?? ""
        
        // 忽略特定应用
        if ignoredBundleIds.contains(bundleId) {
            return
        }
        
        // 一次性获取选中文本和位置（内部已包含快速检查逻辑）
        guard let (selectedText, bounds) = getSelectedTextAndBounds(for: frontApp) else {
            return
        }
        
        // 验证文本长度
        let trimmedText = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.count >= minSelectionLength,
              trimmedText.count <= maxSelectionLength else {
            return
        }
        
        // 去重检查
        if trimmedText == lastSelectedText {
            logger.debug("📋 [SelectionMonitor] 相同文本，忽略")
            return
        }
        
        lastSelectedText = trimmedText
        
        // 创建上下文
        let context = SelectionContext(
            selectedText: trimmedText,
            selectionBounds: bounds,
            sourceAppBundleId: bundleId,
            sourceAppName: frontApp.localizedName
        )
        
        logger.info("📋 [SelectionMonitor] 检测到选中文本 | 长度: \(trimmedText.count) | 应用: \(frontApp.localizedName ?? "unknown")")
        
        // 回调
        onSelectionChanged?(context)
    }
    
    /// 使用 Accessibility API 获取选中文本和位置
    private func getSelectedTextAndBounds(for app: NSRunningApplication) -> (String, CGRect)? {
        var bounds = CGRect.zero
        var selectedText: String?
        var focusedElement: AXUIElement?
        
        // 方法1: 使用 SystemWide 元素获取 (对 Electron 应用更有效)
        let systemWideElement = AXUIElementCreateSystemWide()
        
        var focusedApp: CFTypeRef?
        let appResult = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        
        if appResult == .success, let appElement = focusedApp {
            var focusedUIElement: CFTypeRef?
            let focusResult = AXUIElementCopyAttributeValue(appElement as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedUIElement)
            
            if focusResult == .success, let element = focusedUIElement {
                focusedElement = (element as! AXUIElement)
            }
        }
        
        // 方法2: 如果 SystemWide 失败，使用传统的 Application 方式
        if focusedElement == nil {
            let pid = app.processIdentifier
            let appElement = AXUIElementCreateApplication(pid)
            
            var element: CFTypeRef?
            let focusResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &element)
            
            if focusResult == .success, let e = element {
                focusedElement = (e as! AXUIElement)
            }
        }
        
        guard let axElement = focusedElement else {
            return nil
        }
        
        // 策略1: 尝试通过标准 AXSelectedText API 获取
        var selectedTextValue: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(axElement, kAXSelectedTextAttribute as CFString, &selectedTextValue)
        
        if textResult == .success, let textValue = selectedTextValue as? String, !textValue.isEmpty {
            selectedText = textValue
        }
        
        // 策略2: 参数化属性 (Parameterized Attribute) - 通过范围获取文本
        if selectedText == nil || selectedText?.isEmpty == true {
            var rangeValue: CFTypeRef?
            let rangeResult = AXUIElementCopyAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, &rangeValue)
            
            if rangeResult == .success, let rangeRef = rangeValue, CFGetTypeID(rangeRef) == AXValueGetTypeID() {
                let axValue = rangeRef as! AXValue
                if AXValueGetType(axValue) == .cfRange {
                    var range = CFRange()
                    AXValueGetValue(axValue, .cfRange, &range)
                    
                    if range.length > 0 {
                        var stringForRangeValue: CFTypeRef?
                        let stringResult = AXUIElementCopyParameterizedAttributeValue(
                            axElement,
                            kAXStringForRangeParameterizedAttribute as CFString,
                            rangeRef,
                            &stringForRangeValue
                        )
                        
                        if stringResult == .success, let text = stringForRangeValue as? String, !text.isEmpty {
                            selectedText = text
                        }
                    }
                }
            }
        }
        
        // 策略3: Value + Range (手动截取)
        if selectedText == nil || selectedText?.isEmpty == true {
             var valueRef: CFTypeRef?
             let valueResult = AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &valueRef)
             
             if valueResult == .success, let fullText = valueRef as? String, !fullText.isEmpty {
                 var rangeValue: CFTypeRef?
                 let rangeResult = AXUIElementCopyAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, &rangeValue)
                 
                 if rangeResult == .success, let rangeRef = rangeValue, CFGetTypeID(rangeRef) == AXValueGetTypeID() {
                     let axValue = rangeRef as! AXValue
                     if AXValueGetType(axValue) == .cfRange {
                         var range = CFRange()
                         AXValueGetValue(axValue, .cfRange, &range)
                         
                         let utf16Count = fullText.utf16.count
                         if range.length > 0 && range.location + range.length <= utf16Count {
                             let start = String.Index(utf16Offset: range.location, in: fullText)
                             let end = String.Index(utf16Offset: range.location + range.length, in: fullText)
                             selectedText = String(fullText[start..<end])
                         }
                     }
                 }
             }
        }
        
        // 策略4: 如果直接获取失败，尝试从父元素获取
        if selectedText == nil || selectedText?.isEmpty == true {
            var parent: CFTypeRef?
            if AXUIElementCopyAttributeValue(axElement, kAXParentAttribute as CFString, &parent) == .success,
               let parentElement = parent {
                var parentSelectedText: CFTypeRef?
                if AXUIElementCopyAttributeValue(parentElement as! AXUIElement, kAXSelectedTextAttribute as CFString, &parentSelectedText) == .success,
                   let parentText = parentSelectedText as? String, !parentText.isEmpty {
                    selectedText = parentText
                }
            }
        }
        
        // 策略5: 如果还是失败，尝试遍历子元素
        if selectedText == nil || selectedText?.isEmpty == true {
            selectedText = findSelectedTextInChildren(axElement, depth: 0)
        }
        
        if let text = selectedText, !text.isEmpty {
            // 尝试获取选中范围和位置
            var selectedRangeValue: CFTypeRef?
            let rangeResult = AXUIElementCopyAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, &selectedRangeValue)
            
            if rangeResult == .success, let rangeValue = selectedRangeValue {
                var boundsValue: CFTypeRef?
                let boundsResult = AXUIElementCopyParameterizedAttributeValue(
                    axElement,
                    kAXBoundsForRangeParameterizedAttribute as CFString,
                    rangeValue,
                    &boundsValue
                )
                
                if boundsResult == .success, let axValue = boundsValue {
                    var rect = CGRect.zero
                    if AXValueGetValue(axValue as! AXValue, .cgRect, &rect) {
                        bounds = rect
                    }
                }
            }
        }
        
        guard let text = selectedText, !text.isEmpty else {
            return nil
        }
        
        // 如果无法获取精确位置，使用鼠标位置 (Quartz 坐标系)
        if bounds == .zero {
            let mouseLocation = NSEvent.mouseLocation
            if let screen = NSScreen.main {
                // NSEvent.mouseLocation 是 AppKit 坐标 (左下角原点)
                // 转换为 Quartz 坐标 (左上角原点)
                let quartzY = screen.frame.height - mouseLocation.y
                bounds = CGRect(
                    x: mouseLocation.x - 50,
                    y: quartzY - 10,  // 稍微上移，工具栏显示在鼠标下方
                    width: 100,
                    height: 20
                )
            }
        }
        
        return (text, bounds)
    }
    
    /// 递归遍历子元素寻找选中文本 (用于某些复杂 UI 结构)
    private func findSelectedTextInChildren(_ element: AXUIElement, depth: Int) -> String? {
        // 限制遍历深度，避免无限循环
        guard depth < 10 else { return nil }
        
        // 获取子元素
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        guard result == .success, let childArray = children as? [AXUIElement] else {
            return nil
        }
        
        for child in childArray {
            // 方法1: 尝试从当前子元素获取选中文本
            var selectedTextValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(child, kAXSelectedTextAttribute as CFString, &selectedTextValue) == .success,
               let text = selectedTextValue as? String, !text.isEmpty {
                return text
            }
            
            // 方法2: 尝试 Value + Range 策略
            var rangeValue: CFTypeRef?
            let rangeResult = AXUIElementCopyAttributeValue(child, kAXSelectedTextRangeAttribute as CFString, &rangeValue)
            
            if rangeResult == .success, let rangeRef = rangeValue, CFGetTypeID(rangeRef) == AXValueGetTypeID() {
                let axValue = rangeRef as! AXValue
                if AXValueGetType(axValue) == .cfRange {
                    var range = CFRange()
                    AXValueGetValue(axValue, .cfRange, &range)
                    
                    if range.length > 0 {
                        // 获取 Value
                        var valueRef: CFTypeRef?
                        if AXUIElementCopyAttributeValue(child, kAXValueAttribute as CFString, &valueRef) == .success,
                           let fullText = valueRef as? String, !fullText.isEmpty {
                            let utf16Count = fullText.utf16.count
                            if range.location + range.length <= utf16Count {
                                let start = String.Index(utf16Offset: range.location, in: fullText)
                                let end = String.Index(utf16Offset: range.location + range.length, in: fullText)
                                return String(fullText[start..<end])
                            }
                        }
                        
                        // 尝试 StringForRange
                        var stringForRangeValue: CFTypeRef?
                        if AXUIElementCopyParameterizedAttributeValue(
                            child,
                            kAXStringForRangeParameterizedAttribute as CFString,
                            rangeRef,
                            &stringForRangeValue
                        ) == .success, let text = stringForRangeValue as? String, !text.isEmpty {
                            return text
                        }
                    }
                }
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
    Task { @MainActor in
        service.handleAXNotification()
    }
}
