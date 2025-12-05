import Foundation
import OSLog

// MARK: - Caption Line

/// 字幕行
struct CaptionLine: Identifiable, Equatable {
    let id: UUID
    var original: String
    var translated: String?
    let timestamp: Date
    
    init(id: UUID = UUID(), original: String, translated: String? = nil, timestamp: Date = Date()) {
        self.id = id
        self.original = original
        self.translated = translated
        self.timestamp = timestamp
    }
}

// MARK: - Caption Line Buffer

/// 字幕行缓冲区管理
/// 简化模型（类似 O+R）：直接显示 finalized + volatile，允许回退修改
@MainActor
final class CaptionLineBuffer: ObservableObject {
    
    // MARK: - Configuration
    
    /// 行字符上限 - UI宽672px-48px=624px，约18pt字7px/字符≈80+字符
    private let lineCharLimit = 78
    /// 最大显示行数
    private let maxDisplayLines = 2
    
    // MARK: - State
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "CaptionLineBuffer")
    
    /// 当前显示的原文
    @Published private(set) var displayText: String = ""
    
    /// 当前显示的译文
    @Published private(set) var translatedText: String = ""
    
    /// 待翻译的稳定文本（用于触发翻译）
    @Published private(set) var stableTextForTranslation: String?
    
    /// 兼容旧 API：lines 数组
    @Published private(set) var lines: [CaptionLine] = []
    
    /// 兼容旧 API
    @Published private(set) var pendingFragment: String = ""
    
    /// 累积的已翻译文本
    private var accumulatedTranslation: String = ""
    
    // MARK: - Public API
    
    /// 处理转录结果（finalized + volatile）
    /// 简化逻辑：直接拼接显示，允许回退修改（类似 O+R）
    func update(finalizedText: String, volatileText: String) {
        // 直接拼接 finalized + volatile
        let fullText = (finalizedText + volatileText).trimmingCharacters(in: .whitespaces)
        
        // 智能分行，取最后 N 行
        let newDisplayText = formatForDisplay(fullText)
        
        // 更新 UI
        if newDisplayText != displayText {
            displayText = newDisplayText
            updateLegacyLines()
        }
    }
    
    // MARK: - 核心逻辑
    
    /// 格式化文本用于显示：智能分行，取最后 maxDisplayLines 行
    private func formatForDisplay(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        
        // 将文本分成多行（每行最多 lineCharLimit 字符）
        let lines = splitIntoLines(text)
        
        // 取最后 maxDisplayLines 行
        let visibleLines = lines.suffix(maxDisplayLines)
        return visibleLines.joined(separator: "\n")
    }
    
    /// 将文本智能分行
    private func splitIntoLines(_ text: String) -> [String] {
        var lines: [String] = []
        var remaining = text
        
        while !remaining.isEmpty {
            if remaining.count <= lineCharLimit {
                lines.append(remaining)
                break
            }
            
            // 找最佳切分点
            let splitPoint = findBestSplitPoint(remaining)
            let splitIdx = remaining.index(remaining.startIndex, offsetBy: splitPoint)
            
            let line = String(remaining[..<splitIdx]).trimmingCharacters(in: .whitespaces)
            if !line.isEmpty {
                lines.append(line)
            }
            
            remaining = String(remaining[splitIdx...]).trimmingLeadingWhitespace()
        }
        
        return lines
    }
    
    /// 找最佳切分点
    /// 优先级: 空格 > 标点 > 强制切分
    private func findBestSplitPoint(_ text: String) -> Int {
        let length = text.count
        guard length > lineCharLimit else { return length }
        
        // 搜索范围: [lineCharLimit * 0.7, lineCharLimit]
        let searchStart = max(Int(Double(lineCharLimit) * 0.7), 40)
        let searchEnd = lineCharLimit
        
        let startIdx = text.index(text.startIndex, offsetBy: searchStart)
        let endIdx = text.index(text.startIndex, offsetBy: searchEnd)
        let searchRange = startIdx..<endIdx
        
        // 1. 找空格（最高优先级）
        if let spaceIdx = text[searchRange].lastIndex(of: " ") {
            return text.distance(from: text.startIndex, to: text.index(after: spaceIdx))
        }
        
        // 2. 找标点
        let punctuation: Set<Character> = [".", "。", "!", "?", "！", "？", ",", "，", ";", "；"]
        if let punctIdx = text[searchRange].lastIndex(where: { punctuation.contains($0) }) {
            return text.distance(from: text.startIndex, to: text.index(after: punctIdx))
        }
        
        // 3. 强制切分
        return searchEnd
    }
    
    /// 清空所有内容
    func clear() {
        displayText = ""
        translatedText = ""
        accumulatedTranslation = ""
        stableTextForTranslation = nil
        lines.removeAll()
        pendingFragment = ""
        logger.info("🧹 CaptionLineBuffer cleared")
    }
    
    // MARK: - 兼容旧 API
    
    /// 更新译文
    func updateTranslation(_ translation: String) {
        guard !translation.isEmpty else { return }
        
        if accumulatedTranslation.isEmpty {
            accumulatedTranslation = translation
        } else {
            accumulatedTranslation += translation
        }
        translatedText = truncateForDisplay(accumulatedTranslation, maxLength: 150)
        
        if !lines.isEmpty {
            lines[0].translated = translatedText
        }
        stableTextForTranslation = nil
    }
    
    /// 追加实时输入文本（volatile）- 兼容旧 API
    func updatePending(_ text: String) {
        pendingFragment = text
        // 简化：直接更新显示
        let newDisplay = formatForDisplay(text)
        if newDisplay != displayText {
            displayText = newDisplay
            updateLegacyLines()
        }
    }
    
    /// 追加确定的文本（finalized）- 兼容旧 API
    func append(text: String, translation: String? = nil) {
        guard !text.isEmpty else { return }
        pendingFragment = ""
        if let trans = translation {
            translatedText = trans
            accumulatedTranslation = trans
        }
        // 简化：直接更新显示
        let newDisplay = formatForDisplay(text)
        if newDisplay != displayText {
            displayText = newDisplay
            updateLegacyLines()
        }
    }
    
    /// 更新最后一行的译文 - 兼容旧 API
    func updateLastTranslation(_ translation: String) {
        updateTranslation(translation)
    }
    
    // MARK: - Private Helpers
    
    /// 截断文本用于显示（保持最后 N 个字符）
    private func truncateForDisplay(_ text: String, maxLength: Int = 200) -> String {
        guard !text.isEmpty else { return "" }
        guard text.count > maxLength else { return text }
        
        let startIndex = text.index(text.endIndex, offsetBy: -maxLength)
        let searchRange = startIndex..<text.endIndex
        
        if let spaceIndex = text[searchRange].firstIndex(of: " ") {
            return String(text[spaceIndex...]).trimmingCharacters(in: .whitespaces)
        }
        return String(text[startIndex...])
    }
    
    /// 更新兼容的 lines 数组
    private func updateLegacyLines() {
        if displayText.isEmpty && translatedText.isEmpty {
            lines.removeAll()
            return
        }
        
        if lines.isEmpty {
            lines = [CaptionLine(original: displayText, translated: translatedText.isEmpty ? nil : translatedText)]
        } else {
            lines[0].original = displayText
            lines[0].translated = translatedText.isEmpty ? nil : translatedText
        }
    }
}

// MARK: - String Extension

private extension String {
    /// 去除前导空白
    func trimmingLeadingWhitespace() -> String {
        guard let firstNonWhitespace = firstIndex(where: { !$0.isWhitespace }) else {
            return ""
        }
        return String(self[firstNonWhitespace...])
    }
}
