import Foundation
import OSLog

// MARK: - Caption Stabilizer

/// 字幕稳定器
/// 参考 whisper_streaming 的 HypothesisBuffer 机制
/// 只输出连续多次识别结果都一致的部分，避免文字跳动
@MainActor
final class CaptionStabilizer {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "CaptionStabilizer")
    
    /// 已确认的文本（不会再变化）
    private(set) var confirmedText: String = ""
    
    /// 待确认的文本（可能变化）
    private(set) var pendingText: String = ""
    
    /// 历史假设记录（用于稳定性判断）
    private var hypothesisHistory: [String] = []
    
    /// 连续一致次数阈值（达到后确认）
    private let stabilityThreshold: Int = 2
    
    /// 最大历史记录数
    private let maxHistorySize: Int = 5
    
    /// 上一次的 volatile 文本
    private var lastVolatile: String = ""
    
    // MARK: - Public API
    
    /// 处理新的转录结果
    /// - Parameters:
    ///   - finalizedText: 已最终确认的文本
    ///   - volatileText: 可能变化的文本
    /// - Returns: (displayText, isStable) - 应显示的文本和是否稳定
    func process(finalizedText: String, volatileText: String) -> (displayText: String, translationText: String?) {
        // finalized 部分直接确认
        if !finalizedText.isEmpty {
            confirmedText = finalizedText
        }
        
        // volatile 部分使用稳定策略
        let trimmedVolatile = volatileText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedVolatile.isEmpty {
            // 无 volatile 内容
            pendingText = ""
            return (confirmedText, nil)
        }
        
        // 记录假设历史
        hypothesisHistory.append(trimmedVolatile)
        if hypothesisHistory.count > maxHistorySize {
            hypothesisHistory.removeFirst()
        }
        
        // 检查稳定性：最近 N 次是否都包含相同前缀
        let stablePrefix = findStablePrefix()
        
        if !stablePrefix.isEmpty && stablePrefix.count > 3 {
            // 有稳定前缀，显示确认部分 + 稳定前缀
            pendingText = trimmedVolatile
            let displayText = confirmedText.isEmpty ? trimmedVolatile : confirmedText + " " + trimmedVolatile
            
            // 返回需要翻译的文本（已确认部分的增量）
            return (displayText, stablePrefix)
        } else {
            // 无稳定前缀，仍然显示但标记为不稳定
            pendingText = trimmedVolatile
            let displayText = confirmedText.isEmpty ? trimmedVolatile : confirmedText + " " + trimmedVolatile
            return (displayText, nil)
        }
    }
    
    /// 找到稳定的公共前缀
    /// 检查最近几次假设是否有共同前缀
    private func findStablePrefix() -> String {
        guard hypothesisHistory.count >= stabilityThreshold else {
            return ""
        }
        
        let recentHistory = hypothesisHistory.suffix(stabilityThreshold)
        guard let first = recentHistory.first else { return "" }
        
        var commonPrefix = first
        
        for hypothesis in recentHistory.dropFirst() {
            commonPrefix = String(commonPrefix.commonPrefix(with: hypothesis))
            if commonPrefix.isEmpty { break }
        }
        
        // 在单词边界截断，避免截断单词
        if let lastSpace = commonPrefix.lastIndex(of: " ") {
            return String(commonPrefix[..<lastSpace])
        }
        
        return commonPrefix
    }
    
    /// 清空状态
    func reset() {
        confirmedText = ""
        pendingText = ""
        hypothesisHistory.removeAll()
        lastVolatile = ""
    }
}

// MARK: - String Extension

extension String {
    /// 获取两个字符串的公共前缀
    func commonPrefix(with other: String) -> String {
        var result = ""
        let selfChars = Array(self)
        let otherChars = Array(other)
        let minLength = min(selfChars.count, otherChars.count)
        
        for i in 0..<minLength {
            if selfChars[i] == otherChars[i] {
                result.append(selfChars[i])
            } else {
                break
            }
        }
        
        return result
    }
}
