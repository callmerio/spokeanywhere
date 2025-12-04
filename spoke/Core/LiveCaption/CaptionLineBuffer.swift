import Foundation
import OSLog

// MARK: - Caption Line

/// 字幕行
struct CaptionLine: Identifiable, Equatable {
    let id: UUID
    let original: String
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
/// 实现2行滚动窗口逻辑：固定显示最新2行，智能分句
@MainActor
final class CaptionLineBuffer: ObservableObject {
    
    // MARK: - Constants
    
    /// 每行最大字符数（18pt字体，560pt可用宽度）
    /// 中文约 30 字符，英文约 56 字符
    /// 取中间值 40 作为换行阈值
    private static let maxCharsPerLine: Int = 50
    
    /// 最大显示行数
    private static let maxLines: Int = 2
    
    /// 分句标点符号
    private static let sentenceBreaks: Set<Character> = [".", "?", "!", "。", "？", "！", "；", "…"]
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "CaptionLineBuffer")
    
    /// 当前显示的行（最多2行）
    @Published private(set) var lines: [CaptionLine] = []
    
    /// 当前未完成的句子片段（实时输入中）
    @Published private(set) var pendingFragment: String = ""
    

    
    // MARK: - Public API
    
    /// 追加实时输入文本（volatile）
    func updatePending(_ text: String) {
        pendingFragment = text
    }
    
    /// 追加确定的文本（finalized）
    /// - Parameters:
    ///   - text: 新增的原文
    ///   - translation: 对应的译文（可能稍后到达）
    func append(text: String, translation: String? = nil) {
        guard !text.isEmpty else { return }
        
        // 清空 pending
        pendingFragment = ""
        
        // 分句处理
        let sentences = splitSentences(text)
        
        for sentence in sentences {
            commitSentence(sentence, translation: translation)
        }
    }
    
    /// 更新最后一行的译文
    func updateLastTranslation(_ translation: String) {
        guard !lines.isEmpty else { return }
        lines[lines.count - 1].translated = translation
    }
    
    /// 清空所有内容
    func clear() {
        lines.removeAll()
        pendingFragment = ""
    }
    
    // MARK: - Private
    
    /// 分句：按标点拆分
    private func splitSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        
        for char in text {
            current.append(char)
            
            // 遇到分句标点
            if Self.sentenceBreaks.contains(char) {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    sentences.append(trimmed)
                }
                current = ""
            }
        }
        
        // 剩余部分（未结束的句子）
        let remaining = current.trimmingCharacters(in: .whitespaces)
        if !remaining.isEmpty {
            sentences.append(remaining)
        }
        
        return sentences
    }
    
    /// 提交一个句子
    private func commitSentence(_ sentence: String, translation: String?) {
        // 如果没有行，直接添加第1行
        guard let lastLine = lines.last else {
            lines.append(CaptionLine(original: sentence, translated: translation))
            return
        }
        
        // 尝试拼接到最后一行
        let combined = lastLine.original + " " + sentence
        
        // 判断是否能拼接到最后一行
        if combined.count <= Self.maxCharsPerLine {
            // 拼接到最后一行
            lines[lines.count - 1] = CaptionLine(
                original: combined,
                translated: mergeTranslation(lastLine.translated, translation),
                timestamp: lastLine.timestamp
            )
        } else {
            // 需要换行
            if lines.count >= Self.maxLines {
                // 滚动：移除第1行，第2行升级为第1行
                lines.removeFirst()
            }
            
            // 添加新行
            lines.append(CaptionLine(original: sentence, translated: translation))
        }
        
        // logger.debug("📝 Lines: \(self.lines.map { $0.original })")
    }
    
    /// 合并译文
    private func mergeTranslation(_ existing: String?, _ new: String?) -> String? {
        switch (existing, new) {
        case (nil, nil):
            return nil
        case (let e?, nil):
            return e
        case (nil, let n?):
            return n
        case (let e?, let n?):
            return e + " " + n
        }
    }
}
