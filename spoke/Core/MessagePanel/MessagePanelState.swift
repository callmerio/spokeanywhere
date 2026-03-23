import AppKit
import Combine
import IdentifiedCollections
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.spokeanywhere", category: "MessagePanelState")

private enum MessagePanelFilterEngine {
    static func filteredCards(
        from cards: IdentifiedArrayOf<MessageCard>,
        filterMode: CardFilterMode,
        activeFilterTagIds: Set<UUID>
    ) -> [MessageCard] {
        switch filterMode {
        case .all:
            let sortedCards = Array(cards).sorted { $0.timestamp > $1.timestamp }
            guard !activeFilterTagIds.isEmpty else { return sortedCards }
            return sortByTagMatchKeepingOrder(sortedCards, activeFilterTagIds: activeFilterTagIds)
        case .todo:
            let todoCards = Array(cards.filter { $0.recordType == .todo })
                .sorted { $0.timestamp > $1.timestamp }
            let doneCards = Array(cards.filter { $0.recordType == .done })
                .sorted { $0.timestamp > $1.timestamp }

            guard !activeFilterTagIds.isEmpty else {
                return todoCards + doneCards
            }

            let (matchedTodo, unmatchedTodo) = partitionByTagMatch(todoCards, activeFilterTagIds: activeFilterTagIds)
            let (matchedDone, unmatchedDone) = partitionByTagMatch(doneCards, activeFilterTagIds: activeFilterTagIds)
            return matchedTodo + matchedDone + unmatchedTodo + unmatchedDone
        case .note:
            let noteCards = Array(cards.filter { $0.recordType == .note })
                .sorted { $0.timestamp > $1.timestamp }
            guard !activeFilterTagIds.isEmpty else { return noteCards }
            return sortByTagMatchKeepingOrder(noteCards, activeFilterTagIds: activeFilterTagIds)
        }
    }

    static func partitionByTagMatch(
        _ cards: [MessageCard],
        activeFilterTagIds: Set<UUID>
    ) -> ([MessageCard], [MessageCard]) {
        let matched = cards.filter { card in
            activeFilterTagIds.isSubset(of: Set(card.tagIds))
        }
        let unmatched = cards.filter { card in
            !activeFilterTagIds.isSubset(of: Set(card.tagIds))
        }
        return (matched, unmatched)
    }

    static func sortByTagMatchKeepingOrder(
        _ cards: [MessageCard],
        activeFilterTagIds: Set<UUID>
    ) -> [MessageCard] {
        let (matched, unmatched) = partitionByTagMatch(cards, activeFilterTagIds: activeFilterTagIds)
        return matched + unmatched
    }
}

private enum MessagePanelStorage {
    static func storageURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let spokeDir = appSupport.appendingPathComponent("Spoke", isDirectory: true)
        return spokeDir.appendingPathComponent("pipeline_history.json")
    }

    static func save(cards: [MessageCard], to storageURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(cards)

        let dir = storageURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: storageURL, options: .atomic)
    }

    static func load(from storageURL: URL) throws -> [MessageCard] {
        let data = try Data(contentsOf: storageURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([MessageCard].self, from: data)
    }
}

@MainActor
struct MessagePanelStateDependencies {
    let tagLibrary: TagLibrary
    let attachmentStorage: CardAttachmentStorage
    let attachmentImageCache: AttachmentImageCache
    let notificationCenter: NotificationCenter
    let llmSettings: LLMSettings
    let generateSummary: @Sendable (UUID) async -> Void
}

@MainActor
extension MessagePanelStateDependencies {
    static let live = MessagePanelStateDependencies(
        tagLibrary: .shared,
        attachmentStorage: .shared,
        attachmentImageCache: .shared,
        notificationCenter: .default,
        llmSettings: .shared,
        generateSummary: { @Sendable cardId in
            await runMessagePanelSummary(cardId: cardId)
        }
    )
}

private enum MessagePanelCardMaintenance {
    static func persistableCards(from cards: IdentifiedArrayOf<MessageCard>) -> [MessageCard] {
        cards.filter { card in
            switch card.stage {
            case .asr, .llm, .clipboard:
                return true
            default:
                return false
            }
        }
    }

