import Combine
import Foundation
import os

// MARK: - Dictionary Service

/// 词典服务
/// 管理用户自定义词典的 CRUD、热词挖掘、转录匹配
@MainActor
final class DictionaryService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = DictionaryService()
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "DictionaryService")
    
    // MARK: - Published Properties
    
    /// 所有词典条目
    @Published private(set) var entries: [DictionaryEntry] = []
    
    /// 待确认的热词推荐
    @Published private(set) var pendingHotwords: [DictionaryEntry] = []
    
    // MARK: - Storage
    
    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Spoke/dictionary.json")
    }
    
    private var hotwordsStorageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Spoke/pending_hotwords.json")
    }
    
    // MARK: - Constants
    
    /// 热词推荐的最小频率阈值
    static let hotwordMinFrequency = 3
    
    /// 最大保存条目数
    static let maxEntries = 1000
    
    /// 最大待确认热词数
    static let maxPendingHotwords = 50
    
    // MARK: - Init
    
    private init() {
        loadEntries()
        loadPendingHotwords()
    }
    
    // MARK: - Computed Properties
    
    /// 手动添加的条目
    var manualEntries: [DictionaryEntry] {
        entries.filter { $0.source == .manual }
    }
    
    /// 自动添加的条目（已确认）
    var autoEntries: [DictionaryEntry] {
        entries.filter { $0.source == .auto && $0.confirmedByUser }
    }
    
    /// 所有生效的条目（用于转录匹配）
    var activeEntries: [DictionaryEntry] {
        entries.filter { $0.isActive }
    }
    
    /// 获取所有词语（用于 contextualStrings 注入）
    func getAllWords() -> [String] {
        activeEntries.map { $0.word }
    }
    
    // MARK: - CRUD Operations
    
    /// 添加单个词条
    /// - Parameters:
    ///   - word: 期望的正确词形
    ///   - corrections: 可能的错误识别形式（用于后处理纠错）
    ///   - source: 来源
    /// - Returns: 新创建的词条（如果成功）
    @discardableResult
    func addEntry(word: String, corrections: [String] = [], source: DictionaryEntrySource = .manual) -> DictionaryEntry? {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedWord.isEmpty else {
            logger.warning("⚠️ Cannot add empty word")
            return nil
        }
        
        // 检查是否已存在
        if let existing = entries.first(where: { $0.word.lowercased() == trimmedWord.lowercased() }) {
            logger.info("⚠️ Word already exists: \(existing.word)")
            return nil
        }
        
        let entry = DictionaryEntry(
            word: trimmedWord,
            corrections: corrections,
            source: source,
            confirmedByUser: source == .manual
        )
        
        entries.insert(entry, at: 0)
        saveEntries()
        
        logger.info("✅ Added dictionary entry: \(trimmedWord)")
        return entry
    }
    
    /// 批量添加词条（每行一个词）
    /// - Parameter text: 多行文本，每行一个词
    /// - Returns: 导入结果
    func batchImport(from text: String) -> DictionaryImportResult {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var successCount = 0
        var duplicateCount = 0
        var newEntries: [DictionaryEntry] = []
        
        for line in lines {
            // 支持 "词=纠错1,纠错2" 格式
            let parts = line.components(separatedBy: "=")
            let word = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let corrections: [String] = parts.count > 1
                ? parts[1].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                : []
            
            if let entry = addEntry(word: word, corrections: corrections, source: .manual) {
                successCount += 1
                newEntries.append(entry)
            } else if entries.contains(where: { $0.word.lowercased() == word.lowercased() }) {
                duplicateCount += 1
            }
        }
        
        logger.info("📦 Batch import: \(successCount) success, \(duplicateCount) duplicates")
        
        return DictionaryImportResult(
            successCount: successCount,
            duplicateCount: duplicateCount,
            errorCount: lines.count - successCount - duplicateCount,
            entries: newEntries
        )
    }
    
    /// 更新词条
    func updateEntry(_ entry: DictionaryEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            logger.warning("⚠️ Entry not found for update: \(entry.id)")
            return
        }
        
        entries[index] = entry
        saveEntries()
        logger.info("✏️ Updated entry: \(entry.word)")
    }
    
    /// 添加纠错项到现有词条
    func addCorrection(_ errorForm: String, to entryId: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == entryId }) else { return }
        
        let trimmedErrorForm = errorForm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedErrorForm.isEmpty else { return }
        
        if !entries[index].corrections.contains(where: { $0.lowercased() == trimmedErrorForm.lowercased() }) {
            entries[index].corrections.append(trimmedErrorForm)
            saveEntries()
            logger.info("➕ Added correction '\(trimmedErrorForm)' to '\(self.entries[index].word)'")
        }
    }
    
    /// 添加训练短语到现有词条（用于预编译 LM）
    /// - Parameters:
    ///   - phrase: 包含目标词的完整句子
    ///   - entryId: 词条 ID
    func addTrainingPhrase(_ phrase: String, to entryId: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == entryId }) else { return }
        
        let trimmedPhrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPhrase.isEmpty else { return }
        
        // 限制每个词条最多 20 个训练短语
        if entries[index].trainingPhrases.count >= 20 {
            entries[index].trainingPhrases.removeFirst()
        }
        
        // 避免重复
        if !entries[index].trainingPhrases.contains(where: { $0.lowercased() == trimmedPhrase.lowercased() }) {
            entries[index].trainingPhrases.append(trimmedPhrase)
            saveEntries()
            logger.info("📝 Added training phrase to '\(self.entries[index].word)': \(trimmedPhrase.prefix(30))...")
            
            // 通知需要重新预编译 LM
            NotificationCenter.default.post(name: .dictionaryTrainingDataChanged, object: nil)
        }
    }
    
    /// 获取所有训练短语（用于预编译 LM）
    func getAllTrainingPhrases() -> [(word: String, phrase: String)] {
        var result: [(word: String, phrase: String)] = []
        for entry in entries where entry.isActive {
            for phrase in entry.trainingPhrases {
                result.append((word: entry.word, phrase: phrase))
            }
        }
        return result
    }
    
    /// 是否有训练短语（决定是否启用预编译 LM）
    var hasTrainingPhrases: Bool {
        entries.contains { !$0.trainingPhrases.isEmpty }
    }
    
    /// 清空指定词条的训练短语
    func clearTrainingPhrases(for entryId: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == entryId }) else { return }
        
        entries[index].trainingPhrases.removeAll()
        saveEntries()
        logger.info("🗑️ Cleared training phrases for '\(self.entries[index].word)'")
        
        NotificationCenter.default.post(name: .dictionaryTrainingDataChanged, object: nil)
    }
    
    /// 删除指定词条的单条训练短语
    func removeTrainingPhrase(at phraseIndex: Int, from entryId: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == entryId }),
              phraseIndex >= 0 && phraseIndex < entries[index].trainingPhrases.count else { return }
        
        let removed = entries[index].trainingPhrases.remove(at: phraseIndex)
        saveEntries()
        logger.info("🗑️ Removed training phrase from '\(self.entries[index].word)': \(removed.prefix(20))...")
        
        NotificationCenter.default.post(name: .dictionaryTrainingDataChanged, object: nil)
    }
    
    /// 更新指定词条的单条训练短语
    func updateTrainingPhrase(at phraseIndex: Int, with newPhrase: String, for entryId: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == entryId }),
              phraseIndex >= 0 && phraseIndex < entries[index].trainingPhrases.count else { return }
        
        let trimmedPhrase = newPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPhrase.isEmpty else { return }
        
        // 检查是否与其他短语重复（排除自身）
        let isDuplicate = entries[index].trainingPhrases.enumerated().contains { i, p in
            i != phraseIndex && p.lowercased() == trimmedPhrase.lowercased()
        }
        
        if isDuplicate {
            // 重复则删除当前条目
            entries[index].trainingPhrases.remove(at: phraseIndex)
            logger.info("🗑️ Removed duplicate training phrase from '\(self.entries[index].word)'")
        } else {
            entries[index].trainingPhrases[phraseIndex] = trimmedPhrase
            logger.info("✏️ Updated training phrase for '\(self.entries[index].word)': \(trimmedPhrase.prefix(30))...")
        }
        
        saveEntries()
        NotificationCenter.default.post(name: .dictionaryTrainingDataChanged, object: nil)
    }
    
    /// 去重训练短语（清理已有的重复项）
    func deduplicateTrainingPhrases(for entryId: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == entryId }) else { return }
        
        var seen = Set<String>()
        let originalCount = entries[index].trainingPhrases.count
        
        entries[index].trainingPhrases = entries[index].trainingPhrases.filter { phrase in
            let lowercased = phrase.lowercased()
            if seen.contains(lowercased) {
                return false
            }
            seen.insert(lowercased)
            return true
        }
        
        let removedCount = originalCount - entries[index].trainingPhrases.count
        if removedCount > 0 {
            saveEntries()
            logger.info("🧹 Deduplicated \(removedCount) training phrases for '\(self.entries[index].word)'")
            NotificationCenter.default.post(name: .dictionaryTrainingDataChanged, object: nil)
        }
    }
    
    /// 删除词条
    func deleteEntry(_ entry: DictionaryEntry) {
        entries.removeAll { $0.id == entry.id }
        saveEntries()
        logger.info("🗑️ Deleted entry: \(entry.word)")
    }
    
    /// 删除多个词条
    func deleteEntries(_ entryIds: Set<UUID>) {
        entries.removeAll { entryIds.contains($0.id) }
        saveEntries()
        logger.info("🗑️ Deleted \(entryIds.count) entries")
    }
    
    /// 清空所有词条
    func clearAll() {
        entries.removeAll()
        saveEntries()
        logger.info("🗑️ Cleared all dictionary entries")
    }
    
    // MARK: - Hotword Management
    
    /// 记录词频（用于热词挖掘）
    /// 当转录结果中包含某个词时调用
    func recordWordUsage(_ word: String) {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWord.isEmpty else { return }
        
        // 检查是否已在正式词典中
        if let index = entries.firstIndex(where: { $0.word.lowercased() == trimmedWord.lowercased() }) {
            entries[index].frequency += 1
            entries[index].lastUsedAt = Date()
            saveEntries()
            return
        }
        
        // 检查是否在待确认热词中
        if let index = pendingHotwords.firstIndex(where: { $0.word.lowercased() == trimmedWord.lowercased() }) {
            pendingHotwords[index].frequency += 1
            pendingHotwords[index].lastUsedAt = Date()
            savePendingHotwords()
        } else {
            // 新增待确认热词
            let newHotword = DictionaryEntry(
                word: trimmedWord,
                source: .auto,
                frequency: 1,
                confirmedByUser: false
            )
            pendingHotwords.insert(newHotword, at: 0)
            
            // 限制数量
            if pendingHotwords.count > Self.maxPendingHotwords {
                pendingHotwords = Array(pendingHotwords.prefix(Self.maxPendingHotwords))
            }
            
            savePendingHotwords()
        }
    }
    
    /// 获取推荐的热词（达到频率阈值）
    var recommendedHotwords: [DictionaryEntry] {
        pendingHotwords
            .filter { $0.frequency >= Self.hotwordMinFrequency }
            .sorted { $0.frequency > $1.frequency }
    }
    
    /// 确认热词（添加到正式词典）
    func confirmHotword(_ hotword: DictionaryEntry, correctedWord: String? = nil) {
        var confirmedEntry = hotword
        confirmedEntry.confirmedByUser = true
        
        // 如果用户修正了词形
        if let corrected = correctedWord?.trimmingCharacters(in: .whitespacesAndNewlines), !corrected.isEmpty {
            // 原词变成纠错项
            if confirmedEntry.word != corrected {
                confirmedEntry.corrections.append(confirmedEntry.word)
            }
            confirmedEntry.word = corrected
        }
        
        // 从待确认列表移除
        pendingHotwords.removeAll { $0.id == hotword.id }
        savePendingHotwords()
        
        // 添加到正式词典
        entries.insert(confirmedEntry, at: 0)
        saveEntries()
        
        logger.info("✅ Confirmed hotword: \(confirmedEntry.word)")
    }
    
    /// 忽略热词推荐
    func dismissHotword(_ hotword: DictionaryEntry) {
        pendingHotwords.removeAll { $0.id == hotword.id }
        savePendingHotwords()
        logger.info("❌ Dismissed hotword: \(hotword.word)")
    }
    
    // MARK: - Transcription Matching
    
    /// 对转录文本应用词典匹配
    /// - Parameter text: 转录结果
    /// - Returns: 替换后的文本
    func applyDictionary(to text: String) -> String {
        var result = text
        
        for entry in activeEntries {
            result = entry.replace(in: result)
        }
        
        return result
    }
    
    /// 检查文本中是否包含词典纠错项
    func findMatches(in text: String) -> [(entry: DictionaryEntry, matchedErrorForm: String)] {
        var matches: [(DictionaryEntry, String)] = []
        
        for entry in activeEntries {
            if let matchedErrorForm = entry.matches(in: text) {
                matches.append((entry, matchedErrorForm))
            }
        }
        
        return matches
    }
    
    // MARK: - Search
    
    /// 搜索词典条目
    func search(_ query: String) -> [DictionaryEntry] {
        let lowercasedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !lowercasedQuery.isEmpty else { return entries }
        
        return entries.filter { entry in
            entry.word.lowercased().contains(lowercasedQuery) ||
            entry.corrections.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }
    
    // MARK: - Persistence
    
    private func saveEntries() {
        do {
            let data = try JSONEncoder().encode(entries)
            let dir = storageURL.deletingLastPathComponent()
            
            if !FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            
            try data.write(to: storageURL)
            logger.debug("💾 Saved \(self.entries.count) dictionary entries")
        } catch {
            logger.error("❌ Failed to save dictionary: \(error)")
        }
    }
    
    private func loadEntries() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: storageURL)
            entries = try JSONDecoder().decode([DictionaryEntry].self, from: data)
            logger.info("📂 Loaded \(self.entries.count) dictionary entries")
        } catch {
            logger.error("❌ Failed to load dictionary: \(error)")
        }
    }
    
    private func savePendingHotwords() {
        do {
            let data = try JSONEncoder().encode(pendingHotwords)
            let dir = hotwordsStorageURL.deletingLastPathComponent()
            
            if !FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            
            try data.write(to: hotwordsStorageURL)
        } catch {
            logger.error("❌ Failed to save pending hotwords: \(error)")
        }
    }
    
    private func loadPendingHotwords() {
        guard FileManager.default.fileExists(atPath: hotwordsStorageURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: hotwordsStorageURL)
            pendingHotwords = try JSONDecoder().decode([DictionaryEntry].self, from: data)
            logger.info("📂 Loaded \(self.pendingHotwords.count) pending hotwords")
        } catch {
            logger.error("❌ Failed to load pending hotwords: \(error)")
        }
    }
    
    // MARK: - Export/Import
    
    /// 导出词典为 JSON
    func exportToJSON() -> Data? {
        try? JSONEncoder().encode(entries)
    }
    
    /// 从 JSON 导入词典
    func importFromJSON(_ data: Data) throws {
        let imported = try JSONDecoder().decode([DictionaryEntry].self, from: data)
        
        for entry in imported {
            if !entries.contains(where: { $0.word.lowercased() == entry.word.lowercased() }) {
                entries.append(entry)
            }
        }
        
        saveEntries()
        logger.info("📦 Imported \(imported.count) entries from JSON")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// 词典条目变更通知
    static let dictionaryDidChange = Notification.Name("DictionaryDidChange")
    
    /// 热词推荐变更通知
    static let hotwordsDidChange = Notification.Name("HotwordsDidChange")
    
    /// 请求添加词到词典（从 Pipeline 右键菜单触发）
    static let requestAddToDictionary = Notification.Name("RequestAddToDictionary")
    
    /// 训练数据变更通知（触发预编译 LM 更新）
    static let dictionaryTrainingDataChanged = Notification.Name("DictionaryTrainingDataChanged")
}
