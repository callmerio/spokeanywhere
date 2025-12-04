import Foundation
import os

/// 资源监控器
/// 监控 CPU、内存占用，超限时自动告警或降级
@MainActor
final class ResourceMonitor: ObservableObject {
    static let shared = ResourceMonitor()
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "ResourceMonitor")
    
    // MARK: - Published
    
    @Published private(set) var cpuUsage: Double = 0
    @Published private(set) var memoryUsageMB: Double = 0
    @Published private(set) var isOverloaded = false
    
    // MARK: - Thresholds
    
    /// CPU 阈值（百分比）
    var cpuThreshold: Double = 80
    /// 内存阈值（MB）
    var memoryThresholdMB: Double = 500
    
    // MARK: - Private
    
    private var monitorTimer: Timer?
    private var overloadCallback: (() -> Void)?
    
    private init() {}
    
    // MARK: - Public
    
    /// 开始监控
    /// - Parameters:
    ///   - interval: 采样间隔（秒）
    ///   - onOverload: 超限回调
    func start(interval: TimeInterval = 2.0, onOverload: (() -> Void)? = nil) {
        self.overloadCallback = onOverload
        
        monitorTimer?.invalidate()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sample()
            }
        }
        
        logger.info("📊 Resource monitor started (CPU: \(self.cpuThreshold)%, Memory: \(self.memoryThresholdMB)MB)")
    }
    
    /// 停止监控
    func stop() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        logger.info("📊 Resource monitor stopped")
    }
    
    /// 单次采样
    func sample() {
        cpuUsage = Self.getCPUUsage()
        memoryUsageMB = Self.getMemoryUsageMB()
        
        let wasOverloaded = isOverloaded
        isOverloaded = cpuUsage > cpuThreshold || memoryUsageMB > memoryThresholdMB
        
        if isOverloaded && !wasOverloaded {
            logger.warning("⚠️ Resource overload! CPU: \(self.cpuUsage, format: .fixed(precision: 1))%, Memory: \(self.memoryUsageMB, format: .fixed(precision: 1))MB")
            overloadCallback?()
        }
    }
    
    // MARK: - Static Helpers
    
    /// 获取当前进程 CPU 使用率
    static func getCPUUsage() -> Double {
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        
        let result = task_threads(mach_task_self_, &threadList, &threadCount)
        guard result == KERN_SUCCESS, let threads = threadList else { return 0 }
        
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride))
        }
        
        var totalCPU: Double = 0
        
        for i in 0..<Int(threadCount) {
            var info = thread_basic_info()
            var infoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
            
            let kr = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) {
                    thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &infoCount)
                }
            }
            
            if kr == KERN_SUCCESS && (info.flags & TH_FLAGS_IDLE) == 0 {
                totalCPU += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100
            }
        }
        
        return totalCPU
    }
    
    /// 获取当前进程内存使用量（MB）
    static func getMemoryUsageMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.phys_footprint) / 1024 / 1024
    }
    
    /// 快速日志当前状态
    func logStatus() {
        sample()
        logger.info("📊 CPU: \(self.cpuUsage, format: .fixed(precision: 1))%, Memory: \(self.memoryUsageMB, format: .fixed(precision: 1))MB")
    }
}

// MARK: - Debug View

#if DEBUG
import SwiftUI

struct ResourceMonitorView: View {
    @ObservedObject private var monitor = ResourceMonitor.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // CPU
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .foregroundStyle(monitor.cpuUsage > monitor.cpuThreshold ? .red : .green)
                Text("\(monitor.cpuUsage, specifier: "%.0f")%")
                    .font(.system(size: 10, design: .monospaced))
            }
            
            // Memory
            HStack(spacing: 4) {
                Image(systemName: "memorychip")
                    .foregroundStyle(monitor.memoryUsageMB > monitor.memoryThresholdMB ? .red : .green)
                Text("\(monitor.memoryUsageMB, specifier: "%.0f")MB")
                    .font(.system(size: 10, design: .monospaced))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .cornerRadius(6)
    }
}
#endif
