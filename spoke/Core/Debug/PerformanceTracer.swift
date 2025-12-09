import Foundation
import os

// MARK: - 性能追踪日志
private let performanceLog = OSLog(subsystem: "com.spokeanywhere", category: .pointsOfInterest)
private let pipelineLog = OSLog(subsystem: "com.spokeanywhere", category: "Pipeline")

/// 性能追踪器
/// 使用 os_signpost 记录代码块执行时间，可在 Instruments 中可视化分析
enum PerformanceTracer {
    
    // MARK: - Signpost Categories
    
    /// Pipeline 阶段追踪 Log
    static let pipeline = pipelineLog
    
    /// 通用性能追踪 Log（显示在 Points of Interest）
    static let general = performanceLog
    
    // MARK: - 同步追踪
    
    /// 追踪同步代码块
    /// - Parameters:
    ///   - name: 阶段名称（静态字符串）
    ///   - log: 日志类别
    ///   - block: 要追踪的代码块
    /// - Returns: 代码块的返回值
    @discardableResult
    static func trace<T>(
        _ name: StaticString,
        log: OSLog = pipelineLog,
        _ block: () throws -> T
    ) rethrows -> T {
        let signpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: signpostID)
        defer { os_signpost(.end, log: log, name: name, signpostID: signpostID) }
        return try block()
    }
    
    /// 追踪同步代码块（带额外信息）
    @discardableResult
    static func trace<T>(
        _ name: StaticString,
        log: OSLog = pipelineLog,
        message: String,
        _ block: () throws -> T
    ) rethrows -> T {
        let signpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: signpostID, "%{public}s", message)
        defer { os_signpost(.end, log: log, name: name, signpostID: signpostID, "%{public}s", message) }
        return try block()
    }
    
    // MARK: - 异步追踪
    
    /// 追踪异步代码块
    @discardableResult
    static func traceAsync<T>(
        _ name: StaticString,
        log: OSLog = pipelineLog,
        _ block: () async throws -> T
    ) async rethrows -> T {
        let signpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: signpostID)
        defer { os_signpost(.end, log: log, name: name, signpostID: signpostID) }
        return try await block()
    }
    
    /// 追踪异步代码块（带额外信息）
    @discardableResult
    static func traceAsync<T>(
        _ name: StaticString,
        log: OSLog = pipelineLog,
        message: String,
        _ block: () async throws -> T
    ) async rethrows -> T {
        let signpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: signpostID, "%{public}s", message)
        defer { os_signpost(.end, log: log, name: name, signpostID: signpostID, "%{public}s", message) }
        return try await block()
    }
    
    // MARK: - 手动控制 Signpost
    
    /// 开始一个 signpost 区间
    /// - Returns: SignpostID，用于结束时匹配
    static func begin(_ name: StaticString, log: OSLog = pipelineLog, message: String? = nil) -> OSSignpostID {
        let signpostID = OSSignpostID(log: log)
        if let message = message {
            os_signpost(.begin, log: log, name: name, signpostID: signpostID, "%{public}s", message)
        } else {
            os_signpost(.begin, log: log, name: name, signpostID: signpostID)
        }
        return signpostID
    }
    
    /// 结束一个 signpost 区间
    static func end(_ name: StaticString, log: OSLog = pipelineLog, signpostID: OSSignpostID, message: String? = nil) {
        if let message = message {
            os_signpost(.end, log: log, name: name, signpostID: signpostID, "%{public}s", message)
        } else {
            os_signpost(.end, log: log, name: name, signpostID: signpostID)
        }
    }
    
    /// 标记一个事件点（不是区间）
    static func event(_ name: StaticString, log: OSLog = pipelineLog, message: String? = nil) {
        let signpostID = OSSignpostID(log: log)
        if let message = message {
            os_signpost(.event, log: log, name: name, signpostID: signpostID, "%{public}s", message)
        } else {
            os_signpost(.event, log: log, name: name, signpostID: signpostID)
        }
    }
}

// MARK: - 便捷扩展

extension PerformanceTracer {
    
    /// SelectionMonitor Pipeline 追踪
    enum Selection {
        static let log = OSLog(subsystem: "com.spokeanywhere", category: "SelectionMonitor")
        
        /// 追踪 Selection 检查
        @discardableResult
        static func traceCheck<T>(_ block: () throws -> T) rethrows -> T {
            try PerformanceTracer.trace("SelectionCheck", log: log, block)
        }
        
        /// 追踪 AX API 调用
        @discardableResult
        static func traceAXAPI<T>(method: String, _ block: () throws -> T) rethrows -> T {
            try PerformanceTracer.trace("AX_API", log: log, message: method, block)
        }
        
        /// 追踪过滤逻辑
        @discardableResult
        static func traceFilter<T>(_ block: () throws -> T) rethrows -> T {
            try PerformanceTracer.trace("Filter", log: log, block)
        }
        
        /// 追踪回调执行
        @discardableResult
        static func traceCallback<T>(_ block: () throws -> T) rethrows -> T {
            try PerformanceTracer.trace("Callback", log: log, block)
        }
    }
    
    /// LLM Pipeline 追踪
    enum LLM {
        static let log = OSLog(subsystem: "com.spokeanywhere", category: "LLMPipeline")
        
        @discardableResult
        static func traceRefine<T>(_ block: () async throws -> T) async rethrows -> T {
            try await PerformanceTracer.traceAsync("Refine", log: log, block)
        }
        
        @discardableResult
        static func traceBuildPrompt<T>(_ block: () async throws -> T) async rethrows -> T {
            try await PerformanceTracer.traceAsync("BuildPrompt", log: log, block)
        }
        
        @discardableResult
        static func traceAPICall<T>(provider: String, _ block: () async throws -> T) async rethrows -> T {
            try await PerformanceTracer.traceAsync("APICall", log: log, message: provider, block)
        }
    }
}

// MARK: - 耗时日志（控制台输出）

/// 简单的耗时测量工具（用于快速调试）
struct StopWatch {
    private let name: String
    private let startTime: CFAbsoluteTime
    private let logger: Logger
    
    init(_ name: String, logger: Logger? = nil) {
        self.name = name
        self.startTime = CFAbsoluteTimeGetCurrent()
        self.logger = logger ?? Logger(subsystem: "com.spokeanywhere", category: "StopWatch")
    }
    
    /// 结束计时并打印耗时
    func stop() {
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logger.info("⏱️ [\(self.name)] \(String(format: "%.2f", elapsed))ms")
    }
    
    /// 中间检查点
    func checkpoint(_ label: String) {
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logger.debug("⏱️ [\(self.name)] \(label): \(String(format: "%.2f", elapsed))ms")
    }
}
