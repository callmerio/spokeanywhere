import Foundation
import os
import AppKit

// MARK: - MultitouchSupport Framework Bridge (Dynamic Loading)

/// 触控点状态（C-compatible 结构体）
/// 参考: MultitouchSupport.framework 的 MTTouch 结构
private struct MTPoint {
    var frame: Int32 = 0
    var timestamp: Double = 0
    var identifier: Int32 = 0
    var state: Int32 = 0        // 1=未触碰, 2=开始, 3=移动, 4=结束, 5=静止(lingers), 6=抬起, 7=无效
    var fingerId: Int32 = 0
    var handId: Int32 = 0
    var normalizedX: Float32 = 0 // 归一化 X 坐标 (0-1)
    var normalizedY: Float32 = 0 // 归一化 Y 坐标 (0-1)
    var total: Float32 = 0
    var pressure: Float32 = 0
    var angle: Float32 = 0
    var majorAxis: Float32 = 0
    var minorAxis: Float32 = 0
    var absX: Float32 = 0
    var absY: Float32 = 0
    var field14: Int32 = 0
    var field15: Int32 = 0
    var density: Float32 = 0
}

/// MultitouchSupport.framework 类型定义
private typealias MTDeviceRef = UnsafeMutableRawPointer
private typealias MTContactCallback = @convention(c) (
    MTDeviceRef,                 // device
    UnsafeMutableRawPointer,     // points
    Int32,                       // numPoints
    Double,                      // timestamp
    Int32                        // frame
) -> Void

/// 动态加载的函数类型
private typealias MTDeviceCreateListFunc = @convention(c) () -> CFArray?
private typealias MTRegisterContactFrameCallbackFunc = @convention(c) (MTDeviceRef, MTContactCallback?) -> Void
private typealias MTUnregisterContactFrameCallbackFunc = @convention(c) (MTDeviceRef, MTContactCallback?) -> Void
private typealias MTDeviceStartFunc = @convention(c) (MTDeviceRef, Int32) -> Void
private typealias MTDeviceStopFunc = @convention(c) (MTDeviceRef) -> Void

/// MultitouchSupport 框架加载器
private class MultitouchSupport {
    static let shared = MultitouchSupport()
    
    private var handle: UnsafeMutableRawPointer?
    var createList: MTDeviceCreateListFunc?
    var registerCallback: MTRegisterContactFrameCallbackFunc?
    var unregisterCallback: MTUnregisterContactFrameCallbackFunc?
    var deviceStart: MTDeviceStartFunc?
    var deviceStop: MTDeviceStopFunc?
    
    var isLoaded: Bool { handle != nil }
    
    private init() {
        // 动态加载 MultitouchSupport.framework
        let frameworkPath = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        handle = dlopen(frameworkPath, RTLD_NOW)
        
        guard handle != nil else {
            let error = String(cString: dlerror())
            print("⚠️ 无法加载 MultitouchSupport.framework: \(error)")
            return
        }
        
        NSLog("✅ MultitouchSupport.framework 已加载")
        
        // 获取函数指针
        if let sym = dlsym(handle, "MTDeviceCreateList") {
            createList = unsafeBitCast(sym, to: MTDeviceCreateListFunc.self)
            print("  ✓ MTDeviceCreateList")
        }
        if let sym = dlsym(handle, "MTRegisterContactFrameCallback") {
            registerCallback = unsafeBitCast(sym, to: MTRegisterContactFrameCallbackFunc.self)
            print("  ✓ MTRegisterContactFrameCallback")
        }
        if let sym = dlsym(handle, "MTUnregisterContactFrameCallback") {
            unregisterCallback = unsafeBitCast(sym, to: MTUnregisterContactFrameCallbackFunc.self)
            print("  ✓ MTUnregisterContactFrameCallback")
        }
        if let sym = dlsym(handle, "MTDeviceStart") {
            deviceStart = unsafeBitCast(sym, to: MTDeviceStartFunc.self)
            print("  ✓ MTDeviceStart")
        }
        if let sym = dlsym(handle, "MTDeviceStop") {
            deviceStop = unsafeBitCast(sym, to: MTDeviceStopFunc.self)
            print("  ✓ MTDeviceStop")
        }
    }
    
    deinit {
        if let handle = handle {
            dlclose(handle)
        }
    }
}

