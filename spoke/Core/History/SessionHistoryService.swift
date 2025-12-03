import Foundation
import SwiftUI
import os

// MARK: - Session Record Type

/// 会话记录类型
enum SessionRecordType: String, Codable, CaseIterable {
    case conversation = "conversation"    // 对话（显示在前）
    case transcription = "transcription"  // 转录（显示在后）
    
    var displayName: String {
        switch self {
        case .transcription: return "转录"
        case .conversation: return "对话"
        }
    }
    
    /// 通知中心风格的标题（英文简短）
    var displayTitle: String {
        switch self {
        case .transcription: return "Transcription"
        case .conversation: return "Chat"
        }
    }
    
    var icon: String {
        switch self {
        case .transcription: return "waveform"
        case .conversation: return "bubble.left.and.bubble.right"
        }
    }
    
    var color: Color {
        switch self {
        case .transcription: return .blue
        case .conversation: return .purple
        }
    }
}

// MARK: - Session Record

/// 会话记录模型
struct SessionRecord: Identifiable, Codable {
    let id: UUID
    let type: SessionRecordType
    var title: String  // 支持 AI 动态更新
    let preview: String
    let createdAt: Date
    var updatedAt: Date
    
    /// 对话消息历史（仅 conversation 类型使用）
    var messages: [SessionMessage]
    
    /// 转录文本（仅 transcription 类型使用）
    var transcriptionText: String?
    
    /// 来源应用 Bundle ID
    var appBundleId: String?
    
    init(
        id: UUID = UUID(),
        type: SessionRecordType,
        title: String,
        preview: String,
        messages: [SessionMessage] = [],
        transcriptionText: String? = nil,
        appBundleId: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.preview = preview
        self.createdAt = Date()
        self.updatedAt = Date()
        self.messages = messages
        self.transcriptionText = transcriptionText
        self.appBundleId = appBundleId
    }
    
    /// 格式化时间
    var formattedTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    /// 详细时间
    var detailedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: createdAt)
    }
}

// MARK: - Session Message

/// 对话消息（用于序列化）
struct SessionMessage: Identifiable, Codable {
    let id: UUID
    let role: SessionMessageRole
    let content: String
    let timestamp: Date
    
    init(id: UUID = UUID(), role: SessionMessageRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

enum SessionMessageRole: String, Codable {
    case user
    case assistant
}

// MARK: - Session History Service

/// 会话历史服务
/// 管理转录和对话的历史记录
@MainActor
final class SessionHistoryService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = SessionHistoryService()
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "SessionHistory")
    
    // MARK: - Published
    
    @Published var records: [SessionRecord] = [] {
        didSet { updateGroupedRecords() }
    }
    
    /// 按类型分组的记录（每组内按时间倒序，新的在上）
    @Published private(set) var groupedRecords: [SessionRecordType: [SessionRecord]] = [:]
    
    /// 更新分组缓存
    private func updateGroupedRecords() {
        let grouped = Dictionary(grouping: records, by: { $0.type })
        groupedRecords = grouped.mapValues { $0.sorted { $0.createdAt > $1.createdAt } }
    }
    
