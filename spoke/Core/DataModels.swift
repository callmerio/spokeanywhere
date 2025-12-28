import Foundation
import SwiftData

// MARK: - Record Type

/// 历史记录类型
/// - normal: 普通记录，受自动清理策略影响
/// - todo: 待办记录，需要处理
/// - done: 已完成记录，属于 todo 子状态
/// - note: 笔记，永久保留不被自动清理
enum HistoryRecordType: String, Codable, CaseIterable {
    case normal
    case todo
    case done
    case note
    
    var displayName: String {
        switch self {
        case .normal: return "普通"
        case .todo: return "Todo"
        case .done: return "Done"
        case .note: return "Note"
        }
    }
    
    var isPinned: Bool {
        self != .normal
    }
    
    /// 是否属于 Todo 类别（包含 todo 和 done）
    var isTodoCategory: Bool {
        self == .todo || self == .done
    }
}

@Model
class HistoryItem {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var rawText: String
    var processedText: String?
    var audioPath: String? // Relative path in sandbox/container
    var audioDuration: TimeInterval? // Audio duration in seconds
    var appBundleId: String?
    // Requires ValueTransformer if complex, 
    // but basic arrays of string are supported in recent SwiftData
    var tags: [String]
    
    /// 记录类型：normal/todo/done/note
    /// - normal: 受自动清理策略影响
    /// - todo: 待办事项，不自动清理
    /// - done: 已完成，属于 todo 子状态
    /// - note: 永久保留
    var recordTypeRaw: String = HistoryRecordType.normal.rawValue
    
    var recordType: HistoryRecordType {
        get { HistoryRecordType(rawValue: recordTypeRaw) ?? .normal }
        set { recordTypeRaw = newValue.rawValue }
    }
    
    @Relationship(deleteRule: .nullify)
    var providerConfig: AIProviderConfig?
    
    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        rawText: String,
        processedText: String? = nil,
        audioPath: String? = nil,
        audioDuration: TimeInterval? = nil,
        appBundleId: String? = nil,
        tags: [String] = [],
        recordType: HistoryRecordType = .normal
    ) {
        self.id = id
        self.createdAt = createdAt
        self.rawText = rawText
        self.processedText = processedText
        self.audioPath = audioPath
        self.audioDuration = audioDuration
        self.appBundleId = appBundleId
        self.tags = tags
        self.recordTypeRaw = recordType.rawValue
    }
    
    // MARK: - Computed Properties
    
    /// 显示用的文本（优先 processedText）
    var displayText: String {
        processedText ?? rawText
    }
    
    /// 是否有音频可播放
    var hasAudio: Bool {
        audioPath != nil
    }
    
    /// 格式化的音频时长
    var formattedDuration: String {
        guard let duration = audioDuration else { return "--:--" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

@Model
class AppRule {
    @Attribute(.unique) var bundleId: String
    var appName: String
    var extraPrompt: String
    var isEnabled: Bool
    
    init(bundleId: String, appName: String, extraPrompt: String, isEnabled: Bool = true) {
        self.bundleId = bundleId
        self.appName = appName
        self.extraPrompt = extraPrompt
        self.isEnabled = isEnabled
    }
}

@Model
class AIProviderConfig {
    @Attribute(.unique) var providerId: String // e.g. "gemini-user-1"
    var displayName: String
    var apiKeyReference: String // Keychain Key Identifier
    var baseURL: String?
    var defaultModelId: String
    var isDefault: Bool
    
    init(providerId: String, displayName: String, apiKeyReference: String, baseURL: String? = nil, defaultModelId: String, isDefault: Bool = false) {
        self.providerId = providerId
        self.displayName = displayName
        self.apiKeyReference = apiKeyReference
        self.baseURL = baseURL
        self.defaultModelId = defaultModelId
        self.isDefault = isDefault
    }
}
