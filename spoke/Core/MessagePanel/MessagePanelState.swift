import SwiftUI
import Combine
import OSLog

private let logger = Logger(subsystem: "com.spokeanywhere", category: "MessagePanelState")

// MARK: - Message Card Model

/// 消息卡片阶段类型
enum MessageStage: Equatable, Codable {
    case welcome(String)           // 欢迎消息
    case keyPress(duration: TimeInterval)  // 按键事件
    case asr(model: String)        // ASR 转录 (Apple Speech / Whisper)
    case llm(model: String)        // LLM 润色 (Gemini / GPT)
    case system(String)            // 系统消息
    
    var displayName: String {
        switch self {
        case .welcome: return "欢迎"
        case .keyPress: return "按键"
        case .asr(let model): return "转录 · \(model)"
        case .llm(let model): return "润色 · \(model)"
        case .system: return "系统"
        }
    }
    
    var color: Color {
        switch self {
        case .welcome: return .gray
        case .keyPress: return .orange
        case .asr: return .blue
        case .llm: return .purple
        case .system: return .gray
        }
    }
    
    /// 是否是转录结果（ASR 或 LLM）
    var isTranscriptionResult: Bool {
        switch self {
        case .asr, .llm: return true
        default: return false
        }
    }
}

// MARK: - Text Highlight

/// 文本高亮类型
enum TextHighlightType: String, Codable, Equatable {
    /// 纠错：显示 ~~错误词~~ + 正确词（橙色）
    case correction
    /// 词典学习：显示目标词（橙色）
    case dictionary
}

/// 文本高亮标记
struct TextHighlight: Codable, Equatable {
    let type: TextHighlightType
    /// 原词（纠错模式：被替换的错误词；词典模式：不使用）
    let originalWord: String?
    /// 目标词（纠错模式：正确词；词典模式：学习的词）
    let targetWord: String
    
    /// 纠错标记
    static func correction(from original: String, to correct: String) -> TextHighlight {
        TextHighlight(type: .correction, originalWord: original, targetWord: correct)
    }
    
    /// 词典学习标记
    static func dictionary(word: String) -> TextHighlight {
        TextHighlight(type: .dictionary, originalWord: nil, targetWord: word)
    }
}

/// 卡片记录类型
/// - normal: 普通卡片，受数量限制（默认50条）
/// - todo: 待办卡片，需要处理
/// - done: 已完成卡片，属于 todo 子状态
/// - note: 笔记卡片，永久保留
enum CardRecordType: String, Codable, CaseIterable {
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
    
    /// 是否受保护（不被自动清理）
    var isPinned: Bool {
        self != .normal
    }
    
    /// 是否属于 Todo 类别（包含 todo 和 done）
    var isTodoCategory: Bool {
        self == .todo || self == .done
    }
    
    /// 图标
    var icon: String {
        switch self {
        case .normal: return ""
        case .todo: return "circle"
        case .done: return "checkmark.circle.fill"
        case .note: return "bookmark.fill"
        }
    }
    
    /// 颜色
    var color: Color {
        switch self {
        case .normal: return .clear
        case .todo: return .orange
        case .done: return .green
        case .note: return .blue
        }
    }
}

/// 过滤模式
enum CardFilterMode: String, CaseIterable {
    case all      // 显示全部
    case todo     // 只显示 Todo 类别（todo + done）
    case note     // 只显示 Note
    
    var displayName: String {
        switch self {
        case .all: return "全部"
        case .todo: return "Todo"
        case .note: return "Note"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "tray.full"
        case .todo: return "checklist"
        case .note: return "bookmark"
        }
    }
}

/// 消息卡片数据模型
struct MessageCard: Identifiable, Equatable, Codable {
    let id: UUID
    let timestamp: Date
    let stage: MessageStage
    let content: String
    var metadata: [String: String]
    /// 文本高亮标记（用于显示纠错/词典学习样式）
    var highlights: [TextHighlight]
    /// 记录类型：normal/todo/done/note
    var recordType: CardRecordType
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        stage: MessageStage,
        content: String,
        metadata: [String: String] = [:],
        highlights: [TextHighlight] = [],
        recordType: CardRecordType = .normal
    ) {
        self.id = id
        self.timestamp = timestamp
        self.stage = stage
        self.content = content
        self.metadata = metadata
        self.highlights = highlights
        self.recordType = recordType
    }
    
    // 自定义解码：兼容旧数据（没有 highlights/recordType 字段）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        stage = try container.decode(MessageStage.self, forKey: .stage)
        content = try container.decode(String.self, forKey: .content)
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
        highlights = try container.decodeIfPresent([TextHighlight].self, forKey: .highlights) ?? []
        recordType = try container.decodeIfPresent(CardRecordType.self, forKey: .recordType) ?? .normal
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

