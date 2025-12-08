import SwiftUI
import Combine
import OSLog
import AppKit

private let logger = Logger(subsystem: "com.spokeanywhere", category: "MessagePanelState")

// MARK: - Source App Info

/// 来源应用信息（用于 Pipeline 卡片显示）
struct SourceAppInfo: Codable, Equatable {
    let bundleId: String
    let name: String
    
    /// 运行时从 bundleId 获取应用图标（不持久化）
    var icon: NSImage? {
        guard let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleId
        ) else { return nil }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }
    
    /// 从 NSRunningApplication 创建
    static func from(_ app: NSRunningApplication) -> SourceAppInfo {
        SourceAppInfo(
            bundleId: app.bundleIdentifier ?? "unknown",
            name: app.localizedName ?? "Unknown"
        )
    }
    
    /// 从当前聚焦应用创建
    static func fromFrontmost() -> SourceAppInfo? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return nil
        }
        return from(app)
    }
    
    /// 从 TargetAppInfo 创建
    static func from(_ targetApp: TargetAppInfo) -> SourceAppInfo {
        SourceAppInfo(
            bundleId: targetApp.bundleIdentifier,
            name: targetApp.name
        )
    }
}

// MARK: - Message Card Model

/// 消息卡片阶段类型
enum MessageStage: Equatable, Codable {
    case welcome(String)           // 欢迎消息
    case keyPress(duration: TimeInterval)  // 按键事件
    case asr(model: String)        // ASR 转录 (Apple Speech / Whisper)
    case llm(model: String)        // LLM 润色 (Gemini / GPT)
    case clipboard                 // 剪贴板来源
    case system(String)            // 系统消息
    
    var displayName: String {
        switch self {
        case .welcome: return "欢迎"
        case .keyPress: return "按键"
        case .asr(let model): return model  // 只显示模型名
        case .llm(let model): return model  // 只显示模型名
        case .clipboard: return ""  // 单节点，不显示类型名
        case .system: return "系统"
        }
    }
    
    /// 类型名称（用于 hover 提示）
    var typeName: String {
        switch self {
        case .asr: return "转录"
        case .llm: return "润色"
        default: return ""
        }
    }
    
    var color: Color {
        switch self {
        case .welcome: return .gray
        case .keyPress: return .orange
        case .asr: return .cyan      // 转录用青色
        case .llm: return .orange    // 润色用橙色
        case .clipboard: return .green  // 单节点用绿色区分
        case .system: return .gray
        }
    }
    
    /// 光晕颜色（更柔和）
    var glowColor: Color {
        color.opacity(0.6)
    }
    
    /// 是否是转录结果（ASR / LLM / Clipboard）
    var isTranscriptionResult: Bool {
        switch self {
        case .asr, .llm, .clipboard: return true
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
    /// 标签 ID 列表（通过 TagLibrary 获取完整信息）
    var tagIds: [UUID]
    /// 附件列表（截图等）
    var attachments: [CardAttachment]
    /// 来源应用信息（用于显示图标和光晕）
    var sourceApp: SourceAppInfo?
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        stage: MessageStage,
        content: String,
        metadata: [String: String] = [:],
        highlights: [TextHighlight] = [],
        recordType: CardRecordType = .normal,
        tagIds: [UUID] = [],
        attachments: [CardAttachment] = [],
        sourceApp: SourceAppInfo? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.stage = stage
        self.content = content
        self.metadata = metadata
        self.highlights = highlights
        self.recordType = recordType
        self.tagIds = tagIds
        self.attachments = attachments
        self.sourceApp = sourceApp
    }
    
    // 自定义解码：兼容旧数据（没有 highlights/recordType/tagIds/attachments/sourceApp 字段）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        stage = try container.decode(MessageStage.self, forKey: .stage)
        content = try container.decode(String.self, forKey: .content)
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
        highlights = try container.decodeIfPresent([TextHighlight].self, forKey: .highlights) ?? []
        recordType = try container.decodeIfPresent(CardRecordType.self, forKey: .recordType) ?? .normal
        tagIds = try container.decodeIfPresent([UUID].self, forKey: .tagIds) ?? []
        attachments = try container.decodeIfPresent([CardAttachment].self, forKey: .attachments) ?? []
        sourceApp = try container.decodeIfPresent(SourceAppInfo.self, forKey: .sourceApp)
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
    
    /// 是否有附件
    var hasAttachments: Bool {
        !attachments.isEmpty
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
    
    /// 当前激活的标签筛选（交集逻辑：必须同时包含所有标签）
    @Published var activeFilterTagIds: Set<UUID> = []
    
    // MARK: - Computed Properties
    
    /// 根据过滤模式和标签筛选返回卡片
    /// - 标签筛选：包含所有激活标签的卡片置顶
    /// - Todo 模式：先显示 todo，再显示 done
    /// - Note 模式：只显示 note
    /// - All 模式：显示全部
    var filteredCards: [MessageCard] {
        var result: [MessageCard]
        
        switch filterMode {
        case .all:
            result = cards
        case .todo:
            // Todo 类别：todo 优先，done 在后
            let todoCards = cards.filter { $0.recordType == .todo }
            let doneCards = cards.filter { $0.recordType == .done }
            result = todoCards + doneCards
        case .note:
            result = cards.filter { $0.recordType == .note }
        }
        
        // 如果有标签筛选，按标签匹配排序
        if !activeFilterTagIds.isEmpty {
            result = sortByTagMatch(result)
        }
        
        return result
    }
    
    /// 按标签匹配排序（匹配的在前，按时间倒序）
    private func sortByTagMatch(_ cards: [MessageCard]) -> [MessageCard] {
        // 分离匹配和不匹配的卡片
        let matched = cards.filter { card in
            activeFilterTagIds.isSubset(of: Set(card.tagIds))
        }
        let unmatched = cards.filter { card in
            !activeFilterTagIds.isSubset(of: Set(card.tagIds))
        }
        return matched + unmatched
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
        setupTagDeletionObserver()
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
    func addASRResult(model: String, content: String, duration: TimeInterval? = nil, sourceApp: SourceAppInfo? = nil) {
        var metadata: [String: String] = [:]
        if let duration = duration {
            metadata["duration"] = String(format: "%.2fs", duration)
        }
        addCard(MessageCard(stage: .asr(model: model), content: content, metadata: metadata, sourceApp: sourceApp))
    }
    
    /// 添加 LLM 结果
    func addLLMResult(model: String, content: String, processingTime: TimeInterval? = nil, sourceApp: SourceAppInfo? = nil) {
        var metadata: [String: String] = [:]
        if let time = processingTime {
            metadata["processing"] = String(format: "%.2fs", time)
        }
        addCard(MessageCard(stage: .llm(model: model), content: content, metadata: metadata, sourceApp: sourceApp))
    }
    
    /// 添加剪贴板内容
    func addClipboardContent(content: String, sourceApp: SourceAppInfo? = nil) {
        addCard(MessageCard(stage: .clipboard, content: content, sourceApp: sourceApp))
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
    
    // MARK: - Tag Management
    
    /// 添加标签到卡片
    func addTag(_ tagId: UUID, to cardId: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == cardId }) else { return }
        guard !cards[index].tagIds.contains(tagId) else { return }
        
        cards[index].tagIds.append(tagId)
        saveCards()
        
        // 标记为最近使用
        TagLibrary.shared.markAsRecentlyUsed(tagId)
        
        logger.info("🏷️ 添加标签到卡片")
    }
    
    /// 从卡片移除标签
    func removeTag(_ tagId: UUID, from cardId: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == cardId }) else { return }
        
        cards[index].tagIds.removeAll { $0 == tagId }
        saveCards()
        
        logger.info("🏷️ 从卡片移除标签")
    }
    
