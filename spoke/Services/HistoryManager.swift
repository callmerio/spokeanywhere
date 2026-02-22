import AVFoundation
import Foundation
import os
import SwiftData

/// 历史记录管理器
/// 负责录音记录的持久化、检索、重处理
@MainActor
final class HistoryManager {
    
    // MARK: - Singleton
    
    static let shared = HistoryManager()
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "HistoryManager")
    
    // MARK: - Dependencies
    
    private var modelContext: ModelContext?
    private let llmPipeline = LLMPipeline.shared
    
    // MARK: - Properties
    
    /// 音频存储目录
    var audioStorageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let spokeDir = appSupport.appendingPathComponent("Spoke/Audio", isDirectory: true)
        
        // 确保目录存在
        if !FileManager.default.fileExists(atPath: spokeDir.path) {
            try? FileManager.default.createDirectory(at: spokeDir, withIntermediateDirectories: true)
        }
        
        return spokeDir
    }
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Configuration
    
    /// 配置 ModelContext（在 AppDelegate 中调用）
    func configure(with context: ModelContext) {
        self.modelContext = context
        logger.info("✅ HistoryManager configured with ModelContext")
    }
    
    // MARK: - Public API
    
    /// 保存录音记录
    /// - Parameters:
    ///   - rawText: 原始转写文本
    ///   - processedText: LLM 处理后的文本（可选）
    ///   - tempAudioURL: 临时音频文件 URL（可选）
    ///   - appBundleId: 来源应用的 Bundle ID（可选）
    func saveRecording(
        rawText: String,
        processedText: String?,
        tempAudioURL: URL?,
        appBundleId: String?
    ) async {
        guard let context = modelContext else {
            logger.error("❌ ModelContext not configured")
            return
        }
        
        var audioPath: String?
        var audioDuration: TimeInterval?
        
        // 处理音频文件
        if let tempURL = tempAudioURL, FileManager.default.fileExists(atPath: tempURL.path) {
            let fileName = "\(UUID().uuidString).caf"
            let permanentURL = audioStorageURL.appendingPathComponent(fileName)
            
            do {
                // 后台执行文件操作
                try await Task.detached(priority: .utility) {
                    try FileManager.default.moveItem(at: tempURL, to: permanentURL)
                }.value
                
                audioPath = fileName
                audioDuration = await getAudioDuration(url: permanentURL)
                logger.info("📁 Audio saved: \(fileName, privacy: .public)")
            } catch {
                logger.error("❌ Failed to save audio: \(error.localizedDescription, privacy: .public)")
            }
        }
        
        // 创建历史记录
        let item = HistoryItem(
            rawText: rawText,
            processedText: processedText,
            audioPath: audioPath,
            appBundleId: appBundleId
        )
        item.audioDuration = audioDuration
        
        context.insert(item)
        logger.info("✅ History item saved: \(rawText.prefix(30), privacy: .public)...")
    }
    
    /// 使用新 Prompt 重新处理历史记录
    /// - Parameters:
    ///   - item: 历史记录项
    ///   - customPrompt: 自定义系统提示词
    /// - Returns: 处理结果
    func reprocess(
        _ item: HistoryItem,
        with customPrompt: String
    ) async -> Result<String, LLMError> {
        let result = await llmPipeline.refine(item.rawText, customSystemPrompt: customPrompt)
        
        switch result {
        case .success(let text):
            item.processedText = text
            logger.info("✅ Reprocessed: \(text.prefix(30), privacy: .public)...")
        case .failure(let error):
            logger.error("❌ Reprocess failed: \(error.localizedDescription, privacy: .public)")
        }
        
        return result
    }
    
    /// 删除历史记录（包括音频文件）
    /// - Parameter item: 历史记录项
    func deleteItem(_ item: HistoryItem) {
        guard let context = modelContext else {
            logger.error("❌ ModelContext not configured")
            return
        }
        
        // 删除音频文件
        if let audioPath = item.audioPath {
            let audioURL = audioStorageURL.appendingPathComponent(audioPath)
            try? FileManager.default.removeItem(at: audioURL)
            logger.info("🗑️ Audio deleted: \(audioPath, privacy: .public)")
        }
        
        // 删除数据库记录
        context.delete(item)
        logger.info("🗑️ History item deleted")
    }
    
    /// 获取音频文件的完整 URL
    /// - Parameter item: 历史记录项
    /// - Returns: 音频文件 URL（如果存在）
    func audioURL(for item: HistoryItem) -> URL? {
        guard let audioPath = item.audioPath else { return nil }
        let url = audioStorageURL.appendingPathComponent(audioPath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    
    // MARK: - Auto Cleanup
    
    /// 清理策略
    enum CleanupPolicy {
        case keepDays(Int)      // 保留最近 N 天
        case keepCount(Int)     // 保留最近 N 条
        case keepSize(Int)      // 保留最大 N MB
    }
    
    /// 执行自动清理
    /// - Parameter policy: 清理策略
    func performCleanup(policy: CleanupPolicy) async {
        guard let context = modelContext else {
            logger.error("❌ ModelContext not configured for cleanup")
            return
        }
        
        do {
            // Fetch all and sort in memory to avoid ReferenceWritableKeyPath Sendable issue in Swift 6
            let allItems = try context.fetch(FetchDescriptor<HistoryItem>())
            let sortedItems = allItems.sorted(by: { $0.createdAt > $1.createdAt })
            
            var itemsToDelete: [HistoryItem] = []
            
            switch policy {
            case .keepDays(let days):
                let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
                itemsToDelete = sortedItems.filter { $0.createdAt < cutoffDate }
                
            case .keepCount(let count):
                if sortedItems.count > count {
                    itemsToDelete = Array(sortedItems.dropFirst(count))
                }
                
            case .keepSize(let megabytes):
                let maxBytes = megabytes * 1024 * 1024
                var totalSize = 0
                
                for item in sortedItems {
                    if let audioPath = item.audioPath {
                        let url = audioStorageURL.appendingPathComponent(audioPath)
                        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                           let size = attrs[.size] as? Int {
                            totalSize += size
                        }
                    }
                    
                    if totalSize > maxBytes {
                        itemsToDelete.append(item)
                    }
                }
            }
            
            // 执行删除
            for item in itemsToDelete {
                deleteItem(item)
            }
            
            if !itemsToDelete.isEmpty {
                logger.info("🧹 Cleanup completed: \(itemsToDelete.count, privacy: .public) items deleted")
            }
        } catch {
            logger.error("❌ Cleanup failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// 获取存储统计信息
    func getStorageStats() async -> (count: Int, totalSize: Int64) {
        guard let context = modelContext else { return (0, 0) }
        
        do {
            let items = try context.fetch(FetchDescriptor<HistoryItem>())
            var totalSize: Int64 = 0
            
            for item in items {
                if let audioPath = item.audioPath {
                    let url = audioStorageURL.appendingPathComponent(audioPath)
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                       let size = attrs[.size] as? Int64 {
                        totalSize += size
                    }
                }
            }
            
            return (items.count, totalSize)
        } catch {
            return (0, 0)
        }
    }
    
    // MARK: - Orphan Cleanup
    
    /// 清理孤儿音频文件（磁盘有文件但数据库无记录）
    /// 应在启动时调用，防止音频文件泄漏
    func cleanupOrphanedAudioFiles() async {
        guard let context = modelContext else {
            logger.error("❌ ModelContext not configured for orphan cleanup")
            return
        }
        
        // 获取数据库中所有音频路径
        let validPaths: Set<String>
        do {
            let items = try context.fetch(FetchDescriptor<HistoryItem>())
            validPaths = Set(items.compactMap { $0.audioPath })
        } catch {
            logger.error("❌ Failed to fetch audio paths: \(error.localizedDescription, privacy: .public)")
            return
        }
        
        // 扫描磁盘文件
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: audioStorageURL.path) else { return }
        
        var deletedCount = 0
        var freedBytes: Int64 = 0
        
        for file in files where file.hasSuffix(".caf") {
            if !validPaths.contains(file) {
                let url = audioStorageURL.appendingPathComponent(file)
                if let attrs = try? fm.attributesOfItem(atPath: url.path),
                   let size = attrs[.size] as? Int64 {
                    freedBytes += size
                }
                try? fm.removeItem(at: url)
                deletedCount += 1
            }
        }
        
        if deletedCount > 0 {
            let freedMB = Double(freedBytes) / 1024 / 1024
            logger.info("🧹 Orphan cleanup: \(deletedCount, privacy: .public) files, \(String(format: "%.1f", freedMB), privacy: .public)MB freed")
        }
    }
    
    /// 限制音频总大小（超出后删除最旧的普通记录）
    /// - Parameter maxSizeMB: 最大总大小（MB）
    /// - Note: todo/done/note 类型记录不会被删除
    func enforceAudioSizeLimit(maxSizeMB: Int = 2048) async {
        guard let context = modelContext else { return }
        
        do {
            // Fetch all and sort in memory (forward: oldest first)
            let items = try context.fetch(FetchDescriptor<HistoryItem>())
            let sortedItems = items.sorted(by: { $0.createdAt < $1.createdAt })
            
            var totalSize: Int64 = 0
            let maxBytes = Int64(maxSizeMB) * 1024 * 1024
            
            // 计算当前总大小
            for item in sortedItems {
                if let audioPath = item.audioPath {
                    let url = audioStorageURL.appendingPathComponent(audioPath)
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                       let size = attrs[.size] as? Int64 {
                        totalSize += size
                    }
                }
            }
            
            // 超出限制时，从最旧的普通记录开始删除
            var deletedCount = 0
            for item in sortedItems {
                guard totalSize > maxBytes else { break }
                
                // 跳过 todo/done/note 记录
                if item.recordType.isPinned { continue }
                
                if let audioPath = item.audioPath {
                    let url = audioStorageURL.appendingPathComponent(audioPath)
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                       let size = attrs[.size] as? Int64 {
                        totalSize -= size
                    }
                }
                deleteItem(item)
                deletedCount += 1
            }
            
            if deletedCount > 0 {
                logger.info("🧹 Size limit enforced: \(deletedCount, privacy: .public) old items deleted")
            }
        } catch {
            logger.error("❌ Size limit enforcement failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// 限制普通记录数量（只保留最新的 N 条普通记录）
    /// - Parameter maxCount: 最大保留数量
    /// - Note: todo/done/note 类型记录不计入也不会被删除
    func enforceNormalRecordLimit(maxCount: Int = 50) async {
        guard let context = modelContext else { return }
        
        do {
            // Fetch all and sort in memory (reverse: newest first)
            let allItems = try context.fetch(FetchDescriptor<HistoryItem>())
            let sortedItems = allItems.sorted(by: { $0.createdAt > $1.createdAt })
            
            // 过滤出普通记录
            let normalItems = sortedItems.filter { !$0.recordType.isPinned }
            
            // 超出限制的部分需要删除
            if normalItems.count > maxCount {
                let itemsToDelete = Array(normalItems.dropFirst(maxCount))
                for item in itemsToDelete {
                    deleteItem(item)
                }
                logger.info("🧹 Normal record limit enforced: \(itemsToDelete.count, privacy: .public) old items deleted, keeping \(maxCount, privacy: .public)")
            }
        } catch {
            logger.error("❌ Normal record limit enforcement failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// 旧版兼容：将 today 记录迁移为 todo
    /// 应在启动时调用
    /// - Note: 旧版数据库可能含有 "today" 类型记录，需迁移为 "todo"
    func migrateLegacyTodayRecords() async {
        guard let context = modelContext else { return }
        
        do {
            let items = try context.fetch(FetchDescriptor<HistoryItem>())
            var migratedCount = 0
            
            // 检查是否有 recordTypeRaw == "today" 的旧记录
            for item in items where item.recordTypeRaw == "today" {
                item.recordTypeRaw = HistoryRecordType.todo.rawValue
                migratedCount += 1
            }
            
            if migratedCount > 0 {
                try context.save()
                logger.info("🔄 Migrated \(migratedCount, privacy: .public) legacy 'today' records to 'todo'")
            }
        } catch {
            logger.error("❌ Legacy migration failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// 设置记录类型
    func setRecordType(_ item: HistoryItem, type: HistoryRecordType) {
        item.recordType = type
        try? modelContext?.save()
        logger.info("📌 Record type set to \(type.displayName, privacy: .public): \(item.rawText.prefix(30), privacy: .public)...")
    }
    
    // MARK: - Private
    
    private func getAudioDuration(url: URL) async -> TimeInterval? {
        await Task.detached(priority: .utility) {
            let asset = AVURLAsset(url: url)
            do {
                let duration = try await asset.load(.duration)
                return duration.seconds.isNaN ? nil : duration.seconds
            } catch {
                return nil
            }
        }.value
    }
}