    static func retainedLoadedCards(_ loadedCards: [MessageCard], cutoff: Date) -> [MessageCard] {
        var filtered = loadedCards.filter { card in
            card.recordType.isPinned || card.timestamp > cutoff
        }
        filtered.sort { $0.timestamp < $1.timestamp }
        return filtered
    }
}

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

// MARK: - Summary Status

/// 总结状态
enum SummaryStatus: String, Codable, Equatable {
    case none       // 未总结
    case pending    // 等待中
    case generating // 生成中
    case completed  // 已完成
    case failed     // 失败
    
    var isInProgress: Bool {
        self == .pending || self == .generating
    }
}

/// 内容类型（用于总结时的处理策略）
enum CardContentType: String, Codable, Equatable {
    case text       // 普通文本
    case image      // 图片（需要多模态模型）
    case url        // 网页链接（需要先抓取内容）
    case mixed      // 混合内容
    
    /// 从内容自动检测类型
    static func detect(from content: String, attachments: [CardAttachment]) -> CardContentType {
        // 有图片附件
        if !attachments.isEmpty {
            return content.isEmpty ? .image : .mixed
        }
        // URL 检测
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let matches = detector.matches(in: content, range: NSRange(content.startIndex..., in: content))
            if matches.count == 1, let match = matches.first,
               let range = Range(match.range, in: content),
               content[range].count > content.count / 2 {
                // URL 占据内容主体
                return .url
            }
        }
        return .text
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

/// 消息卡片数据模型（class + ObservableObject 避免 ForEach 全量重绘）
final class MessageCard: ObservableObject, Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let stage: MessageStage
    let content: String
    @Published var metadata: [String: String]
    /// 文本高亮标记（用于显示纠错/词典学习样式）
    @Published var highlights: [TextHighlight]
    /// 记录类型：normal/todo/done/note
    @Published var recordType: CardRecordType
    /// 标签 ID 列表（通过 TagLibrary 获取完整信息）
    @Published var tagIds: [UUID]
    /// 附件列表（截图等）
    @Published var attachments: [CardAttachment]
    /// 来源应用信息（用于显示图标和光晕）
    var sourceApp: SourceAppInfo?
    
    // MARK: - Summary
    
    /// 总结内容
    @Published var summary: String?
    /// 总结状态
    @Published var summaryStatus: SummaryStatus
    /// 内容类型（用于选择总结策略）
    var contentType: CardContentType
    
