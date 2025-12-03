import Foundation
import os

// MARK: - Transcription Post Processor

/// 转录后处理器
/// 负责在转录结果返回后应用词典匹配、热词学习等处理
/// 为后续 Whisper 等模型的词典学习预留接口
@MainActor
final class TranscriptionPostProcessor {
    
    // MARK: - Singleton
    
    static let shared = TranscriptionPostProcessor()
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "TranscriptionPostProcessor")
    
    // MARK: - Configuration
    
    /// 是否启用词典匹配
    var isDictionaryEnabled: Bool = true
    
    /// 是否启用热词学习（自动记录词频）
    var isHotwordLearningEnabled: Bool = true
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Public API
    
    /// 处理转录结果
    /// - Parameter result: 原始转录结果
    /// - Returns: 处理后的转录结果
    func process(_ result: TranscriptionResult) -> TranscriptionResult {
        var processedFinalizedText = result.finalizedText
        var processedVolatileText = result.volatileText
        
        // 1. 词典纠错（corrections → word 映射）
        // 默认使用 LLM 智能纠错（在 LLMPipeline 中处理），不在这里强制替换
        // 只有当用户关闭 LLM 智能纠错时，才在这里进行强制替换
        if isDictionaryEnabled && !UserDefaults.standard.useLLMForCorrection {
            let dictionaryService = DictionaryService.shared
            
            // 对已确认文本应用词典（强制替换模式）
            if !result.finalizedText.isEmpty {
                processedFinalizedText = dictionaryService.applyDictionary(to: result.finalizedText)
            }
            
            // 对最终结果的完整文本应用词典
            if result.type == .final {
                processedFinalizedText = dictionaryService.applyDictionary(to: result.text)
                processedVolatileText = ""
            }
        }
        
        // 2. 热词学习（记录词频）
        if isHotwordLearningEnabled && result.type == .final {
            learnHotwords(from: result.text)
        }
        
        // 返回处理后的结果
        return TranscriptionResult(
            finalizedText: processedFinalizedText,
            volatileText: processedVolatileText,
            type: result.type,
            confidence: result.confidence,
            timestamp: result.timestamp
        )
    }
    
    // MARK: - Hotword Learning
    
    /// 从转录文本中学习热词
    /// 提取可能的专有名词、术语等
    private func learnHotwords(from text: String) {
        // 提取可能的热词候选
        let candidates = extractHotwordCandidates(from: text)
        
        let dictionaryService = DictionaryService.shared
        for candidate in candidates {
            dictionaryService.recordWordUsage(candidate)
        }
        
        if !candidates.isEmpty {
            logger.debug("📚 Learned \(candidates.count) hotword candidates")
        }
    }
    
    /// 从文本中提取热词候选
    /// - Parameter text: 转录文本
    /// - Returns: 热词候选列表
    private func extractHotwordCandidates(from text: String) -> [String] {
        var candidates: [String] = []
        
        // 策略 1: 提取英文单词（可能是专有名词、品牌名等）
        let englishPattern = "[A-Z][a-zA-Z]+|[A-Z]{2,}" // 大写开头或全大写
        if let regex = try? NSRegularExpression(pattern: englishPattern, options: []) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, options: [], range: range)
            
            for match in matches {
                if let range = Range(match.range, in: text) {
                    let word = String(text[range])
                    // 过滤常见词
                    if !isCommonWord(word) && word.count >= 3 {
                        candidates.append(word)
                    }
                }
            }
        }
        
        // 策略 2: 提取中英混合词（如 "GPT-4", "iPhone"）
        let mixedPattern = "[A-Za-z]+[-]?\\d+|[A-Za-z]+[A-Z][a-z]+"
        if let regex = try? NSRegularExpression(pattern: mixedPattern, options: []) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, options: [], range: range)
            
            for match in matches {
                if let range = Range(match.range, in: text) {
                    let word = String(text[range])
                    if word.count >= 2 {
                        candidates.append(word)
                    }
                }
            }
        }
        
        // 去重
        return Array(Set(candidates))
    }
    
    /// 检查是否是常见词（不应作为热词）
    private func isCommonWord(_ word: String) -> Bool {
        let commonWords = Set([
            "The", "This", "That", "There", "These", "Those",
            "What", "When", "Where", "Why", "How", "Who",
            "And", "But", "Or", "Not", "No", "Yes",
            "It", "Is", "Are", "Was", "Were", "Be", "Been",
            "Have", "Has", "Had", "Do", "Does", "Did",
            "Will", "Would", "Could", "Should", "May", "Might",
            "Can", "Cannot", "With", "From", "Into", "For",
            "To", "In", "On", "At", "By", "As", "Of",
            "If", "Then", "So", "Very", "Just", "Only",
            "About", "After", "Before", "Between", "Under", "Over"
        ])
        return commonWords.contains(word)
    }
}

