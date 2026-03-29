import Foundation
import OSLog

struct VocabularyServiceDependencies {
    let notificationCenter: NotificationCenter
}

// MARK: - Vocabulary Item

/// 生词条目
struct VocabularyItem: Codable, Identifiable, Equatable {
    let id: UUID
    let word: String
    let createdAt: Date
    
    init(id: UUID = UUID(), word: String, createdAt: Date = Date()) {
        self.id = id
        self.word = word.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
    }
}

// MARK: - Vocabulary Service

/// 生词记忆服务
/// 管理用户添加的生词，支持持久化存储和高效匹配
@MainActor
final class VocabularyService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = VocabularyService()
    
    // MARK: - Published
    
    /// 生词列表
    @Published private(set) var items: [VocabularyItem] = []
    
    // MARK: - Private
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "VocabularyService")
    
    /// 小写词集，用于 O(1) 去重检查
    private var wordSet: Set<String> = []
    
    /// 预编译的正则表达式（带单词边界）
    private var matchRegex: NSRegularExpression?
    
    /// 生词数量上限（防止正则性能问题）
    private let maxVocabularySize: Int
    
    /// 存储路径
    private let storageURL: URL
    private let dependencies: VocabularyServiceDependencies

    nonisolated private static func defaultStorageURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let spokeDir = appSupport.appendingPathComponent("Spoke", isDirectory: true)
        return spokeDir.appendingPathComponent("vocabulary.json")
    }
    
    // MARK: - Init
    
    init(
        dependencies: VocabularyServiceDependencies = .live,
        storageURL: URL = VocabularyService.defaultStorageURL(),
        maxVocabularySize: Int = 200,
        loadPersistedItems: Bool = true
    ) {
        self.dependencies = dependencies
        self.storageURL = storageURL
        self.maxVocabularySize = max(1, maxVocabularySize)

        if loadPersistedItems {
            loadItems()
        }

        rebuildRegex()
    }
    
    // MARK: - Public API
    
    /// 添加生词
    /// - Parameter word: 要添加的词
    /// - Returns: 新创建的条目（如果成功）
    @discardableResult
    func add(_ word: String) -> VocabularyItem? {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            logger.warning("[VOCAB] 不能添加空生词")
            return nil
        }
        
        // 去重检查（忽略大小写）
        let lowercased = trimmed.lowercased()
        guard !wordSet.contains(lowercased) else {
            logger.info("[VOCAB] 生词已存在: \(trimmed)")
            return nil
        }
        
        // 数量上限检查（防止正则性能问题）
        guard items.count < maxVocabularySize else {
            logger.warning("[VOCAB] 达到上限 \(self.maxVocabularySize)，无法添加: \(trimmed)")
            return nil
        }
        
        let item = VocabularyItem(word: trimmed)
        items.insert(item, at: 0)
        wordSet.insert(lowercased)
        
        saveItems()
        rebuildRegex()
        
        logger.info("[VOCAB] 添加: \(trimmed)")
        
        // 发送通知
        dependencies.notificationCenter.post(name: .vocabularyChanged, object: nil)
        
        return item
    }
    
    /// 删除生词
    func remove(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let word = items[index].word
        
        items.remove(at: index)
        wordSet.remove(word.lowercased())
        
        saveItems()
        rebuildRegex()
        
        logger.info("[VOCAB] 删除: \(word)")
        dependencies.notificationCenter.post(name: .vocabularyChanged, object: nil)
    }
    
    /// 检查是否是生词
    func contains(_ word: String) -> Bool {
        wordSet.contains(word.lowercased())
    }
    
    /// 获取所有生词（小写）
    func getAllWords() -> Set<String> {
        wordSet
    }
    
    /// 获取文本中需要高亮的范围
    /// - Parameter text: 要检查的文本
    /// - Returns: 需要高亮的 NSRange 数组
    func highlightRanges(in text: String) -> [NSRange] {
        guard let regex = matchRegex else { return [] }
        
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        
        let matches = regex.matches(in: text, options: [], range: fullRange)
        return matches.map { $0.range }
    }
    
    /// 标记文本中的生词
    /// 复用预编译的正则，性能极佳，且已处理长词优先逻辑
    /// - Parameters:
    ///   - text: 原始文本
    ///   - template: 替换模板，默认使用 <word>$0</word>
    /// - Returns: 标记后的文本
    func markVocabulary(in text: String, template: String = "<word>$0</word>") -> String {
        guard let regex = matchRegex else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: template)
    }
    
    /// 清空所有生词
    func clearAll() {
        items.removeAll()
        wordSet.removeAll()
        matchRegex = nil
        saveItems()
        
        logger.info("[VOCAB] 清空所有生词")
        dependencies.notificationCenter.post(name: .vocabularyChanged, object: nil)
    }
    
    // MARK: - Private Methods
    
    /// 重建正则表达式
    /// 英文使用 \b 单词边界，中文直接匹配
    private func rebuildRegex() {
        guard !wordSet.isEmpty else {
            matchRegex = nil
            return
        }
        
        // 分离中英文词汇
        var englishWords: [String] = []
        var chineseWords: [String] = []
        
        for word in wordSet {
            let escaped = NSRegularExpression.escapedPattern(for: word)
            if word.range(of: "\\p{Han}", options: .regularExpression) != nil {
                chineseWords.append(escaped)
            } else {
                englishWords.append(escaped)
            }
        }
        
        // 🔥 关键优化：按长度降序排序
        // 确保正则引擎优先匹配长词（例如 "AI Agent" 优先于 "AI"），避免子串错误匹配
        // 同时解决 "上千个词" 场景下的潜在歧义问题
        englishWords.sort { $0.count > $1.count }
        chineseWords.sort { $0.count > $1.count }
        
        // 构建正则：英文用 \b 边界，中文直接匹配
        var patterns: [String] = []
        if !englishWords.isEmpty {
            patterns.append("\\b(" + englishWords.joined(separator: "|") + ")\\b")
        }
        if !chineseWords.isEmpty {
            patterns.append("(" + chineseWords.joined(separator: "|") + ")")
        }
        
        let pattern = patterns.joined(separator: "|")
        
        do {
            matchRegex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            logger.debug("[VOCAB] 正则重建: \(self.wordSet.count) 个词")
        } catch {
            logger.error("[VOCAB] 正则构建失败: \(error.localizedDescription)")
            matchRegex = nil
        }
    }
    
    // MARK: - Persistence
    
    private func saveItems() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(items)
            
            // 确保目录存在
            let dir = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            
            try data.write(to: storageURL, options: .atomic)
            logger.debug("[VOCAB] 保存 \(self.items.count) 个生词")
        } catch {
            logger.error("[VOCAB] 保存失败: \(error.localizedDescription)")
        }
    }
    
    private func loadItems() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            logger.debug("[VOCAB] 生词文件不存在")
            return
        }
        
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            items = try decoder.decode([VocabularyItem].self, from: data)
            
            // 重建 wordSet
            wordSet = Set(items.map { $0.word.lowercased() })
            
            logger.info("[VOCAB] 加载 \(self.items.count) 个生词")
        } catch {
            logger.error("[VOCAB] 加载失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// 生词列表变化通知
    static let vocabularyChanged = Notification.Name("vocabularyChanged")
}
