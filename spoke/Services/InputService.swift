import Foundation
import CoreGraphics
import AppKit
import os

/// 键盘输入模拟服务
/// 用于实现"边说边打字"功能
@MainActor
final class InputService {
    
    static let shared = InputService()
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "InputService")
    
    /// 上一次输入的文本（用于增量输入）
    private var lastTypedText: String = ""
    
    /// 上一次看到的文本（用于稳定性检测）
    private var lastSeenText: String = ""
    
    /// 待输入的文本（等待稳定）
    private var pendingText: String = ""
    
    /// 稳定性检测计时器
    private var stabilityTimer: Task<Void, Never>?
    
    /// 稳定延迟（毫秒）
    private let stabilityDelayMs: UInt64 = 500
    
    private init() {}
    
    // MARK: - Public API
    
    /// 重置状态（开始新的录音会话时调用）
    func reset() {
        lastTypedText = ""
        lastSeenText = ""
        pendingText = ""
        stabilityTimer?.cancel()
        stabilityTimer = nil
    }
    
    /// 输入文本（全量替换模式）
    /// - Parameter text: 要输入的完整文本
    func typeText(_ text: String) {
        guard !text.isEmpty else { return }
        
        // 使用 CGEvent 模拟键盘输入
        postUnicodeString(text)
        
        logger.debug("⌨️ Typed: \(text)")
    }
    
    /// 增量输入文本（只输入新增的部分）
    /// - Parameter fullText: 当前完整的文本
    /// - Returns: 实际输入的新增文本
    @discardableResult
    func typeIncremental(_ fullText: String) -> String {
        // 计算新增的部分
        let newText: String
        
        if fullText.hasPrefix(lastTypedText) {
            // 正常情况：新文本以旧文本为前缀，只输入差异部分
            newText = String(fullText.dropFirst(lastTypedText.count))
        } else {
            // 异常情况：文本发生了变化（可能是纠错）
            // 为了安全，我们不做任何操作
            // 因为回删用户已有的文本风险太大
            logger.warning("⚠️ Text changed unexpectedly, skipping: '\(self.lastTypedText)' -> '\(fullText)'")
            lastTypedText = fullText
            return ""
        }
        
        if !newText.isEmpty {
            postUnicodeString(newText)
            lastTypedText = fullText
            logger.debug("⌨️ Incremental: +\(newText)")
        }
        
        return newText
    }
    
    /// 延迟输入：等待文本稳定 500ms 后才输入
    /// - Parameters:
    ///   - finalizedText: 已确认的文本（引擎认为稳定的）
    ///   - volatileText: 预览文本（可能变化）
    func typeWithStabilityDetection(finalizedText: String, volatileText: String) {
        let fullText = finalizedText + volatileText
        
        // 如果文本没变化，不做任何事（等计时器触发）
        if fullText == lastSeenText {
            return
        }
        
        // 文本变化了，取消之前的计时器
        stabilityTimer?.cancel()
        
        // 更新待输入的文本
        pendingText = fullText
        lastSeenText = fullText
        
        // 启动新的延迟计时器
        stabilityTimer = Task { [weak self] in
            do {
                // 等待 500ms
                try await Task.sleep(nanoseconds: (self?.stabilityDelayMs ?? 500) * 1_000_000)
                
                // 检查是否被取消
                if Task.isCancelled { return }
                
                // 500ms 过去了，文本稳定，可以输入
                await self?.flushPendingText()
                
            } catch {
                // Task 被取消，正常情况
            }
        }
    }
    
    /// 强制刷新待输入的文本（录音结束时调用）
    func flushPendingText() {
        guard !pendingText.isEmpty else { return }
        
        // 取消计时器
        stabilityTimer?.cancel()
        stabilityTimer = nil
        
        // 简单策略：只输入超出已输入长度的新内容
        // 这样可以避免重复输入，但可能在纠正时漏掉中间变化的部分
        // 权衡：宁可漏掉，不要重复
        
        if lastTypedText.isEmpty {
            // 第一次输入
            postUnicodeString(pendingText)
            logger.info("⌨️ First input: \(self.pendingText)")
        } else if pendingText.count > lastTypedText.count {
            // 有新增内容：只输入超出已输入长度的部分
            let newLength = pendingText.count - lastTypedText.count
            let newContent = String(pendingText.suffix(newLength))
            
            if !newContent.isEmpty {
                postUnicodeString(newContent)
                logger.info("⌨️ Delayed input: +\(newContent)")
            }
        } else {
            // 文本变短或长度相同但内容变了（纠正）
            // 不输入任何内容，避免重复
            logger.debug("⌨️ Text corrected/shortened, skipping to avoid duplicates")
        }
        
        lastTypedText = pendingText
        pendingText = ""
    }
    
    /// 找到两个字符串的公共前缀长度
    private func findCommonPrefixLength(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let minLen = min(aChars.count, bChars.count)
        
        for i in 0..<minLen {
            if aChars[i] != bChars[i] {
                return i
            }
        }
        return minLen
    }
    
    /// 检查辅助功能权限
    static func checkAccessibilityPermission() -> Bool {
        // 检查是否有辅助功能权限（CGEvent 需要）
        let trusted = AXIsProcessTrusted()
        return trusted
    }
    
    /// 请求辅助功能权限
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
    
    // MARK: - Private
    
    /// 使用 CGEvent 发送 Unicode 字符串
    private func postUnicodeString(_ string: String) {
        guard !string.isEmpty else { return }
        
        let source = CGEventSource(stateID: .hidSystemState)
        
        // 将字符串转换为 UTF-16 数组
        var chars = Array(string.utf16)
        
        // 创建 Key Down 事件
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else {
            logger.error("❌ Failed to create key down event")
            return
        }
        
        // 设置 Unicode 字符串
        keyDown.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
        
        // 发送事件
        keyDown.post(tap: .cghidEventTap)
        
        // 创建 Key Up 事件
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
            keyUp.post(tap: .cghidEventTap)
        }
    }
    
    /// 模拟按下退格键（危险操作，暂不使用）
    /// - Parameter count: 退格次数
    private func postBackspace(count: Int) {
        guard count > 0 else { return }
        
        let source = CGEventSource(stateID: .hidSystemState)
        let backspaceKeyCode: CGKeyCode = 51  // kVK_Delete
        
        for _ in 0..<count {
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: backspaceKeyCode, keyDown: true) {
                keyDown.post(tap: .cghidEventTap)
            }
            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: backspaceKeyCode, keyDown: false) {
                keyUp.post(tap: .cghidEventTap)
            }
            
            // 小延迟避免按键丢失
            usleep(1000)  // 1ms
        }
    }
}