// MARK: - Whisper Integration Placeholder

/// Whisper 词典学习接口（预留）
/// 当后续集成 Whisper 模型时，可以通过此接口传递词典数据
@MainActor
protocol WhisperDictionaryProvider {
    /// 获取词典数据用于 Whisper 的 prompt/context
    func getDictionaryPrompt() -> String
    
    /// 获取热词列表用于 Whisper 的 initial_prompt
    func getHotwordList() -> [String]
}

extension DictionaryService: WhisperDictionaryProvider {
    
    /// 生成用于 Whisper prompt 的词典文本
    /// Whisper 支持在 initial_prompt 中加入常用词汇来提高识别准确率
    func getDictionaryPrompt() -> String {
        // 获取所有活跃词条
        let words = activeEntries.map { $0.word }
        
        guard !words.isEmpty else { return "" }
        
        // 格式化为 Whisper 友好的格式
        // Whisper 的 initial_prompt 应该是一段自然的文本
        return "常用词汇: " + words.joined(separator: ", ") + "。"
    }
    
    /// 获取热词列表
    func getHotwordList() -> [String] {
        activeEntries.map { $0.word }
    }
}

// MARK: - Dictionary Weight Level

/// 词典权重级别
/// 控制词典对 ASR 识别的影响程度
enum DictionaryWeightLevel: String, CaseIterable, Identifiable {
    /// 轻量：基础提示，不影响正常识别
    case light = "light"
    /// 标准：适度提升词典词的识别概率
    case standard = "standard"
    /// 增强：显著提升，适合专业术语场景
    case enhanced = "enhanced"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .light: return "轻量"
        case .standard: return "标准"
        case .enhanced: return "增强"
        }
    }
    
    var description: String {
        switch self {
        case .light: return "基础提示，尊重原始识别"
        case .standard: return "适度提升词典词的识别概率"
        case .enhanced: return "优先识别词典词，适合专业场景"
        }
    }
    
    /// 基础权重值
    var baseWeight: Int {
        switch self {
        case .light: return 3
        case .standard: return 8
        case .enhanced: return 20
        }
    }
    
    /// 最大权重值
    var maxWeight: Int {
        switch self {
        case .light: return 15
        case .standard: return 40
        case .enhanced: return 80
        }
    }
}

// MARK: - AppSettings Extension

extension UserDefaults {
    
    private enum DictionaryKeys {
        static let isDictionaryEnabled = "dictionary.isEnabled"
        static let isHotwordLearningEnabled = "dictionary.hotwordLearningEnabled"
        static let weightLevel = "dictionary.weightLevel"
        static let useLLMForCorrection = "dictionary.useLLMForCorrection"
    }
    
    var isDictionaryEnabled: Bool {
        get { bool(forKey: DictionaryKeys.isDictionaryEnabled) }
        set { set(newValue, forKey: DictionaryKeys.isDictionaryEnabled) }
    }
    
    var isHotwordLearningEnabled: Bool {
        get {
            // 默认开启
            if object(forKey: DictionaryKeys.isHotwordLearningEnabled) == nil {
                return true
            }
            return bool(forKey: DictionaryKeys.isHotwordLearningEnabled)
        }
        set { set(newValue, forKey: DictionaryKeys.isHotwordLearningEnabled) }
    }
    
    /// 词典权重级别
    var dictionaryWeightLevel: DictionaryWeightLevel {
        get {
            guard let raw = string(forKey: DictionaryKeys.weightLevel),
                  let level = DictionaryWeightLevel(rawValue: raw) else {
                return .light  // 默认轻量
            }
            return level
        }
        set { set(newValue.rawValue, forKey: DictionaryKeys.weightLevel) }
    }
    
    /// 是否使用 LLM 进行智能纠错（而非强制替换）
    var useLLMForCorrection: Bool {
        get {
            // 默认开启智能纠错
            if object(forKey: DictionaryKeys.useLLMForCorrection) == nil {
                return true
            }
            return bool(forKey: DictionaryKeys.useLLMForCorrection)
        }
        set { set(newValue, forKey: DictionaryKeys.useLLMForCorrection) }
    }
}
