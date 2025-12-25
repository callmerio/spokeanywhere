import Foundation
import OSLog

private let logger = Logger(subsystem: "com.spokeanywhere", category: "UnifiedDictionaryService")

// MARK: - Unified Dictionary Result

/// 统一查词结果 - 聚合本地和在线数据源
struct UnifiedDictionaryResult: Identifiable, Equatable {
    let id = UUID()
    let word: String
    let phonetic: String?
    let senses: [UnifiedSense]
    let source: DataSource
    let lemma: String?        // 原型词（如 sustains -> sustain）
    let formNote: String?     // 词形说明（如"第三人称单数"）
    
    enum DataSource: String {
        case local = "本地词典"
        case remote = "在线词典"
        case mixed = "混合"
    }
    
    /// 简要释义 - 格式: "v. 维持；支撑  n. 支持"
    var briefDefinition: String {
        var posMeanings: [(pos: String, meanings: [String])] = []
        
        for sense in senses {
            if let chinese = sense.chinese, !chinese.isEmpty {
                let pos = sense.posAbbr
                if let idx = posMeanings.firstIndex(where: { $0.pos == pos }) {
                    if posMeanings[idx].meanings.count < 2 {
                        posMeanings[idx].meanings.append(chinese)
                    }
                } else {
                    posMeanings.append((pos, [chinese]))
                }
            }
        }
        
        guard !posMeanings.isEmpty else {
            // Fallback: 使用英文释义
            if let first = senses.first?.english {
                return first.count > 50 ? String(first.prefix(50)) + "..." : first
            }
            return ""
        }
        
        let parts = posMeanings.prefix(3).map { pos, meanings in
            "\(pos) \(meanings.joined(separator: "；"))"
        }
        let combined = parts.joined(separator: "  ")
        return combined.count > 60 ? String(combined.prefix(60)) + "..." : combined
    }
}

/// 统一释义条目
struct UnifiedSense: Identifiable, Equatable {
    let id = UUID()
    let pos: String?
    let chinese: String?
    let english: String?
    let examples: [String]
    
    var posAbbr: String {
        guard let pos = pos else { return "" }
        let abbrs: [String: String] = [
            "noun": "n.", "verb": "v.", "adjective": "adj.", "adverb": "adv.",
            "preposition": "prep.", "conjunction": "conj.", "pronoun": "pron.",
            "interjection": "interj.", "determiner": "det.", "article": "art.",
            "n": "n.", "v": "v.", "adj": "adj.", "adv": "adv."
        ]
        return abbrs[pos.lowercased()] ?? pos
    }
}

// MARK: - Unified Dictionary Service

/// 统一查词服务 - 本地优先，在线兜底
@MainActor
final class UnifiedDictionaryService {
    
    // MARK: - Singleton
    
    static let shared = UnifiedDictionaryService()
    
    // MARK: - Dependencies
    
    private let localService = LocalDictionaryService.shared
    private let remoteService = DictionaryAPIService.shared
    
    // MARK: - Cache
    
    private var cache: [String: UnifiedDictionaryResult] = [:]
    private var cacheOrder: [String] = []
    private let maxCacheSize = 100
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Public API
    
    /// 查询单词 - 本地优先，无中文释义时调用在线
    /// - Parameter word: 要查询的单词
    /// - Returns: 统一格式的查词结果
    func lookup(_ word: String) async -> UnifiedDictionaryResult? {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        
        // 检查缓存
        if let cached = cache[trimmed] {
            logger.debug("📖 [Unified] 缓存命中: \(trimmed)")
            return cached
        }
        
        // Step 1: 查询本地词典
        if let localResult = localService.lookup(trimmed) {
            let unified = convertLocalResult(localResult)
            
            // 如果有中文释义，直接返回
            if unified.senses.contains(where: { $0.chinese != nil && !$0.chinese!.isEmpty }) {
                logger.info("📖 [Unified] 本地有中文释义: \(trimmed)")
                cacheResult(word: trimmed, result: unified)
                return unified
            }
            
            logger.info("📖 [Unified] 本地无中文释义，尝试在线: \(trimmed)")
        }
        
        // Step 2: 调用在线 API（词形还原 + 中文释义）
        let remoteResult = await remoteService.lookup(trimmed)
        
        switch remoteResult {
        case .success(let data):
            let unified = convertRemoteResult(data)
            logger.info("📖 [Unified] 在线查询成功: \(trimmed) (\(unified.senses.count) 条释义)")
            cacheResult(word: trimmed, result: unified)
            return unified
            
        case .failure(let error):
            logger.warning("📖 [Unified] 在线查询失败: \(error.localizedDescription)")
            
            // Fallback: 返回本地结果（即使没有中文释义）
            if let localResult = localService.lookup(trimmed) {
                let unified = convertLocalResult(localResult)
                cacheResult(word: trimmed, result: unified)
                return unified
            }
            
            return nil
        }
    }
    
    /// 仅查询本地词典（同步，不调用网络）
    func lookupLocal(_ word: String) -> UnifiedDictionaryResult? {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let localResult = localService.lookup(trimmed) else { return nil }
        return convertLocalResult(localResult)
    }
    
    /// 清除缓存
    func clearCache() {
        cache.removeAll()
        cacheOrder.removeAll()
        logger.info("📖 [Unified] 缓存已清除")
    }
    
    // MARK: - Private Converters
    
    private func convertLocalResult(_ local: LocalDictionaryResult) -> UnifiedDictionaryResult {
        // 解析本地词典的 definition 字段
        let parsed = DictionaryDefinitionParser.shared.parse(word: local.word, definition: local.definition)
        
        var senses: [UnifiedSense] = []
        for section in parsed.sections {
            for sense in section.senses {
                // 提取例句的英文部分
                let exampleStrings = sense.examples.map { $0.english }
                senses.append(UnifiedSense(
                    pos: section.pos,
                    chinese: sense.chinese,
                    english: nil,  // 本地词典没有单独的英文释义
                    examples: exampleStrings
                ))
            }
        }
        
        // 如果解析失败，使用原始数据
        if senses.isEmpty {
            senses.append(UnifiedSense(
                pos: local.pos,
                chinese: local.chineseDefinition,
                english: local.definition,
                examples: []
            ))
        }
        
        return UnifiedDictionaryResult(
            word: local.word,
            phonetic: local.phonetic,
            senses: senses,
            source: .local,
            lemma: nil,
            formNote: nil
        )
    }

    
    private func convertRemoteResult(_ remote: DictionaryData) -> UnifiedDictionaryResult {
        let effectiveSenses = remote.effectiveSenses
        
        let senses: [UnifiedSense] = effectiveSenses.map { sense in
            UnifiedSense(
                pos: sense.pos,
                chinese: sense.chinese,
                english: sense.english,
                examples: sense.examples ?? []
            )
        }
        
        return UnifiedDictionaryResult(
            word: remote.word,
            phonetic: remote.phonetic,
            senses: senses,
            source: .remote,
            lemma: remote.lemmaWord,
            formNote: remote.formTypeDisplay
        )
    }
    
    // MARK: - Cache Management (LRU)
    
    private func cacheResult(word: String, result: UnifiedDictionaryResult) {
        if cache[word] == nil {
            cacheOrder.append(word)
            if cacheOrder.count > maxCacheSize {
                let oldest = cacheOrder.removeFirst()
                cache.removeValue(forKey: oldest)
            }
        }
        cache[word] = result
    }
}
