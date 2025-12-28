import AppKit
import CoreServices
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.spokeanywhere", category: "LocalDictionaryService")

// MARK: - Private Dictionary Services API

/// 获取所有活动词典（私有 API）
@_silgen_name("DCSGetActiveDictionaries")
func DCSGetActiveDictionaries() -> Unmanaged<CFArray>?

// MARK: - Local Dictionary Result

struct LocalDictionaryResult: Identifiable, Equatable {
    /// 基于 word 的稳定 ID (SwiftUI ForEach 需要稳定 ID 来正确追踪 cell)
    var id: String { word.lowercased() }
    let word: String
    let definition: String
    let pos: String?
    let phonetic: String?
    let chineseDefinition: String?
    
    var briefDefinition: String {
        // 格式: adj. 好的；健康的  v. 很好  adv. 非常
        // 每个词性后跟该词性的释义
        let parsed = DictionaryDefinitionParser.shared.parse(word: word, definition: definition)
        
        // 按词性分组收集释义
        var posMeanings: [(pos: String, meanings: [String])] = []
        let posAbbr: [String: String] = [
            "adjective": "adj.", "noun": "n.", "verb": "v.", 
            "adverb": "adv.", "preposition": "prep.", "pronoun": "pron.",
            "conjunction": "conj.", "interjection": "interj.", "determiner": "det.",
            "transitive verb": "vt.", "intransitive verb": "vi."
        ]
        
        for section in parsed.sections {
            let abbr = posAbbr[section.pos.lowercased()] ?? section.pos
            var meanings: [String] = []
            for sense in section.senses.prefix(2) { // 每个词性最多取2个义项
                if let chinese = sense.chinese, !chinese.isEmpty {
                    meanings.append(chinese)
                }
            }
            if !meanings.isEmpty {
                posMeanings.append((abbr, meanings))
            }
        }
        
        if !posMeanings.isEmpty {
            // 格式: adj. 好的；健康的  v. 很好
            let parts = posMeanings.prefix(3).map { pos, meanings in
                "\(pos) \(meanings.joined(separator: "；"))"
            }
            let combined = parts.joined(separator: "  ")
            if combined.count > 60 {
                return String(combined.prefix(60)) + "..."
            }
            return combined
        }
        
        // Fallback: 使用原有的 chineseDefinition
        if let chinese = chineseDefinition, !chinese.isEmpty {
            return chinese
        }
        
        // 最后 fallback: 取第一行
        let cleaned = definition
            .replacingOccurrences(of: #"\|[^|]+\|"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = cleaned.components(separatedBy: "\n").first ?? definition
        if firstLine.count > 60 {
            return String(firstLine.prefix(60)) + "..."
        }
        return firstLine
    }
}

// MARK: - Local Dictionary Service

final class LocalDictionaryService: @unchecked Sendable {
    
    // MARK: - Singleton
    
    static let shared = LocalDictionaryService()
    
    // MARK: - Properties
    
    private var searchHistory: [String] = []
    private let maxHistoryCount = 20
    
    /// 查询缓存 - 避免重复调用 DCSCopyTextDefinition
    private var lookupCache: [String: LocalDictionaryResult] = [:]
    private var lookupCacheOrder: [String] = []  // LRU 顺序
    private let maxCacheSize = 200
    
    /// 线程同步锁
    private let lock = NSLock()
    
    // MARK: - Init
    
    private init() {
        loadHistory()
    }
    
    // MARK: - Public API
    
    /// 查询单词定义 - 优先返回英汉词典（包含中文释义）
    func lookup(_ word: String) -> LocalDictionaryResult? {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        
        // 检查缓存（线程安全）
        lock.lock()
        let cached = lookupCache[trimmed]
        lock.unlock()
        if let cached = cached {
            return cached
        }
        
        let range = CFRangeMake(0, trimmed.count)
        
        // 尝试从所有词典中查找，优先返回包含中文的定义
        var bestResult: LocalDictionaryResult?
        var fallbackResult: LocalDictionaryResult?
        
        // 获取所有活动词典
        if let dictionaries = DCSGetActiveDictionaries()?.takeUnretainedValue() {
            let count = CFArrayGetCount(dictionaries)
            for i in 0..<count {
                let dictRef = unsafeBitCast(CFArrayGetValueAtIndex(dictionaries, i), to: DCSDictionary.self)
                if let definition = DCSCopyTextDefinition(dictRef, trimmed as CFString, range) {
                    let defString = definition.takeRetainedValue() as String
                    let parsed = parseDefinition(word: trimmed, definition: defString)
                    
                    // 如果有中文释义，优先使用
                    if parsed.chineseDefinition != nil && !parsed.chineseDefinition!.isEmpty {
                        bestResult = parsed
                        break // 找到英汉词典结果，停止搜索
                    }
                    
                    // 保存第一个有效结果作为 fallback
                    if fallbackResult == nil {
                        fallbackResult = parsed
                    }
                }
            }
        }
        
        // 如果遍历词典没找到，尝试默认查询
        if bestResult == nil && fallbackResult == nil {
            if let definition = DCSCopyTextDefinition(nil, trimmed as CFString, range) {
                let defString = definition.takeRetainedValue() as String
                fallbackResult = parseDefinition(word: trimmed, definition: defString)
            }
        }
        
        guard let result = bestResult ?? fallbackResult else {
            return nil
        }
        
        // 缓存结果
        cacheLookupResult(word: trimmed, result: result)
        
        return result
    }
    
