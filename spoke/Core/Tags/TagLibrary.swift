import Combine
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.spokeanywhere", category: "TagLibrary")

// MARK: - Tag Library

/// 标签库管理器（全局单例）
/// 负责标签的 CRUD 和持久化
@MainActor
final class TagLibrary: ObservableObject {
    
    static let shared = TagLibrary()
    
    // MARK: - Published
    
    /// 所有标签
    @Published private(set) var tags: [CardTag] = []
    
    /// 最近使用的标签（按使用时间倒序，最多显示 5 个）
    @Published private(set) var recentTags: [CardTag] = []
    
    // MARK: - Storage
    
    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let spokeDir = appSupport.appendingPathComponent("Spoke", isDirectory: true)
        return spokeDir.appendingPathComponent("tag_library.json")
    }
    
    private var recentTagIdsURL: URL {
        storageURL.deletingLastPathComponent().appendingPathComponent("recent_tags.json")
    }
    
    // MARK: - Init
    
    private init() {
        loadTags()
        loadRecentTags()
    }
    
    // MARK: - Query
    
    /// 根据 ID 获取标签
    func tag(for id: UUID) -> CardTag? {
        tags.first { $0.id == id }
    }
    
    /// 根据名称获取标签（不区分大小写）
    func tag(named name: String) -> CardTag? {
        tags.first { $0.name.lowercased() == name.lowercased() }
    }
    
    /// 根据 ID 列表获取标签（保持顺序）
    func tags(for ids: [UUID]) -> [CardTag] {
        ids.compactMap { id in tags.first { $0.id == id } }
    }
    
    /// 搜索标签（前缀匹配）
    func search(_ query: String) -> [CardTag] {
        guard !query.isEmpty else { return tags }
        let lowercased = query.lowercased()
        return tags.filter { $0.name.lowercased().hasPrefix(lowercased) }
    }
    
    // MARK: - CRUD
    
    /// 创建新标签（如果同名标签已存在则返回现有的）
    @discardableResult
    func createTag(name: String, color: TagColor? = nil) -> CardTag {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            logger.warning("⚠️ 尝试创建空名称标签")
            return CardTag(name: "未命名")
        }
        
        // 检查是否已存在
        if let existing = tag(named: trimmedName) {
            logger.debug("📌 标签已存在: \(trimmedName)")
            return existing
        }
        
        let newTag = CardTag(name: trimmedName, color: color)
        tags.append(newTag)
        saveTags()
        
        logger.info("✅ 创建标签: \(trimmedName) [\(newTag.color.rawValue)]")
        return newTag
    }
    
    /// 更新标签名称
    func updateTagName(_ id: UUID, name: String) {
        guard let index = tags.firstIndex(where: { $0.id == id }) else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        tags[index].name = trimmedName
        saveTags()
        updateRecentTagsCache()
        
        logger.info("✏️ 更新标签名称: \(trimmedName)")
    }
    
    /// 更新标签颜色
    func updateTagColor(_ id: UUID, color: TagColor) {
        guard let index = tags.firstIndex(where: { $0.id == id }) else { return }
        
        tags[index].color = color
        saveTags()
        updateRecentTagsCache()
        
        logger.info("🎨 更新标签颜色: \(self.tags[index].name) → \(color.rawValue)")
    }
    
    /// 删除标签
    func deleteTag(_ id: UUID) {
        guard let index = tags.firstIndex(where: { $0.id == id }) else { return }
        let name = tags[index].name
        
        tags.remove(at: index)
        saveTags()
        
        // 从最近使用中移除
        recentTagIds.removeAll { $0 == id }
        saveRecentTags()
        updateRecentTagsCache()
        
        logger.info("🗑️ 删除标签: \(name)")
        
        // 通知 MessagePanelState 移除相关引用
        NotificationCenter.default.post(name: .tagDeleted, object: nil, userInfo: ["tagId": id])
    }
    
    // MARK: - Recent Tags
    
    private var recentTagIds: [UUID] = []
    private let maxRecentTags = 5
    
    /// 标记标签为最近使用
    func markAsRecentlyUsed(_ tagId: UUID) {
        // 移除旧位置
        recentTagIds.removeAll { $0 == tagId }
        // 插入到最前面
        recentTagIds.insert(tagId, at: 0)
        // 限制数量
        if recentTagIds.count > maxRecentTags {
            recentTagIds = Array(recentTagIds.prefix(maxRecentTags))
        }
        
        saveRecentTags()
        updateRecentTagsCache()
    }
    
    private func updateRecentTagsCache() {
        recentTags = tags(for: recentTagIds)
    }
    
    // MARK: - Persistence
    
    private func saveTags() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(tags)
            
            let dir = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: storageURL, options: .atomic)
            
            logger.debug("💾 保存 \(self.tags.count) 个标签")
        } catch {
            logger.error("❌ 保存标签失败: \(error.localizedDescription)")
        }
    }
    
    private func loadTags() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            logger.debug("📂 标签库文件不存在")
            return
        }
        
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            tags = try decoder.decode([CardTag].self, from: data)
            
            logger.info("📥 加载 \(self.tags.count) 个标签")
        } catch {
            logger.error("❌ 加载标签失败: \(error.localizedDescription)")
        }
    }
    
    private func saveRecentTags() {
        do {
            let data = try JSONEncoder().encode(recentTagIds)
            try data.write(to: recentTagIdsURL, options: .atomic)
        } catch {
            logger.error("❌ 保存最近标签失败: \(error.localizedDescription)")
        }
    }
    
    private func loadRecentTags() {
        guard FileManager.default.fileExists(atPath: recentTagIdsURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: recentTagIdsURL)
            recentTagIds = try JSONDecoder().decode([UUID].self, from: data)
            updateRecentTagsCache()
        } catch {
            logger.error("❌ 加载最近标签失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    /// 标签被删除（userInfo: ["tagId": UUID]）
    static let tagDeleted = Notification.Name("tagDeleted")
}