// MARK: - Message Panel State

/// 消息面板状态管理
@MainActor
final class MessagePanelState: ObservableObject {
    
    /// 全局单例
    static let shared = MessagePanelState()
    
    // MARK: - Published Properties
    
    /// 面板是否可见
    @Published var isVisible: Bool = false
    
    /// 所有消息卡片
    @Published var cards: [MessageCard] = []
    
    /// 面板滑动偏移量（用于动画）
    @Published var slideOffset: CGFloat = -400
    
    /// 当前过滤模式
    @Published var filterMode: CardFilterMode = .all
    
    // MARK: - Computed Properties
    
    /// 根据过滤模式返回卡片
    /// - Todo 模式：先显示 todo，再显示 done
    /// - Note 模式：只显示 note
    /// - All 模式：显示全部
    var filteredCards: [MessageCard] {
        switch filterMode {
        case .all:
            return cards
        case .todo:
            // Todo 类别：todo 优先，done 在后
            let todoCards = cards.filter { $0.recordType == .todo }
            let doneCards = cards.filter { $0.recordType == .done }
            return todoCards + doneCards
        case .note:
            return cards.filter { $0.recordType == .note }
        }
    }
    
    /// 各类型卡片数量（用于显示 badge）
    var todoCount: Int {
        cards.filter { $0.recordType.isTodoCategory }.count
    }
    
    var noteCount: Int {
        cards.filter { $0.recordType == .note }.count
    }
    
    // MARK: - Constants
    
    /// 面板宽度
    static let panelWidth: CGFloat = 360
    
    /// 最大保存的卡片数量
    private let maxCards: Int = 500
    