    /// 创建并添加标签到卡片（快捷方式）
    func createAndAddTag(name: String, to cardId: UUID) {
        let tag = TagLibrary.shared.createTag(name: name)
        addTag(tag.id, to: cardId)
    }
    
    /// 监听标签删除通知，移除相关引用
    func setupTagDeletionObserver() {
        NotificationCenter.default.addObserver(
            forName: .tagDeleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let tagId = notification.userInfo?["tagId"] as? UUID else { return }
            Task { @MainActor in
                self?.removeDeletedTagFromAllCards(tagId)
            }
        }
    }
    
    private func removeDeletedTagFromAllCards(_ tagId: UUID) {
        var modified = false
        for i in cards.indices {
            if cards[i].tagIds.contains(tagId) {
                cards[i].tagIds.removeAll { $0 == tagId }
                modified = true
            }
        }
        if modified {
            saveCards()
            logger.info("🏷️ 从所有卡片移除已删除的标签")
        }
        
        // 同时从筛选条件中移除
        activeFilterTagIds.remove(tagId)
    }
    
    // MARK: - Tag Filtering
    
    /// 切换标签筛选状态（点击标签气泡触发）
    func toggleTagFilter(_ tagId: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if activeFilterTagIds.contains(tagId) {
                activeFilterTagIds.remove(tagId)
                logger.info("🏷️ 移除标签筛选")
            } else {
                activeFilterTagIds.insert(tagId)
                logger.info("🏷️ 添加标签筛选")
            }
        }
    }
    
    /// 清除所有标签筛选
    func clearTagFilters() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            activeFilterTagIds.removeAll()
        }
        logger.info("🏷️ 清除所有标签筛选")
    }
    
    /// 获取当前激活的筛选标签
    var activeFilterTags: [CardTag] {
        TagLibrary.shared.tags(for: Array(activeFilterTagIds))
    }
    
    // MARK: - Attachment Management
    
    /// 添加附件到卡片（从图片）
    func addAttachment(_ image: NSImage, to cardId: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == cardId }) else { return }
        guard let attachment = CardAttachmentStorage.shared.saveImage(image) else { return }
        
        cards[index].attachments.append(attachment)
        saveCards()
        
        logger.info("📎 添加附件到卡片")
    }
    
    /// 从卡片移除附件
    func removeAttachment(_ attachmentId: UUID, from cardId: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == cardId }) else { return }
        guard let attachmentIndex = cards[index].attachments.firstIndex(where: { $0.id == attachmentId }) else { return }
        
        let attachment = cards[index].attachments[attachmentIndex]
        
        // 删除文件
        CardAttachmentStorage.shared.deleteAttachment(attachment)
        // 清除缓存
        AttachmentImageCache.shared.clearCache(for: attachmentId)
        
        cards[index].attachments.remove(at: attachmentIndex)
        saveCards()
        
        logger.info("📎 从卡片移除附件")
    }
    
    /// 从剪贴板粘贴图片到卡片
    func pasteImageFromClipboard(to cardId: UUID) -> Bool {
        let pasteboard = NSPasteboard.general
        
        // 尝试读取图片
        if let image = NSImage(pasteboard: pasteboard) {
            addAttachment(image, to: cardId)
            return true
        }
        
        // 尝试读取文件 URL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls {
                if let image = NSImage(contentsOf: url) {
                    addAttachment(image, to: cardId)
                    return true
                }
            }
        }
        
        return false
    }
    
    // MARK: - Persistence
    
    /// 保存卡片到本地
    private func saveCards() {
        // 只保存 ASR/LLM/Clipboard 结果（过滤掉 welcome/keyPress/system）
        let cardsToSave = cards.filter { card in
            switch card.stage {
            case .asr, .llm, .clipboard: return true
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
