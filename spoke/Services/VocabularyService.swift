import Foundation
import OSLog

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
    
    /// 存储路径
    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let spokeDir = appSupport.appendingPathComponent("Spoke", isDirectory: true)
        return spokeDir.appendingPathComponent("vocabulary.json")
    }
    
    // MARK: - Init
    
    private init() {
        loadItems()
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
            logger.warning("⚠️ 不能添加空生词")
            return nil
        }
        
        // 去重检查（忽略大小写）
        let lowercased = trimmed.lowercased()
        guard !wordSet.contains(lowercased) else {
            logger.info("⚠️ 生词已存在: \(trimmed)")
            return nil
        }
        
        let item = VocabularyItem(word: trimmed)
        items.insert(item, at: 0)
        wordSet.insert(lowercased)
        
        saveItems()
        rebuildRegex()
        
        logger.info("✅ 添加生词: \(trimmed)")
        
        // 发送通知
        NotificationCenter.default.post(name: .vocabularyChanged, object: nil)
        
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
        
        logger.info("🗑️ 删除生词: \(word)")
        NotificationCenter.default.post(name: .vocabularyChanged, object: nil)
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
    
    /// 清空所有生词
    func clearAll() {
        items.removeAll()
        wordSet.removeAll()
        matchRegex = nil
        saveItems()
        
        logger.info("🧹 清空所有生词")
        NotificationCenter.default.post(name: .vocabularyChanged, object: nil)
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
            logger.debug("🔄 正则重建: \(self.wordSet.count) 个词")
        } catch {
            logger.error("❌ 正则构建失败: \(error.localizedDescription)")
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
            logger.debug("💾 保存 \(self.items.count) 个生词")
        } catch {
            logger.error("❌ 保存生词失败: \(error.localizedDescription)")
        }
    }
    
    private func loadItems() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            logger.debug("📂 生词文件不存在")
            return
        }
        
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            items = try decoder.decode([VocabularyItem].self, from: data)
            
            // 重建 wordSet
            wordSet = Set(items.map { $0.word.lowercased() })
            
            logger.info("📥 加载 \(self.items.count) 个生词")
        } catch {
            logger.error("❌ 加载生词失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// 生词列表变化通知
    static let vocabularyChanged = Notification.Name("vocabularyChanged")
}