    /// 缓存查询结果 (LRU, 线程安全)
    private func cacheLookupResult(word: String, result: LocalDictionaryResult) {
        lock.lock()
        defer { lock.unlock() }
        
        if lookupCache[word] == nil {
            lookupCacheOrder.append(word)
            // LRU 淘汰
            if lookupCacheOrder.count > maxCacheSize {
                let oldest = lookupCacheOrder.removeFirst()
                lookupCache.removeValue(forKey: oldest)
            }
        }
        lookupCache[word] = result
    }
    
    /// 搜索单词 (前缀匹配 - 使用 NSSpellChecker 补全 + 历史记录)
    func search(_ query: String) -> [LocalDictionaryResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            return getRecentWords()
        }
        
        var results: [LocalDictionaryResult] = []
        var addedWords: Set<String> = []
        
        // 1. 精确查询当前输入（最高优先级）
        if let exactMatch = lookup(trimmed) {
            results.append(exactMatch)
            addedWords.insert(exactMatch.word.lowercased())
            logger.debug("📖 [LocalDict] 搜索添加精确匹配: \(exactMatch.word)")
        }
        
        // 2. 使用 NSSpellChecker 获取单词补全建议（核心：实现前缀搜索）
        let spellChecker = NSSpellChecker.shared
        let completions = spellChecker.completions(
            forPartialWordRange: NSRange(location: 0, length: trimmed.count),
            in: trimmed,
            language: "en",
            inSpellDocumentWithTag: 0
        ) ?? []
        
        for completion in completions.prefix(8) {
            let word = completion.lowercased()
            guard !addedWords.contains(word) else { continue }
            if results.count >= 10 { break }
            if let result = lookup(word) {
                results.append(result)
                addedWords.insert(result.word.lowercased())
                logger.debug("📖 [LocalDict] 搜索添加补全: \(result.word)")
            }
        }
        
        // 3. 从历史记录中匹配（前缀 + 子串）
        // 先添加前缀匹配（优先级更高）
        let prefixMatches = searchHistory
            .filter { $0.lowercased().hasPrefix(trimmed) && $0.lowercased() != trimmed }
            .prefix(3)
        
        for historyWord in prefixMatches {
            guard !addedWords.contains(historyWord.lowercased()) else { continue }
            if results.count >= 10 { break }
            if let result = lookup(historyWord) {
                results.append(result)
                addedWords.insert(result.word.lowercased())
                logger.debug("📖 [LocalDict] 搜索添加历史前缀: \(result.word)")
            }
        }
        
        // 再添加子串匹配（如 "eck" -> "check"）
        if trimmed.count >= 2 {
            let substringMatches = searchHistory
                .filter { word in
                    let lower = word.lowercased()
                    return lower.contains(trimmed) && !lower.hasPrefix(trimmed) && lower != trimmed
                }
                .prefix(3)
            
            for historyWord in substringMatches {
                guard !addedWords.contains(historyWord.lowercased()) else { continue }
                if results.count >= 10 { break }
                if let result = lookup(historyWord) {
                    results.append(result)
                    addedWords.insert(result.word.lowercased())
                    logger.debug("📖 [LocalDict] 搜索添加历史子串: \(result.word)")
                }
            }
        }
        
        // 4. 常见词形变化（仅当结果较少时）
        if results.count < 5 {
            let variations = generateVariations(for: trimmed)
            for variation in variations {
                guard !addedWords.contains(variation.lowercased()) else { continue }
                if results.count >= 10 { break }
                if let result = lookup(variation) {
                    results.append(result)
                    addedWords.insert(result.word.lowercased())
                    logger.debug("📖 [LocalDict] 搜索添加变形: \(result.word)")
                }
            }
        }
        
        logger.info("📖 [LocalDict] 搜索 '\(trimmed)' 返回 \(results.count) 结果: \(results.map { $0.word }.joined(separator: ", "))")
        return results
    }
    
    /// 获取最近查询的单词
    func getRecentWords() -> [LocalDictionaryResult] {
        return searchHistory.prefix(10).compactMap { lookup($0) }
    }
    
    /// 添加到搜索历史
    func addToHistory(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }
        
        searchHistory.removeAll { $0.lowercased() == trimmed }
        searchHistory.insert(trimmed, at: 0)
        
        if searchHistory.count > maxHistoryCount {
            searchHistory = Array(searchHistory.prefix(maxHistoryCount))
        }
        