// MARK: - Trackpad Gesture Service

/// 触控板手势服务
/// 检测从左边缘往右滑打开 Panel，往左滑关闭 Panel
final class TrackpadGestureService {
    
    // MARK: - Singleton
    
    static let shared = TrackpadGestureService()
    
    // MARK: - Configuration
    
    /// 左边缘阈值（触控板宽度的百分比，0.15 = 左侧 15%）
    private let edgeThreshold: Float32 = 0.15
    
    /// 滑动距离阈值（触控板宽度的百分比，0.10 = 10%）
    private let swipeDistanceThreshold: Float32 = 0.10
    
    /// 最小手指数量（需要双指才能触发）
    private let minFingerCount: Int = 2
    
    /// 最大手指数量
    private let maxFingerCount: Int = 3
    
    /// 累积检测时间窗口（秒）
    private let fingerTrackingWindow: Double = 0.1
    
    // MARK: - State
    
    /// 是否已启动
    private(set) var isRunning = false
    
    /// 手势起始信息
    private struct GestureStart {
        let startX: Float32
        let startY: Float32
        let isFromLeftEdge: Bool
        let timestamp: Double
        let fingerCount: Int
    }
    
    /// 当前手势起始状态
    private var gestureStart: GestureStart?
    
    /// 跟踪最近看到的触控点（identifier -> 最后更新时间）
    private var recentFingers: [Int32: Double] = [:]
    
    /// 最近帧中检测到的最大点数
    private var recentMaxPoints: Int = 0
    private var recentMaxPointsTime: Double = 0
    
    /// 活跃的设备列表
    private var devices: [MTDeviceRef] = []
    