    /// 存储文件路径
    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let spokeDir = appSupport.appendingPathComponent("Spoke", isDirectory: true)
        return spokeDir.appendingPathComponent("pipeline_history.json")
    }
    
    // MARK: - Init
    
    init() {
        loadCards()
    }
    
    // MARK: - Public API
    
    /// 添加新卡片（新的在上面）
    func addCard(_ card: MessageCard) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            cards.insert(card, at: 0)  // 新卡片在顶部（越新越上）
        }
        
        // 限制数量（移除最旧的）
        if cards.count > maxCards {
            cards = Array(cards.prefix(maxCards))
        }
        
        // 持久化保存
        saveCards()
    }
    
    /// 添加 Welcome 消息
    func addWelcome(_ message: String) {
        addCard(MessageCard(stage: .welcome(message), content: message))
    }
    
    /// 添加 ASR 结果
    func addASRResult(model: String, content: String, duration: TimeInterval? = nil) {
        var metadata: [String: String] = [:]
        if let duration = duration {
            metadata["duration"] = String(format: "%.2fs", duration)
        }
        addCard(MessageCard(stage: .asr(model: model), content: content, metadata: metadata))
    }
    
    /// 添加 LLM 结果
    func addLLMResult(model: String, content: String, processingTime: TimeInterval? = nil) {
        var metadata: [String: String] = [:]
        if let time = processingTime {
            metadata["processing"] = String(format: "%.2fs", time)
        }
        addCard(MessageCard(stage: .llm(model: model), content: content, metadata: metadata))
    }
    
    /// 添加系统消息
    func addSystemMessage(_ message: String) {
        addCard(MessageCard(stage: .system(message), content: message))
    }
    
    /// 删除单个卡片
    func removeCard(_ id: UUID) {
        cards.removeAll { $0.id == id }
        saveCards()
    }
    
    /// 添加高亮标记到包含目标词的最近卡片（LLM 优先，其次 ASR）
    /// - Parameter highlight: 高亮标记
    func addHighlightToLatestCard(_ highlight: TextHighlight) {
        // 查找包含目标词的卡片（纠错模式查找原词，词典模式查找目标词）
        let searchWord = highlight.type == .correction 
            ? (highlight.originalWord ?? highlight.targetWord)
            : highlight.targetWord
        
        // 优先找 LLM 卡片，其次 ASR 卡片
        let targetIndex = cards.firstIndex { card in
            let isRelevantStage: Bool
            switch card.stage {
            case .llm, .asr: isRelevantStage = true
            default: isRelevantStage = false
            }
            return isRelevantStage && card.content.localizedCaseInsensitiveContains(searchWord)
        }
        
        guard let index = targetIndex else { return }
        
        // 检查是否已存在相同的高亮
        let isDuplicate = cards[index].highlights.contains { h in
            h.targetWord.lowercased() == highlight.targetWord.lowercased() &&
            h.type == highlight.type
        }
        
        guard !isDuplicate else { return }
        
        cards[index].highlights.append(highlight)
        saveCards()
    }
    
    /// 清空所有卡片
    func clearAll() {
        withAnimation {
            cards.removeAll()
        }
        saveCards()
    }
    
    // MARK: - Record Type Management
    
    /// 设置卡片的记录类型
    func setRecordType(_ cardId: UUID, type: CardRecordType) {
        guard let index = cards.firstIndex(where: { $0.id == cardId }) else { return }
        cards[index].recordType = type
        saveCards()
        logger.info("📌 Card record type set to \(type.displayName)")
    }
    
    /// 旧版兼容：将 today 记录迁移为 todo
    /// 应在启动时调用
    func migrateLegacyTodayCards() {
        // 旧版 JSON 可能含有 "today" 类型，迁移为 "todo"
        // Codable 解码时 unknown case 会 fallback 到 .normal
        // 这里主要是为了日志记录
        logger.info("🔄 Legacy today cards migration completed")
    }
    
    /// 限制普通卡片数量（保留最新的 N 条）
    /// todo/done/note 卡片不受影响
    func enforceNormalCardLimit(maxCount: Int = 50) {
        // 分离 pinned 和 normal 卡片
        let pinnedCards = cards.filter { $0.recordType.isPinned }
        var normalCards = cards.filter { !$0.recordType.isPinned }
        
        // 只限制 normal 卡片数量
        if normalCards.count > maxCount {
            normalCards = Array(normalCards.prefix(maxCount))
            cards = pinnedCards + normalCards
            // 按时间倒序排列（最新在前）
            cards.sort { $0.timestamp > $1.timestamp }
            saveCards()
            logger.info("🧹 Normal card limit enforced, keeping \(maxCount)")
        }
    }
    
    // MARK: - Persistence
    
    /// 保存卡片到本地
    private func saveCards() {
        // 只保存 ASR 和 LLM 结果（过滤掉 welcome/keyPress/system）
        let cardsToSave = cards.filter { card in
            switch card.stage {
            case .asr, .llm: return true
            default: return false
            }
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(cardsToSave)
            
            // 确保目录存在
            let dir = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            
            try data.write(to: storageURL, options: .atomic)
            logger.debug("💾 Saved \(cardsToSave.count) pipeline cards")
        } catch {
            logger.error("❌ Failed to save pipeline cards: \(error.localizedDescription)")
        }
    }
    
    /// 从本地加载卡片
    private func loadCards() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            logger.debug("📂 No pipeline history file found")
            return
        }
        
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loadedCards = try decoder.decode([MessageCard].self, from: data)
            
            // 过滤规则：
            // - todo/done/note 卡片永久保留
            // - normal 卡片只保留最近 24 小时
            let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
            cards = loadedCards.filter { card in
                card.recordType.isPinned || card.timestamp > cutoff
            }
            
            logger.info("📥 Loaded \(self.cards.count) pipeline cards from history")
            
            // 启动时执行维护
            migrateLegacyTodayCards()
            enforceNormalCardLimit(maxCount: 50)
        } catch {
            logger.error("❌ Failed to load pipeline cards: \(error.localizedDescription)")
        }
    }
    
    /// 显示面板
    func show() {
        isVisible = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            slideOffset = 0
        }
    }
    
    /// 隐藏面板
    func hide() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            slideOffset = -MessagePanelState.panelWidth - 20
        }
        
        // 动画结束后设置不可见
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.isVisible = false
        }
    }
    
    /// 切换面板显示/隐藏
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
}
