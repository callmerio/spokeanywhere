import Foundation

// MARK: - Dictionary Entry Source

/// 词典条目来源
enum DictionaryEntrySource: String, Codable, CaseIterable {
    case manual      // 手动添加
    case auto        // 自动推荐（热词挖掘）
    
    var displayName: String {
        switch self {
        case .manual: return "手动添加"
        case .auto: return "自动添加"
        }
    }
    
    var icon: String {
        switch self {
        case .manual: return "pencil"
        case .auto: return "sparkles"
        }
    }
}

// MARK: - Dictionary Entry

/// 词典条目模型
/// 用于存储用户自定义词汇，帮助提高转录准确性
struct DictionaryEntry: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    
    /// 期望的正确词形（用户最终想要的输出）
    /// 例如: "Anthropic", "Claude", "GPT-4"
    var word: String
    
    /// 纠错映射：可能的错误识别形式
    /// 转录引擎可能识别成的各种形式，后处理时会替换为正确词形
    /// 例如: ["安索皮克", "anthropick", "anthro pick"] → 替换为 "Anthropic"
    var corrections: [String]
    
    /// 条目来源
    var source: DictionaryEntrySource
    
    /// 使用频率（用于热词排序）
    var frequency: Int
    
    /// 创建时间
    let createdAt: Date
    
    /// 最后使用时间
    var lastUsedAt: Date?
    
    /// 是否已被用户确认（仅对自动推荐的热词有效）
    /// 自动推荐的热词需要用户确认后才会在转录中生效
    var confirmedByUser: Bool
    
    /// 训练短语：包含该词的完整句子
    /// 用于预编译 LM，提高 ASR 识别率（WWDC23 推荐方式）
    /// 例如: ["Claude 是一个 AI 助手", "我想用 Claude 写代码"]
    var trainingPhrases: [String]
    
    // MARK: - Init
    
    init(
        id: UUID = UUID(),
        word: String,
        corrections: [String] = [],
        source: DictionaryEntrySource = .manual,
        frequency: Int = 0,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil,
        confirmedByUser: Bool = true,
        trainingPhrases: [String] = []
    ) {
        self.id = id
        self.word = word.trimmingCharacters(in: .whitespacesAndNewlines)
        self.corrections = corrections.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.source = source
        self.frequency = frequency
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        // 手动添加的默认已确认，自动推荐的默认未确认
        self.confirmedByUser = source == .manual ? true : confirmedByUser
        self.trainingPhrases = trainingPhrases
    }
    
    // MARK: - Computed Properties
    
    /// 格式化创建时间
    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: createdAt)
    }
    
    /// 相对创建时间
    var relativeCreatedAt: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    /// 是否是生效状态（手动添加或已确认的自动推荐）
    var isActive: Bool {
        source == .manual || confirmedByUser
    }
    
    /// 所有可能的匹配词（word + corrections）
    var allMatchPatterns: [String] {
        [word.lowercased()] + corrections.map { $0.lowercased() }
    }
}

// MARK: - Dictionary Entry + Matching

extension DictionaryEntry {
    
    /// 检查文本是否匹配此词典条目的纠错项
    /// - Parameter text: 要检查的文本（通常是转录结果）
    /// - Returns: 匹配到的错误形式（如果有）
    func matches(in text: String) -> String? {
        let lowercasedText = text.lowercased()
        
        // 检查纠错项（错误识别形式）
        for correction in corrections {
            let lowercasedCorrection = correction.lowercased()
            if lowercasedText.contains(lowercasedCorrection) {
                return correction
            }
        }
        
        return nil
    }
    
    /// 用正确词形替换匹配到的错误形式
    /// - Parameter text: 原始文本
    /// - Returns: 替换后的文本
    func replace(in text: String) -> String {
        var result = text
        
        for errorForm in corrections {
            // 使用不区分大小写的替换
            let pattern = NSRegularExpression.escapedPattern(for: errorForm)
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: word
                )
            }
        }
        
        return result
    }
}

// MARK: - Batch Import Result

/// 批量导入结果
struct DictionaryImportResult {
    let successCount: Int
    let duplicateCount: Int
    let errorCount: Int
    let entries: [DictionaryEntry]
}