    // MARK: - Storage
    
    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Spoke/session_history.json")
    }
    
    // MARK: - Init
    
    private init() {
        loadRecords()
        updateGroupedRecords()  // didSet 在 init 期间不触发，需手动调用
    }
    
    // MARK: - Public API
    
    /// 保存对话记录（从 AnswerPanel）
    func saveConversation(panelId: UUID, messages: [ChatMessage]) {
        guard !messages.isEmpty else { return }
        
        // 自动生成标题（取第一条用户消息的前30字）
        let firstUserMessage = messages.first { $0.role == .user }?.content ?? "新对话"
        let fallbackTitle = generateTitle(from: firstUserMessage)
        
        // 预览（取最后一条 AI 回复的前50字）
        let lastAssistantMessage = messages.last { $0.role == .assistant }?.content ?? ""
        let preview = String(lastAssistantMessage.prefix(50))
        
        // 转换消息格式
        let sessionMessages = messages.map { msg in
            SessionMessage(
                id: msg.id,
                role: msg.role == .user ? .user : .assistant,
                content: msg.content,
                timestamp: msg.timestamp
            )
        }
        
        // 检查是否已存在（更新）
        if let index = records.firstIndex(where: { $0.id == panelId }) {
            records[index].messages = sessionMessages
            records[index].updatedAt = Date()
            saveRecords()
            logger.info("💬 Conversation updated: \(self.records[index].title)")
        } else {
            // 新建记录 - 先用 fallback 标题
            let record = SessionRecord(
                id: panelId,
                type: .conversation,
                title: fallbackTitle,
                preview: preview,
                messages: sessionMessages
            )
            records.insert(record, at: 0)
            saveRecords()
            logger.info("💬 Conversation saved: \(fallbackTitle)")
            
            // 异步生成 AI 标题（如果启用）
            Task {
                await generateAITitleIfNeeded(for: panelId, content: firstUserMessage)
            }
        }
    }
    
    /// 异步生成 AI 标题
    private func generateAITitleIfNeeded(for recordId: UUID, content: String) async {
        let llmSettings = LLMSettings.shared
        
        guard let aiTitle = await llmSettings.generateTitle(from: content) else {
            return
        }
        
        // 更新记录标题
        if let index = records.firstIndex(where: { $0.id == recordId }) {
            records[index].title = aiTitle
            records[index].updatedAt = Date()
            saveRecords()
            logger.info("✨ AI title generated: \(aiTitle)")
        }
    }
    
    /// 保存转录记录
    func saveTranscription(text: String, appBundleId: String? = nil) {
        let title = generateTitle(from: text)
        let preview = String(text.prefix(80))
        
        let record = SessionRecord(
            type: .transcription,
            title: title,
            preview: preview,
            transcriptionText: text,
            appBundleId: appBundleId
        )
        
        records.insert(record, at: 0)
        saveRecords()
        logger.info("📝 Transcription saved: \(title)")
    }
    
    /// 删除记录
    func deleteRecord(_ record: SessionRecord) {
        records.removeAll { $0.id == record.id }
        saveRecords()
        logger.info("🗑️ Record deleted: \(record.title)")
    }
    
    /// 按 ID 删除记录
    func deleteRecord(_ id: UUID) {
        if let record = records.first(where: { $0.id == id }) {
            deleteRecord(record)
        }
    }
    
    /// 清空所有记录
    func clearAll() {
        records.removeAll()
        saveRecords()
        logger.info("🗑️ All records cleared")
    }
    
    /// 清空指定类型的记录
    func clearRecords(of type: SessionRecordType) {
        records.removeAll { $0.type == type }
        saveRecords()
        logger.info("🗑️ \(type.displayName) records cleared")
    }
    
    /// 获取记录（用于恢复对话）
    func getRecord(id: UUID) -> SessionRecord? {
        records.first { $0.id == id }
    }
    
    // MARK: - Private
    
    /// 生成标题（智能截取）
    private func generateTitle(from text: String) -> String {
        // 移除换行，取前30字
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleaned.count <= 30 {
            return cleaned
        }
        
        // 尝试在标点处截断
        let truncated = String(cleaned.prefix(30))
        if let lastPunctuation = truncated.lastIndex(where: { "，。！？,.!?".contains($0) }) {
            return String(truncated[..<lastPunctuation]) + "..."
        }
        
        return truncated + "..."
    }
    
    /// 保存到文件
    private func saveRecords() {
        do {
            let data = try JSONEncoder().encode(records)
            
            // 确保目录存在
            let dir = storageURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            
            try data.write(to: storageURL)
        } catch {
            logger.error("❌ Failed to save records: \(error)")
        }
    }
    
    /// 从文件加载
    private func loadRecords() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: storageURL)
            records = try JSONDecoder().decode([SessionRecord].self, from: data)
            logger.info("📂 Loaded \(self.records.count) session records")
        } catch {
            logger.error("❌ Failed to load records: \(error)")
        }
    }
}