    // MARK: - Codable Keys
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, stage, content, metadata, highlights
        case recordType, tagIds, attachments, sourceApp
        case summary, summaryStatus, contentType
    }
    
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
        sourceApp: SourceAppInfo? = nil,
        summary: String? = nil,
        summaryStatus: SummaryStatus = .none,
        contentType: CardContentType? = nil
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
        self.summary = summary
        self.summaryStatus = summaryStatus
        // 自动检测内容类型
        self.contentType = contentType ?? CardContentType.detect(from: content, attachments: attachments)
    }
    
    // 自定义解码：兼容旧数据 + @Published 属性
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 先解码所有值到本地变量
        let decodedId = try container.decode(UUID.self, forKey: .id)
        let decodedTimestamp = try container.decode(Date.self, forKey: .timestamp)
        let decodedStage = try container.decode(MessageStage.self, forKey: .stage)
        let decodedContent = try container.decode(String.self, forKey: .content)
        let decodedMetadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
        let decodedHighlights = try container.decodeIfPresent([TextHighlight].self, forKey: .highlights) ?? []
        let decodedRecordType = try container.decodeIfPresent(CardRecordType.self, forKey: .recordType) ?? .normal
        let decodedTagIds = try container.decodeIfPresent([UUID].self, forKey: .tagIds) ?? []
        let decodedAttachments = try container.decodeIfPresent([CardAttachment].self, forKey: .attachments) ?? []
        let decodedSourceApp = try container.decodeIfPresent(SourceAppInfo.self, forKey: .sourceApp)
        let decodedSummary = try container.decodeIfPresent(String.self, forKey: .summary)
        let decodedSummaryStatus = try container.decodeIfPresent(SummaryStatus.self, forKey: .summaryStatus) ?? .none
        let decodedContentType = try container.decodeIfPresent(CardContentType.self, forKey: .contentType)
            ?? CardContentType.detect(from: decodedContent, attachments: decodedAttachments)
        
        // 然后赋值给属性
        self.id = decodedId
        self.timestamp = decodedTimestamp
        self.stage = decodedStage
        self.content = decodedContent
        self.metadata = decodedMetadata
        self.highlights = decodedHighlights
        self.recordType = decodedRecordType
        self.tagIds = decodedTagIds
        self.attachments = decodedAttachments
        self.sourceApp = decodedSourceApp
        self.summary = decodedSummary
        self.summaryStatus = decodedSummaryStatus
        self.contentType = decodedContentType
    }
    
    // 自定义编码：@Published 属性需要手动编码
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(stage, forKey: .stage)
        try container.encode(content, forKey: .content)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(highlights, forKey: .highlights)
        try container.encode(recordType, forKey: .recordType)
        try container.encode(tagIds, forKey: .tagIds)
        try container.encode(attachments, forKey: .attachments)
        try container.encodeIfPresent(sourceApp, forKey: .sourceApp)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encode(summaryStatus, forKey: .summaryStatus)
        try container.encode(contentType, forKey: .contentType)
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M-d HH:mm"
        return formatter.string(from: timestamp)
    }
    
    /// 是否有附件
    var hasAttachments: Bool {
        !attachments.isEmpty
    }
    
    /// 是否有总结
    var hasSummary: Bool {
        summary != nil && !summary!.isEmpty
    }
    
    /// 显示文本（优先总结，如果没有则显示原文）
    var displayText: String {
        if hasSummary {
            return summary!
        }
        return content
    }
    
    /// 是否需要总结（todo/note 类型且未总结）
    var needsSummary: Bool {
        (recordType == .todo || recordType == .note) && summaryStatus == .none
    }
}

// MARK: - MessageCard Equatable & Hashable

extension MessageCard: Equatable {
    static func == (lhs: MessageCard, rhs: MessageCard) -> Bool {
        // 只比较 ID，因为是引用类型，同一个对象的属性变化由 @Published 处理
        lhs.id == rhs.id
    }
}

extension MessageCard: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Message Panel State

/// 消息面板状态管理
@MainActor
final class MessagePanelState: ObservableObject {
    
    /// 全局单例
    static let shared = MessagePanelState(dependencies: .live)
    
    // MARK: - Published Properties
    
    /// 面板是否可见
    @Published var isVisible: Bool = false
    
    /// 所有消息卡片（使用 IdentifiedArray 优化 ForEach 性能）
    @Published var cards: IdentifiedArrayOf<MessageCard> = []
    
    /// 面板滑动偏移量（用于动画）
    @Published var slideOffset: CGFloat = -400
    
    /// 当前过滤模式
    @Published var filterMode: CardFilterMode = .all
    
    /// 当前激活的标签筛选（交集逻辑：必须同时包含所有标签）
    @Published var activeFilterTagIds: Set<UUID> = []
    
    /// 缓存的过滤结果（避免每次布局都重新计算）
    @Published private(set) var filteredCards: IdentifiedArrayOf<MessageCard> = []
    
    /// 分页：当前显示的卡片数量
    @Published var displayLimit: Int = 20
    
    /// 分页：每次加载更多的数量
    private let pageSize: Int = 15
    
    /// Combine 订阅存储
    private var cancellables = Set<AnyCancellable>()
    private let dependencies: MessagePanelStateDependencies
    private var tagDeletionObserver: NSObjectProtocol?
    
    // MARK: - Private
    
    /// 重新计算过滤结果（在 cards/filterMode/activeFilterTagIds 变化时调用）
    /// 注意：结果按最终显示顺序排序（新的在前），visibleCards 直接取前 N 个
    private func updateFilteredCards() {
        let result = MessagePanelFilterEngine.filteredCards(
            from: cards,
            filterMode: filterMode,
            activeFilterTagIds: activeFilterTagIds
        )
        
        // IdentifiedArray 的 ids 属性可以高效比较
        let resultIds = result.map(\.id)
        let currentIds = filteredCards.ids
        
        if resultIds != Array(currentIds) {
            filteredCards = IdentifiedArrayOf(uniqueElements: result)
        }
    }
    
