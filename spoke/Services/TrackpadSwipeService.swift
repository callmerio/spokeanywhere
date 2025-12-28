import AppKit
import Foundation
import os

// MARK: - Trackpad Swipe Service (App Store Compatible)

/// 触控板滑动手势服务 (使用公开 API)
/// 
/// 检测双指长距离水平滑动来打开/关闭 Panel
/// 
/// ⚠️ 注意: 需要 Accessibility 权限才能全局监听
/// 
/// 与私有 API 版本的区别:
/// - ✅ 使用 NSEvent.addGlobalMonitorForEvents (公开 API)
/// - ✅ 可以上架 App Store
/// - ❌ 无法检测"从边缘开始" (scrollWheel 只有 delta，没有绝对位置)
/// - ❌ 无法精确知道手指数量 (但可以推断 - 触控板滚动默认是双指)
final class TrackpadSwipeService {
    
    // MARK: - Singleton
    
    static let shared = TrackpadSwipeService()
    
    // MARK: - Configuration
    
    /// 触发阈值 (累积滑动距离)
    /// 双指滑动的 deltaX 通常在 1-30 之间，需要累积
    private let swipeThreshold: CGFloat = 300.0
    
    /// 垂直容差比例 (deltaY / deltaX < 0.5 才算水平滑动)
    private let verticalTolerance: CGFloat = 0.5
    
    /// 手势超时时间 (秒)
    private let gestureTimeout: TimeInterval = 0.5
    
    /// 触发后冷却时间 (秒)
    private let cooldownDuration: TimeInterval = 0.3
    
    // MARK: - State
    
    /// 是否已启动
    private(set) var isRunning = false
    
    /// 全局事件监听器
    private var globalMonitor: Any?
    
    /// 累积的水平滑动距离
    private var accumulatedDeltaX: CGFloat = 0
    
    /// 累积的垂直滑动距离
    private var accumulatedDeltaY: CGFloat = 0
    
    /// 手势开始时间
    private var gestureStartTime: Date?
    
    /// 上次触发时间 (冷却)
    private var lastTriggerTime: Date?
    
    /// Logger
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "TrackpadSwipe")
    
    // MARK: - Callbacks
    
    /// 打开 Panel 回调 (右滑)
    var onOpenPanel: (() -> Void)?
    
    /// 关闭 Panel 回调 (左滑)
    var onClosePanel: (() -> Void)?
    
    /// Panel 是否可见
    var isPanelVisible: (() -> Bool)?
    
    // MARK: - Debug
    
    /// 调试模式
    var debugMode = false
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Public API
    
    /// 启动手势监听
    /// 
    /// ⚠️ 需要 Accessibility 权限
    func start() {
        guard !isRunning else { return }
        
        // 检查辅助功能权限
        let trusted = AXIsProcessTrusted()
        if !trusted {
            logger.warning("⚠️ 需要辅助功能权限才能全局监听触控板")
            // 提示用户开启权限
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            return
        }
        
        // 监听 scrollWheel 事件 (双指滑动会转换为此事件)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScrollWheel(event)
        }
        
        isRunning = true
        logger.info("✅ TrackpadSwipeService 已启动 (公开 API)")
    }
    
    /// 停止手势监听
    func stop() {
        guard isRunning else { return }
        
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        
        resetGesture()
        isRunning = false
        logger.info("🛑 TrackpadSwipeService 已停止")
    }
    
    // MARK: - Event Handling
    
    private func handleScrollWheel(_ event: NSEvent) {
        // 只处理触控板事件 (排除鼠标滚轮)
        // phase != .none 表示是触控板手势
        guard event.phase != [] || event.momentumPhase != [] else {
            return
        }
        
        // 检查冷却
        if let lastTrigger = lastTriggerTime,
           Date().timeIntervalSince(lastTrigger) < cooldownDuration {
            return
        }
        
        let deltaX = event.scrollingDeltaX
        let deltaY = event.scrollingDeltaY
        let now = Date()
        
        // 手势阶段处理
        switch event.phase {
        case .began:
            // 新手势开始
            resetGesture()
            gestureStartTime = now
            accumulatedDeltaX = deltaX
            accumulatedDeltaY = deltaY
            
            if debugMode {
                logger.debug("🖐️ 手势开始")
            }
            
        case .changed:
            // 手势进行中
            guard gestureStartTime != nil else {
                // 可能错过了 began，重新开始
                gestureStartTime = now
                accumulatedDeltaX = deltaX
                accumulatedDeltaY = deltaY
                return
            }
            
            // 检查超时
            if now.timeIntervalSince(gestureStartTime!) > gestureTimeout {
                resetGesture()
                return
            }
            
            // 累积滑动距离
            accumulatedDeltaX += deltaX
            accumulatedDeltaY += deltaY
            
            if debugMode && abs(accumulatedDeltaX) > 50 {
                logger.debug("📏 累积: deltaX=\(String(format: "%.1f", self.accumulatedDeltaX)) deltaY=\(String(format: "%.1f", self.accumulatedDeltaY))")
            }
            
            // 检查是否是水平滑动 (垂直偏移要小)
            let isHorizontal = abs(accumulatedDeltaY) < abs(accumulatedDeltaX) * verticalTolerance
            guard isHorizontal else {
                // 不是水平滑动，可能是上下滚动
                return
            }
            
            // 检查是否达到阈值
            if accumulatedDeltaX > swipeThreshold {
                // 右滑 -> 打开 Panel
                logger.info("👉 双指右滑触发 (累积=\(String(format: "%.1f", self.accumulatedDeltaX)))")
                triggerOpen()
            } else if accumulatedDeltaX < -swipeThreshold {
                // 左滑 -> 关闭 Panel
                if isPanelVisible?() == true {
                    logger.info("👈 双指左滑触发 (累积=\(String(format: "%.1f", self.accumulatedDeltaX)))")
                    triggerClose()
                }
            }
            
        case .ended, .cancelled:
            // 手势结束
            if debugMode {
                logger.debug("🖐️ 手势结束 (累积 deltaX=\(String(format: "%.1f", self.accumulatedDeltaX)))")
            }
            resetGesture()
            
        default:
            break
        }
        
        // 处理惯性阶段 (momentum)
        if event.momentumPhase == .ended {
            resetGesture()
        }
    }
    
    // MARK: - Actions
    
    private func triggerOpen() {
        lastTriggerTime = Date()
        resetGesture()
        
        DispatchQueue.main.async { [weak self] in
            self?.onOpenPanel?()
        }
    }
    
    private func triggerClose() {
        lastTriggerTime = Date()
        resetGesture()
        
        DispatchQueue.main.async { [weak self] in
            self?.onClosePanel?()
        }
    }
    
    private func resetGesture() {
        accumulatedDeltaX = 0
        accumulatedDeltaY = 0
        gestureStartTime = nil
    }
}
