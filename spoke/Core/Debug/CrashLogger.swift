import Foundation
import os

/// 崩溃日志记录器
/// 捕获未处理的异常和信号，写入日志文件
final class CrashLogger {
    static let shared = CrashLogger()
    
    private let logger = Logger(subsystem: "app.spokenly", category: "CrashLogger")
    private var logFileHandle: FileHandle?
    
    /// 日志文件路径
    private var logFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let spokeDir = appSupport.appendingPathComponent("Spoke", isDirectory: true)
        let crashDir = spokeDir.appendingPathComponent("crashes", isDirectory: true)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())
        
        return crashDir.appendingPathComponent("crash-\(timestamp).log")
    }
    
    private init() {}
    
    /// 安装崩溃处理器
    func install() {
        // 1. 捕获 NSException
        NSSetUncaughtExceptionHandler { exception in
            CrashLogger.shared.logException(exception)
        }
        
        // 2. 捕获信号 (SIGSEGV, SIGABRT, SIGILL, SIGFPE)
        signal(SIGSEGV, handleSignal)
        signal(SIGABRT, handleSignal)
        signal(SIGILL, handleSignal)
        signal(SIGFPE, handleSignal)
        signal(SIGTRAP, handleSignal)
        
        logger.info("💥 Crash logger installed")
    }
    
    /// 记录异常
    private func logException(_ exception: NSException) {
        let crashInfo = """
        ========================================
        CRASH REPORT
        Time: \(Date())
        Exception: \(exception.name.rawValue)
        Reason: \(exception.reason ?? "Unknown")
        
        Call Stack:
        \(exception.callStackSymbols.joined(separator: "\n"))
        ========================================
        
        """
        
        writeToFile(crashInfo)
        logger.error("💥 CRASH: \(exception.name.rawValue) - \(exception.reason ?? "Unknown")")
        
        // 同时输出到控制台
        NSLog("💥💥💥 CRASH DETECTED 💥💥💥")
        NSLog("%@", crashInfo)
    }
    
    /// 记录信号
    fileprivate func logSignal(_ signal: Int32, name: String) {
        let crashInfo = """
        ========================================
        SIGNAL CRASH
        Time: \(Date())
        Signal: \(name) (\(signal))
        
        Thread: \(Thread.current)
        ========================================
        
        """
        
        writeToFile(crashInfo)
        NSLog("💥💥💥 SIGNAL CRASH: \(name) 💥💥💥")
        NSLog("%@", crashInfo)
    }
    
    /// 写入文件
    private func writeToFile(_ content: String) {
        do {
            // 确保目录存在
            let dir = logFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            
            // 写入文件
            if !FileManager.default.fileExists(atPath: logFileURL.path) {
                FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
            }
            
            if let data = content.data(using: .utf8) {
                if let handle = try? FileHandle(forWritingTo: logFileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            }
            
            NSLog("💾 Crash log saved to: \(logFileURL.path)")
        } catch {
            NSLog("❌ Failed to write crash log: \(error)")
        }
    }
}

// MARK: - Signal Handler

private func handleSignal(_ signal: Int32) {
    let signalName: String
    switch signal {
    case SIGSEGV: signalName = "SIGSEGV (Segmentation Fault)"
    case SIGABRT: signalName = "SIGABRT (Abort)"
    case SIGILL: signalName = "SIGILL (Illegal Instruction)"
    case SIGFPE: signalName = "SIGFPE (Floating Point Exception)"
    case SIGTRAP: signalName = "SIGTRAP (Trace/Breakpoint)"
    default: signalName = "UNKNOWN"
    }
    
    CrashLogger.shared.logSignal(signal, name: signalName)
    
    // 恢复默认处理器并重新触发信号
    Darwin.signal(signal, SIG_DFL)
    raise(signal)
}