    /// 各类型卡片数量（用于显示 badge）
    var todoCount: Int {
        cards.filter { $0.recordType.isTodoCategory }.count
    }
    
    var noteCount: Int {
        cards.filter { $0.recordType == .note }.count
    }
    
    // MARK: - Pagination
    
    /// 当前可见的卡片（分页，filteredCards 已按显示顺序排序）
    var visibleCards: [MessageCard] {
        // filteredCards 已按最终显示顺序排序（新的在前），直接取前 N 个
        Array(filteredCards.prefix(displayLimit))
    }
    
    /// 是否还有更多卡片可以加载
    var hasMoreCards: Bool {
        displayLimit < filteredCards.count
    }
    
    /// 剩余未显示的卡片数量
    var remainingCount: Int {
        max(0, filteredCards.count - displayLimit)
    }
    
    /// 加载更多卡片
    func loadMore() {
        displayLimit += pageSize
    }
    
    /// 重置分页（切换过滤模式时调用）
    func resetPagination() {
        displayLimit = 20
    }
    
    // MARK: - Constants
    
    /// 面板宽度
    static let panelWidth: CGFloat = 360
    
    /// 最大保存的卡片数量
    private let maxCards: Int = 500
    
    /// 存储文件路径
    private var storageURL: URL {
        MessagePanelStorage.storageURL()
    }
    
    // MARK: - Init
    
    convenience init() {
        self.init(dependencies: .live)
    }

    private init(dependencies: MessagePanelStateDependencies) {
        self.dependencies = dependencies
        loadCards()
        setupTagDeletionObserver()
        setupFilteredCardsSubscription()
        // 初始化过滤结果
        updateFilteredCards()
    }

    deinit {
        if let tagDeletionObserver {
            dependencies.notificationCenter.removeObserver(tagDeletionObserver)
        }
    }
    
    /// 设置过滤结果自动更新订阅
    private func setupFilteredCardsSubscription() {
        // 监听 cards 变化 - 防抖避免连续添加时频繁更新
        $cards
            .dropFirst()
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateFilteredCards()
            }
            .store(in: &cancellables)
        
