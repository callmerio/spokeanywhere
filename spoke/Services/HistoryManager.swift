import Foundation
import SwiftData
import AVFoundation
import os

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
                logger.info("📁 Audio saved: \(fileName)")
            } catch {
                logger.error("❌ Failed to save audio: \(error.localizedDescription)")
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
        logger.info("✅ History item saved: \(rawText.prefix(30))...")
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
            logger.info("✅ Reprocessed: \(text.prefix(30))...")
        case .failure(let error):
            logger.error("❌ Reprocess failed: \(error.localizedDescription)")
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
            logger.info("🗑️ Audio deleted: \(audioPath)")
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
        
        let descriptor = FetchDescriptor<HistoryItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        
        do {
            let allItems = try context.fetch(descriptor)
            var itemsToDelete: [HistoryItem] = []
            
            switch policy {
            case .keepDays(let days):
                let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
                itemsToDelete = allItems.filter { $0.createdAt < cutoffDate }
                
            case .keepCount(let count):
                if allItems.count > count {
                    itemsToDelete = Array(allItems.dropFirst(count))
                }
                
            case .keepSize(let megabytes):
                let maxBytes = megabytes * 1024 * 1024
                var totalSize = 0
                
                for item in allItems {
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
                logger.info("🧹 Cleanup completed: \(itemsToDelete.count) items deleted")
            }
            
        } catch {
            logger.error("❌ Cleanup failed: \(error.localizedDescription)")
        }
    }
    
    /// 获取存储统计信息
    func getStorageStats() async -> (count: Int, totalSize: Int64) {
        guard let context = modelContext else { return (0, 0) }
        
        let descriptor = FetchDescriptor<HistoryItem>()
        
        do {
            let items = try context.fetch(descriptor)
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