        saveHistory()
    }
    
    /// 清除搜索历史
    func clearHistory() {
        searchHistory.removeAll()
        saveHistory()
    }
    
    // MARK: - Private
    
    private func parseDefinition(word: String, definition: String) -> LocalDictionaryResult {
        var pos: String?
        var phonetic: String?
        var chineseDefinition: String?
        
        // 尝试提取音标 (通常在 | | 或 / / 中)
        if let phoneticMatch = definition.range(of: #"\|[^|]+\|"#, options: .regularExpression) {
            phonetic = String(definition[phoneticMatch]).trimmingCharacters(in: CharacterSet(charactersIn: "|"))
        } else if let phoneticMatch = definition.range(of: #"/[^/]+/"#, options: .regularExpression) {
            phonetic = String(definition[phoneticMatch])
        }
        
        // 尝试提取所有词性 - 按出现位置排序
        let posPatterns: [(full: String, abbr: String)] = [
            ("adjective", "adj."), ("noun", "n."), ("verb", "v."), 
            ("adverb", "adv."), ("preposition", "prep."), ("pronoun", "pron."),
            ("conjunction", "conj."), ("interjection", "interj."), ("determiner", "det.")
        ]
        var foundPOS: [(position: Int, abbr: String)] = []
        for (full, abbr) in posPatterns {
            if let range = definition.lowercased().range(of: full) {
                let position = definition.distance(from: definition.startIndex, to: range.lowerBound)
                foundPOS.append((position, abbr))
            }
        }
        // 按位置排序，用 / 连接
        if !foundPOS.isEmpty {
            foundPOS.sort { $0.position < $1.position }
            pos = foundPOS.map { $0.abbr }.joined(separator: "/")
        }
        
        // 提取中文释义 - 优化逻辑：提取完整的中文短语/句子
        chineseDefinition = extractChineseDefinition(from: definition)
        
        return LocalDictionaryResult(
            word: word,
            definition: definition,
            pos: pos,
            phonetic: phonetic,
            chineseDefinition: chineseDefinition
        )
    }
    
    /// 从定义中提取中文释义
    private func extractChineseDefinition(from definition: String) -> String? {
        // 匹配包含中文的完整短语（中文字符 + 可能的标点/数字）
        let chinesePattern = #"[\u4e00-\u9fa5][\u4e00-\u9fa5，、；：。！？\s0-9a-zA-Z]*"#
        
        var chineseParts: [String] = []
        let regex = try? NSRegularExpression(pattern: chinesePattern, options: [])
        let nsString = definition as NSString
        let matches = regex?.matches(in: definition, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        for match in matches {
            let part = nsString.substring(with: match.range).trimmingCharacters(in: .whitespaces)
            if part.count >= 2 { // 至少2个字符
                chineseParts.append(part)
            }
        }
        
        guard !chineseParts.isEmpty else { return nil }
        
        // 拼接前几个中文部分，限制长度
        let combined = chineseParts.prefix(3).joined(separator: "；")
        if combined.count > 60 {
            return String(combined.prefix(60)) + "..."
        }
        return combined
    }
    
    private func generateVariations(for word: String) -> [String] {
        var variations: [String] = []
        
        // 常见词形变化
        if word.hasSuffix("ing") {
            let base = String(word.dropLast(3))
            variations.append(base)
            variations.append(base + "e")
            if let lastChar = base.last {
                variations.append(base + String(lastChar) + "ed")
            }
        } else if word.hasSuffix("ed") {
            let base = String(word.dropLast(2))
            variations.append(base)
            variations.append(base + "e")
            variations.append(base + "ing")
        } else if word.hasSuffix("s") {
            let base = String(word.dropLast(1))
            variations.append(base)
            if word.hasSuffix("es") {
                variations.append(String(word.dropLast(2)))
            }
            if word.hasSuffix("ies") {
                variations.append(String(word.dropLast(3)) + "y")
            }
        } else {
            // 添加常见变形
            variations.append(word + "s")
            variations.append(word + "ed")
            variations.append(word + "ing")
            variations.append(word + "er")
            variations.append(word + "est")
            variations.append(word + "ly")
            variations.append(word + "ness")
        }
        
        return variations
    }
    
    // MARK: - Persistence
    
    private var historyURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Spoke/dictionary_history.json")
    }
    
    private func loadHistory() {
        do {
            let data = try Data(contentsOf: historyURL)
            searchHistory = try JSONDecoder().decode([String].self, from: data)
            logger.info("📖 [LocalDict] 加载历史记录: \(self.searchHistory.count) 条")
        } catch {
            searchHistory = []
        }
    }
    
    private func saveHistory() {
        do {
            let directory = historyURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(searchHistory)
            try data.write(to: historyURL)
        } catch {
            logger.error("📖 [LocalDict] 保存历史记录失败: \(error.localizedDescription)")
        }
    }
}