    /// Logger
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "TrackpadGesture")
    
    // MARK: - Callbacks
    
    /// 打开 Panel 回调
    var onOpenPanel: (() -> Void)?
    
    /// 关闭 Panel 回调
    var onClosePanel: (() -> Void)?
    
    /// Panel 是否可见（用于判断是否响应关闭手势）
    var isPanelVisible: (() -> Bool)?
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Public API
    
    /// 启动手势监听
    func start() {
        guard !isRunning else { return }
        
        let mt = MultitouchSupport.shared
        guard mt.isLoaded else {
            logger.warning("⚠️ MultitouchSupport.framework 未加载")
            return
        }
        
        // 设置全局回调处理器
        TrackpadGestureService.sharedInstance = self
        
        // 获取所有多点触控设备
        guard let rawList = mt.createList?() else {
            NSLog("⚠️ MTDeviceCreateList 返回 nil")
            return
        }
        
        let count = CFArrayGetCount(rawList)
        NSLog("📋 找到 %d 个触控设备", count)
        
        guard count > 0 else {
            NSLog("⚠️ 没有找到触控设备")
            return
        }
        
        // 从 CFArray 中提取设备引用
        for i in 0..<count {
            if let device = CFArrayGetValueAtIndex(rawList, i) {
                // 转换为 UnsafeMutableRawPointer
                let mutableDevice = UnsafeMutableRawPointer(mutating: device)
                devices.append(mutableDevice)
            }
        }
        
        // 为每个设备注册回调
        for device in devices {
            mt.registerCallback?(device, trackpadCallback)
            mt.deviceStart?(device, 0)
        }
        
        isRunning = true
        let deviceCount = devices.count
        NSLog("✅ 触控板手势监听已启动，设备数: %d", deviceCount)
        NSLog("📐 MTPoint 结构体大小: %d bytes", MemoryLayout<MTPoint>.size)
        logger.info("✅ 触控板手势监听已启动，设备数: \(deviceCount)")
    }
    
    /// 停止手势监听
    func stop() {
        guard isRunning else { return }
        
        let mt = MultitouchSupport.shared
        
        for device in devices {
            mt.unregisterCallback?(device, trackpadCallback)
            mt.deviceStop?(device)
        }
        
        devices.removeAll()
        isRunning = false
        TrackpadGestureService.sharedInstance = nil
        logger.info("🛑 触控板手势监听已停止")
    }
    
    // MARK: - Private
    
    /// 全局实例引用（用于 C 回调）
    fileprivate static var sharedInstance: TrackpadGestureService?
    
    /// 调试模式
    var debugMode = false
    
    /// 处理触控帧
    fileprivate func handleContactFrame(
        pointsRaw: UnsafeMutableRawPointer,
        numPoints: Int32,
        timestamp: Double
    ) {
        let points = pointsRaw.assumingMemoryBound(to: MTPoint.self)
        let count = Int(numPoints)
        
        // 1. 更新最近帧中的最大点数（用于判断多指）
        if count > recentMaxPoints || timestamp - recentMaxPointsTime > fingerTrackingWindow {
            recentMaxPoints = count
            recentMaxPointsTime = timestamp
        }
        
        // 2. 收集当前帧活跃点
        var currentActivePoints: [MTPoint] = []
        var allTouchesEnded = true
        for i in 0..<count {
            let point = points[i]
            // state: 3=开始, 4=移动, 5=静止
            if point.state >= 3 && point.state <= 5 {
                currentActivePoints.append(point)
                allTouchesEnded = false
            }
        }
        
        // 3. 所有触控结束时重置
        if allTouchesEnded {
            gestureStart = nil
            recentMaxPoints = 0
            return
        }
        
        // 4. 使用最近帧中检测到的最大点数作为手指数
        let fingerCount = recentMaxPoints
        
        // 调试日志
        if debugMode && fingerCount > 0 {
            NSLog("🖐️ 原始点数: %d 累计最大: %d", count, fingerCount)
        }
        
        // 5. 检查手指数量
        guard fingerCount >= minFingerCount && fingerCount <= maxFingerCount else {
            return
        }
        
        // 5. 计算所有活跃触控点的平均位置
        guard !currentActivePoints.isEmpty else { return }
        let avgX = currentActivePoints.reduce(Float32(0)) { $0 + $1.normalizedX } / Float32(currentActivePoints.count)
        let avgY = currentActivePoints.reduce(Float32(0)) { $0 + $1.normalizedY } / Float32(currentActivePoints.count)
        
        // 6. 检测新手势开始
        let hasNewTouch = currentActivePoints.contains { $0.state == 3 }
        
        if hasNewTouch && gestureStart == nil {
            let isFromLeftEdge = avgX < edgeThreshold
            gestureStart = GestureStart(
                startX: avgX,
                startY: avgY,
                isFromLeftEdge: isFromLeftEdge,
                timestamp: timestamp,
                fingerCount: fingerCount
            )
            if debugMode {
                NSLog("👆 双指手势开始: x=%.3f, 左边缘=%@, 手指=%d", avgX, isFromLeftEdge ? "YES" : "NO", fingerCount)
            }
        }
        
        guard let start = gestureStart else { return }
        
        // 7. 计算滑动距离
        let deltaX = avgX - start.startX
        let deltaY = avgY - start.startY
        
        // 检查是否是水平滑动
        let isHorizontalSwipe = abs(deltaY) < abs(deltaX) * 0.5
        guard isHorizontalSwipe else { return }
        
        // 调试
        if debugMode && abs(deltaX) > 0.05 {
            NSLog("📏 滑动: deltaX=%.3f 手指=%d", deltaX, fingerCount)
        }
        
        // 8. 检查滑动方向和距离
        if start.isFromLeftEdge && deltaX > swipeDistanceThreshold {
            NSLog("👉 双指右滑，打开 Panel (deltaX=%.3f, 手指=%d)", deltaX, fingerCount)
            gestureStart = nil
            recentFingers.removeAll()
            DispatchQueue.main.async { [weak self] in
                self?.onOpenPanel?()
            }
        } else if deltaX < -swipeDistanceThreshold {
            if isPanelVisible?() == true {
                NSLog("👈 双指左滑，关闭 Panel (deltaX=%.3f, 手指=%d)", deltaX, fingerCount)
                gestureStart = nil
                recentFingers.removeAll()
                DispatchQueue.main.async { [weak self] in
                    self?.onClosePanel?()
                }
            }
        }
    }
}

// MARK: - C Callback

/// 触控板回调函数（C 函数指针）
private let trackpadCallback: MTContactCallback = { device, pointsRaw, numPoints, timestamp, frame in
    TrackpadGestureService.sharedInstance?.handleContactFrame(
        pointsRaw: pointsRaw,
        numPoints: numPoints,
        timestamp: timestamp
    )
}