        // 监听 filterMode 变化 - 防抖避免快速切换
        $filterMode
            .dropFirst()
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateFilteredCards()
            }
            .store(in: &cancellables)
        
        // 监听 activeFilterTagIds 变化 - 防抖避免取消搜索时多次触发
        $activeFilterTagIds
            .dropFirst()
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateFilteredCards()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public API
    
    /// 添加新卡片（append 到末尾，显示时 reversed 避免全量 diff）
    func addCard(_ card: MessageCard) {
        _ = withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            cards.append(card)  // IdentifiedArray append O(1)
        }
        
        // 限制数量（移除最旧的，即数组开头）
        if cards.count > maxCards {
            let kept = Array(cards.suffix(maxCards))
            cards = IdentifiedArrayOf(uniqueElements: kept)
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
        cards.remove(id: id)  // IdentifiedArray O(1) 删除
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
        let isDuplicate = cards[index].highlights.contains { existing in
            existing.targetWord.lowercased() == highlight.targetWord.lowercased() &&
            existing.type == highlight.type
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
    /// - Parameters:
    ///   - cardId: 卡片 ID
    ///   - type: 目标类型
    ///   - autoSummary: 是否自动生成总结（默认遵循设置）
    func setRecordType(_ cardId: UUID, type: CardRecordType, autoSummary: Bool? = nil) {
        guard let index = cards.firstIndex(where: { $0.id == cardId }) else { return }
        
        let previousType = cards[index].recordType
        cards[index].recordType = type
        saveCards()
        
        // 状态切换后重新排序（todo/done 分组显示）
        updateFilteredCards()
        
        logger.info("📌 Card record type set to \(type.displayName)")
        
        // 如果切换到 todo/note 且之前不是这两种类型，自动触发总结
        let shouldAutoSummary = autoSummary ?? dependencies.llmSettings.summaryAutoEnabled
        let isNewPinnedType = (type == .todo || type == .note) && previousType == .normal
        
        if shouldAutoSummary && isNewPinnedType && cards[index].summaryStatus == .none {
            let generateSummary = dependencies.generateSummary
            runMessagePanelStateAsync {
                await generateSummary(cardId)
            }
        }
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
        let pinnedCards = Array(cards.filter { $0.recordType.isPinned })
        let normalCards = Array(cards.filter { !$0.recordType.isPinned })
        
        // 只限制 normal 卡片数量
        if normalCards.count > maxCount {
            let keptNormal = Array(normalCards.prefix(maxCount))
            var combined = pinnedCards + keptNormal
            // 按时间正序排列（旧的在前，新的在后）
            combined.sort { $0.timestamp < $1.timestamp }
            cards = IdentifiedArrayOf(uniqueElements: combined)
            saveCards()
            logger.info("🧹 Normal card limit enforced, keeping \(maxCount)")
        }
    }
    
    // MARK: - Tag Management
    
    /// 添加标签到卡片
    func addTag(_ tagId: UUID, to cardId: UUID) {
        guard cards[id: cardId] != nil else { return }
        guard !(cards[id: cardId]?.tagIds.contains(tagId) ?? false) else { return }
        
        cards[id: cardId]?.tagIds.append(tagId)
        saveCards()
        
        // 标记为最近使用
        dependencies.tagLibrary.markAsRecentlyUsed(tagId)
        
        logger.info("🏷️ 添加标签到卡片")
    }
    
    /// 从卡片移除标签
    func removeTag(_ tagId: UUID, from cardId: UUID) {
        guard cards[id: cardId] != nil else { return }
        
        cards[id: cardId]?.tagIds.removeAll { $0 == tagId }
        saveCards()
        
        logger.info("🏷️ 从卡片移除标签")
    }
    
    /// 创建并添加标签到卡片（快捷方式）
    func createAndAddTag(name: String, to cardId: UUID) {
        let tag = dependencies.tagLibrary.createTag(name: name)
        addTag(tag.id, to: cardId)
    }
    
    /// 监听标签删除通知，移除相关引用
    func setupTagDeletionObserver() {
        guard tagDeletionObserver == nil else { return }
        tagDeletionObserver = dependencies.notificationCenter.addObserver(
            forName: .tagDeleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let tagId = notification.userInfo?["tagId"] as? UUID else { return }
            runMessagePanelStateOnMain(owner: self) { state in
                state.removeDeletedTagFromAllCards(tagId)
            }
        }
    }
    
    private func removeDeletedTagFromAllCards(_ tagId: UUID) {
        var modified = false
        for i in cards.indices where cards[i].tagIds.contains(tagId) {
            cards[i].tagIds.removeAll { $0 == tagId }
            modified = true
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
        dependencies.tagLibrary.tags(for: Array(activeFilterTagIds))
    }
    
    // MARK: - Attachment Management
    
    /// 添加附件到卡片（从图片）
    func addAttachment(_ image: NSImage, to cardId: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == cardId }) else { return }
        guard let attachment = dependencies.attachmentStorage.saveImage(image) else { return }
        
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
        dependencies.attachmentStorage.deleteAttachment(attachment)
        // 清除缓存
        dependencies.attachmentImageCache.clearCache(for: attachmentId)
        
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
    func saveCards() {
        let cardsToSave = MessagePanelCardMaintenance.persistableCards(from: cards)
        
        do {
            try MessagePanelStorage.save(cards: Array(cardsToSave), to: storageURL)
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
            let loadedCards = try MessagePanelStorage.load(from: storageURL)
            let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
            let filtered = MessagePanelCardMaintenance.retainedLoadedCards(loadedCards, cutoff: cutoff)
            cards = IdentifiedArrayOf(uniqueElements: filtered)
            
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
        scheduleMessagePanelStateMain(after: 0.35) { [weak self] in
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
