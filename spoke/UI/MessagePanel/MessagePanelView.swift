import SwiftUI
import AppKit

// MARK: - Hover State (用于键盘事件)

/// 追踪当前 hover 的卡片（用于 Cmd+V 粘贴图片/文本）
@MainActor
final class MessagePanelHoverState: ObservableObject {
    static let shared = MessagePanelHoverState()
    
    @Published var hoveredCardId: UUID?
    /// 鼠标是否在 Panel 区域内
    @Published var isMouseInPanel: Bool = false
    
    private var localMonitor: Any?
    private var globalMonitor: Any?
    
    private init() {
        setupKeyboardMonitor()
    }
    
    deinit {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    /// 设置键盘监听器（本地 + 全局）
    private func setupKeyboardMonitor() {
        // 本地监听（应用激活时）
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleCmdV(event) == true {
                return nil  // 已处理，拦截事件
            }
            return event
        }
        
        // 全局监听（应用未激活但鼠标在 Pipeline 上时）
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handleCmdV(event)
        }
    }
    
    /// 处理 Cmd+V 事件
    private func handleCmdV(_ event: NSEvent) -> Bool {
        // 检查是否是 Cmd+V
        guard event.modifierFlags.contains(.command),
              event.charactersIgnoringModifiers == "v" else {
            return false
        }
        
        // 如果 hover 在某个卡片上，尝试粘贴图片
        if let cardId = hoveredCardId {
            if pasteImageToCard(cardId) {
                return true
            }
        }
        
        // 如果鼠标在 Panel 区域但不在卡片上，尝试粘贴文本创建新节点
        if isMouseInPanel && MessagePanelManager.shared.isVisible {
            if pasteTextAsNewCard() {
                return true
            }
        }
        
        return false
    }
    
    /// 粘贴图片到指定卡片
    private func pasteImageToCard(_ cardId: UUID) -> Bool {
        let pasteboard = NSPasteboard.general
        
        // 仅检查图片类型
        let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png]
        guard pasteboard.availableType(from: imageTypes) != nil else {
            return false
        }
        
        // 读取图片
        if let image = NSImage(pasteboard: pasteboard) {
            MessagePanelState.shared.addAttachment(image, to: cardId)
            return true
        }
        
        return false
    }
    
    /// 粘贴文本创建新节点
    private func pasteTextAsNewCard() -> Bool {
        let pasteboard = NSPasteboard.general
        
        // 检查是否有文本
        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        // 触发 ClipboardPipelineService 创建新节点
        ClipboardPipelineService.shared.trigger()
        return true
    }
}

// MARK: - Message Panel View

/// 消息面板主视图
struct MessagePanelView: View {
    @ObservedObject var state: MessagePanelState
    @ObservedObject var historyService = SessionHistoryService.shared
    @StateObject private var dictionaryHandler = AddToDictionaryHandler.shared
    
    var body: some View {
        VStack(spacing: 12) {
            // 头部标题栏
            headerView
            
            // 标签筛选状态栏（有激活标签时显示）
            if !state.activeFilterTagIds.isEmpty {
                tagFilterStatusBar
            }
            
            // 统一内容区域（Pipeline + 历史记录）
            contentListView
            
            // 底部快捷提问按钮
            askButton
        }
        .padding(12)
        .frame(width: MessagePanelState.panelWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(panelBackground)
        .offset(x: state.slideOffset)  // 滑动动画
        // 追踪鼠标是否在 Panel 区域（用于 Cmd+V 粘贴）
        .onHover { isHovering in
            MessagePanelHoverState.shared.isMouseInPanel = isHovering
        }
        // 词典弹窗
        .sheet(isPresented: $dictionaryHandler.isShowingAddSheet) {
            QuickAddToDictionarySheet(
                isPresented: $dictionaryHandler.isShowingAddSheet,
                initialWord: dictionaryHandler.pendingWord,
                fullText: dictionaryHandler.pendingFullText  // 用于训练短语
            )
        }
        .sheet(isPresented: $dictionaryHandler.isShowingCorrectionSheet) {
            CorrectToSheet(
                isPresented: $dictionaryHandler.isShowingCorrectionSheet,
                errorText: dictionaryHandler.pendingWord,
                fullText: dictionaryHandler.pendingFullText  // 用于训练短语
            )
        }
    }
    
    // MARK: - Panel Background
    
    /// 🔮 系统原生毛玻璃背景 (NSVisualEffectView)
    /// 使用 .contentBackground 材质，更有质感
    @ViewBuilder
    private var panelBackground: some View {
        VisualEffectBlur(
            material: .popover,  // 更有质感的材质
            cornerRadius: 16
        )
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            // 大标题（类似"通知中心"）
            Text("Pipeline")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            // 过滤按钮组（包含关闭按钮）
            filterButtons
        }
        .padding(.horizontal, 4)  // 和 Chat 行对齐
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    /// 过滤按钮组
    private var filterButtons: some View {
        HStack(spacing: 6) {
            FilterChip(
                title: "Todo",
                count: state.todoCount,
                isActive: state.filterMode == .todo,
                color: .orange
            ) {
                state.filterMode = state.filterMode == .todo ? .all : .todo
                state.resetPagination()
            }
            
            FilterChip(
                title: "Note",
                count: state.noteCount,
                isActive: state.filterMode == .note,
                color: .blue
            ) {
                state.filterMode = state.filterMode == .note ? .all : .note
                state.resetPagination()
            }
            
            // 关闭按钮（隐藏面板）
            HoverCloseButton(action: {
                MessagePanelManager.shared.hide()
            }, size: 24, iconSize: 10)
        }
    }
    
    // MARK: - Tag Filter Status Bar
    
    /// 标签筛选状态栏（显示当前激活的筛选标签）
    private var tagFilterStatusBar: some View {
        HStack(spacing: 8) {
            // 筛选图标
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
            
            // 激活的标签气泡
            FlowLayout(spacing: 6) {
                ForEach(state.activeFilterTags) { tag in
                    ActiveFilterTagBubble(tag: tag) {
                        state.toggleTagFilter(tag.id)
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                }
            }
            
            Spacer()
            
            // 清除全部按钮
            Button {
                state.clearTagFilters()
            } label: {
                Text("清除")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        // 🍑 移除动画，避免卡死
    }
    
    
    private func clearAll() {
        state.clearAll()
        historyService.clearAll()
    }
    
    // MARK: - Content List (History + Pipeline)
    
    private var contentListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // 历史记录分组（Chat 在上，Transcription 在下）
                ForEach(SessionRecordType.allCases, id: \.self) { type in
                    if let records = historyService.groupedRecords[type], !records.isEmpty {
                        HistoryGroupView(
                            type: type,
                            records: records,
                            onRecordTap: handleRecordTap,
                            onClearType: { historyService.clearRecords(of: type) }
                        )
                    }
                }
                
                // Pipeline 卡片（分页显示，新卡片在上）
                let cards = state.visibleCards
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    MessageCardView(card: card, activeFilterTagIds: state.activeFilterTagIds) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            state.removeCard(card.id)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity).combined(with: .offset(y: -10)),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                    // 懒加载：最后一个卡片出现时加载更多
                    .onAppear {
                        if index == cards.count - 1 && state.hasMoreCards {
                            state.loadMore()
                        }
                    }
                }
                
                // 加载指示器（还有更多时显示）
                if state.hasMoreCards {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.vertical, 8)
                }
            }
        }
        .scrollIndicators(.hidden)
    }
    
    /// 处理历史记录点击
    private func handleRecordTap(_ record: SessionRecord) {
        switch record.type {
        case .conversation:
            // 恢复对话窗口
            restoreConversation(record)
        case .transcription:
            // 复制到剪贴板
            if let text = record.transcriptionText {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
        }
        
        // 隐藏面板
        MessagePanelManager.shared.hide()
    }
    
    /// 恢复对话窗口
    private func restoreConversation(_ record: SessionRecord) {
        // 转换消息格式
        let chatMessages = record.messages.map { msg in
            ChatMessage(
                role: msg.role == .user ? .user : .assistant,
                content: msg.content,
                attachments: []
            )
        }
        
        // 创建新面板并恢复消息
        let panelId = AnswerPanelManager.shared.show(
            question: record.title,
            attachments: []
        )
        
        // 延迟更新消息（等待窗口创建）
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            if let state = AnswerPanelManager.shared.state(for: panelId) {
                state.messages = chatMessages
                state.isLoading = false
            }
        }
    }
    
    // MARK: - Ask Button
    
    private var askButton: some View {
        Button(action: triggerQuickAsk) {
            HStack(spacing: 10) {
                // AI 图标
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(.purple)
                
                Text("提问 AI...")
                    .font(.system(size: 13))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                
                Spacer()
                
                // 快捷键提示
                Text("⌥T")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(DesignTokens.Colors.textPlaceholder)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(widgetBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private func triggerQuickAsk() {
        // 触发 Quick Ask（和 ⌥T 一样的效果）
        Task { @MainActor in
            // 先隐藏 Message Panel
            MessagePanelManager.shared.hide()
            
            // 等一小会让 Panel 开始隐藏动画
            try? await Task.sleep(for: .milliseconds(100))
            
            // 设置 Quick Ask 状态并触发
            HotKeyService.shared.isQuickAskActive = true
            HotKeyService.shared.onQuickAskStart?()
        }
    }
    
    // MARK: - Widget Background
    
    private var widgetBackground: some View {
        // Header 完全透明
        Color.clear
    }
}

// MARK: - Message Card View

/// 单个消息卡片视图（小组件风格）
/// 支持折叠/展开、复制、删除
struct MessageCardView: View {
    let card: MessageCard
    let activeFilterTagIds: Set<UUID>  // 从外部传入，避免在 TagListView 中观察整个 state
    var onDelete: (() -> Void)?
    
    @State private var isHovered = false
    @State private var showCopied = false
    @State private var isExpanded = false
    @State private var isShowingOriginal = false  // 点击展开原文（摘要模式）
    @State private var copyScale: CGFloat = 1.0
    @State private var showTagPopover = false
    @State private var isDropTargeted = false
    
    /// 折叠时显示的最大行数（类似 macOS 通知：1 行标题 + 3 行内容）
    private let collapsedMaxLines = 3
    /// 每行大约的字符数（用于估算是否需要折叠）
    private let charsPerLine = 25
    
    /// 是否需要折叠（内容超过阈值或有多个附件）
    private var needsCollapse: Bool {
        // 估算行数：总字符数 / 每行字符数
        let estimatedLines = card.content.count / charsPerLine
        let hasMultipleAttachments = card.attachments.count > 1
        return estimatedLines > collapsedMaxLines || hasMultipleAttachments
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // 卡片主体
            VStack(alignment: .leading, spacing: 8) {
                // 头部：阶段标签 + 时间 + 操作按钮
                headerView
                
                // 内容区域（支持折叠）
                contentView
                
                // 附件区域（仅 ASR/LLM 卡片显示）
                if card.stage.isTranscriptionResult && card.hasAttachments {
                    CardAttachmentView(
                        attachments: card.attachments,
                        cardId: card.id,
                        isExpanded: isExpanded
                    )
                }
                
                // 标签区域（仅 ASR/LLM 卡片显示）
                if card.stage.isTranscriptionResult {
                    tagsView
                }
                
                // 元数据
                if !card.metadata.isEmpty {
                    metadataView
                }
            }
            .padding(14)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                // 拖拽提示
                CardDropOverlay(isTargeted: isDropTargeted)
            )
            .scaleEffect(copyScale)
            .popover(isPresented: $showTagPopover, arrowEdge: .bottom) {
                AddTagPopover(cardId: card.id, isPresented: $showTagPopover)
            }
            // 拖拽支持
            .onDrop(of: [.image, .fileURL], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers)
            }
            
            // 复制成功浮动提示
            if showCopied {
                copyFeedbackBadge
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .offset(y: 8)),
                        removal: .opacity
                    ))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // 点击卡片交互：
            // - 有摘要：摘要 ↔ 展开原文（自动展开）
            // - 无摘要：折叠 ↔ 展开
            // - 其他：复制
            if card.summary != nil && card.summaryStatus == .completed {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isShowingOriginal.toggle()
                    // 切换到原文时自动展开，显示完整内容
                    if isShowingOriginal {
                        isExpanded = true
                    }
                }
            } else if needsCollapse {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } else {
                copyContent()
            }
        }
        .onHover { hovering in
            isHovered = hovering
            // 更新全局 hover 状态（用于键盘事件）
            if hovering && card.stage.isTranscriptionResult {
                MessagePanelHoverState.shared.hoveredCardId = card.id
            } else if MessagePanelHoverState.shared.hoveredCardId == card.id {
                MessagePanelHoverState.shared.hoveredCardId = nil
            }
        }
        .contextMenu {
            // 状态切换菜单（仅 ASR/LLM 卡片显示）
            if card.stage.isTranscriptionResult {
                // Todo 相关操作
                if card.recordType != .todo {
                    Button {
                        MessagePanelState.shared.setRecordType(card.id, type: .todo)
                    } label: {
                        Label("设为 Todo", systemImage: "circle")
                    }
                }
                
                // Done 相关操作（仅 Todo 类别显示）
                if card.recordType == .todo {
                    Button {
                        MessagePanelState.shared.setRecordType(card.id, type: .done)
                    } label: {
                        Label("标记完成", systemImage: "checkmark.circle.fill")
                    }
                }
                
                // Done → Todo（重新激活）
                if card.recordType == .done {
                    Button {
                        MessagePanelState.shared.setRecordType(card.id, type: .todo)
                    } label: {
                        Label("重新激活", systemImage: "arrow.uturn.backward.circle")
                    }
                }
                
                // Note 操作
                if card.recordType != .note {
                    Button {
                        MessagePanelState.shared.setRecordType(card.id, type: .note)
                    } label: {
                        Label("设为 Note", systemImage: "bookmark")
                    }
                }
                
                // 取消标记（回到 Normal）
                if card.recordType.isPinned {
                    Divider()
                    Button {
                        MessagePanelState.shared.setRecordType(card.id, type: .normal)
                    } label: {
                        Label("取消标记", systemImage: "xmark.circle")
                    }
                }
                
                Divider()
                
                // 添加标签
                Button {
                    showTagPopover = true
                } label: {
                    Label("添加标签", systemImage: "tag")
                }
                
                // 粘贴图片
                Button {
                    _ = MessagePanelState.shared.pasteImageFromClipboard(to: card.id)
                } label: {
                    Label("粘贴图片", systemImage: "photo.on.rectangle")
                }
                
                Divider()
            }
            
            // 总结相关操作（所有卡片都可以）
            if card.summary == nil || card.summary?.isEmpty == true {
                // 没有摘要时显示"总结"
                Button {
                    Task { await SummaryService.shared.generateSummary(for: card.id) }
                } label: {
                    Label("总结", systemImage: "text.quote")
                }
            } else {
                // 有摘要时显示"重新总结"
                Button {
                    Task { await SummaryService.shared.generateSummary(for: card.id, regenerate: true) }
                } label: {
                    Label("重新总结", systemImage: "arrow.clockwise")
                }
            }
            
            Button {
                copyContent()
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }
            
            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Drop Handler
    
    /// 处理拖拽
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard card.stage.isTranscriptionResult else { return false }
        
        var handled = false
        
        for provider in providers {
            // 尝试加载图片
            if provider.canLoadObject(ofClass: NSImage.self) {
                _ = provider.loadObject(ofClass: NSImage.self) { image, _ in
                    if let image = image as? NSImage {
                        Task { @MainActor in
                            MessagePanelState.shared.addAttachment(image, to: card.id)
                        }
                    }
                }
                handled = true
            }
            // 尝试加载文件 URL
            else if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
                    if let data = data as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil),
                       let image = NSImage(contentsOf: url) {
                        Task { @MainActor in
                            MessagePanelState.shared.addAttachment(image, to: card.id)
                        }
                    }
                }
                handled = true
            }
        }
        
        return handled
    }
    
    /// 仅粘贴图片（不处理文本/URL）
    private func pasteImageOnly() -> Bool {
        let pasteboard = NSPasteboard.general
        
        // 仅检查图片类型
        let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png]
        guard pasteboard.availableType(from: imageTypes) != nil else {
            return false
        }
        
        // 读取图片
        if let image = NSImage(pasteboard: pasteboard) {
            MessagePanelState.shared.addAttachment(image, to: card.id)
            return true
        }
        
        return false
    }
    
    // MARK: - Header
    
    /// 卡片标题（优先使用摘要标题，其次模型名）
    private var cardTitle: String {
        // 如果有摘要，显示 "总结: xxx"
        if let summary = card.summary, card.summaryStatus == .completed {
            // 取摘要的第一句或前 20 字作为标题
            let firstLine = summary.components(separatedBy: CharacterSet.newlines)
                .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? summary
            let maxLen = 25
            if firstLine.count > maxLen {
                return "总结: " + String(firstLine.prefix(maxLen)) + "..."
            }
            return "总结: " + firstLine
        }
        // 否则显示模型名
        return card.stage.displayName.isEmpty ? "Pipeline" : card.stage.displayName
    }
    
    private var headerView: some View {
        HStack(spacing: 8) {
            // 图标：应用图标或阶段指示器
            if let sourceApp = card.sourceApp {
                SourceAppIconView(
                    sourceApp: sourceApp,
                    glowColor: card.stage.glowColor,
                    typeName: card.stage.typeName
                )
            } else {
                // 无来源应用时显示阶段圆点
                Circle()
                    .fill(card.stage.color)
                    .frame(width: 8, height: 8)
                    .shadow(color: card.stage.glowColor.opacity(0.5), radius: 4, x: 0, y: 0)
            }
            
            // 标题（类似通知的 App 名称位置）
            Text(cardTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
            
            // Today/Note 标记
            if card.recordType.isPinned {
                recordTypeBadge
            }
            
            Spacer(minLength: 8)
            
            // 时间戳
            Text(card.formattedTime)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.white.opacity(0.4))
            
            // 操作按钮组（悬浮显示）
            if isHovered {
                HStack(spacing: 4) {
                    // 重新处理按钮
                    if canReprocess {
                        cardActionButton(icon: "arrow.clockwise", action: reprocess)
                    }
                    
                    // 展开/折叠按钮（只在需要折叠时显示）
                    if needsCollapse {
                        cardActionButton(
                            icon: (isExpanded || isShowingOriginal) ? "chevron.up" : "chevron.down",
                            action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }
                        )
                    }
                    
                    // 删除按钮
                    cardActionButton(icon: "xmark", action: { onDelete?() })
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.12), value: isHovered)
            }
        }
    }
    
    // MARK: - Content
    
    /// 是否应显示摘要
    /// - 点击展开原文，再次点击收起
    /// - 有摘要且未展开时显示摘要
    private var shouldShowSummary: Bool {
        !isShowingOriginal && card.summary != nil && card.summaryStatus == .completed
    }
    
    /// 显示的文本内容
    private var displayText: String {
        shouldShowSummary ? (card.summary ?? card.content) : card.content
    }
    
    private var contentView: some View {
        ZStack(alignment: .topLeading) {
            // 文本内容（固定从顶部开始显示）
            VStack(alignment: .leading, spacing: 4) {
                // 摘要生成中的提示（不阻塞内容显示）
                if card.summaryStatus == .generating {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("正在总结...")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(DesignTokens.Colors.textPlaceholder)
                    .padding(.bottom, 2)
                }
                
                // 有高亮标记时使用 HighlightedContentText，否则使用普通 Text
                Group {
                    if !card.highlights.isEmpty && !shouldShowSummary {
                        HighlightedContentText(
                            text: displayText,
                            highlights: card.highlights,
                            font: .systemFont(ofSize: 13),
                            foregroundColor: DesignTokens.Colors.NS.textPrimary
                        )
                    } else {
                        // 普通文本或摘要（摘要标题已在 header 显示，这里直接显示内容）
                        Text(displayText)
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.6))
                            .textSelection(.enabled)
                    }
                }
                .frame(minHeight: 20, alignment: .topLeading)
                // 恢复旧版高度计算：折叠时使用固定高度 (3行 * 18pt = 54pt)，避免 .fixedSize 导致的过度压缩
                .frame(maxHeight: needsCollapse && !isExpanded && !shouldShowSummary ? CGFloat(collapsedMaxLines * 18) : nil, alignment: .topLeading)
                .clipped()
                // 折叠时底部渐隐效果
                .mask {
                    if needsCollapse && !isExpanded && !shouldShowSummary {
                        VStack(spacing: 0) {
                            // 上方完全显示区域
                            Rectangle()
                            // 底部渐隐
                            LinearGradient(
                                colors: [.white, .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 20)
                        }
                    } else {
                        Rectangle()
                    }
                }
                
                // 折叠状态下，透明覆盖层拦截点击（NSTextView 会吃掉点击事件）
                if needsCollapse && !isExpanded && !shouldShowSummary {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded.toggle()
                            }
                        }
                }
            }
        }
    }
    
    // MARK: - Tags
    
    /// 从 TagLibrary 获取卡片标签
    private var cardTags: [CardTag] {
        TagLibrary.shared.tags(for: card.tagIds)
    }
    
    private var tagsView: some View {
        Group {
            if !cardTags.isEmpty {
                // 显示已有标签
                TagListView(tags: cardTags, cardId: card.id, activeFilterTagIds: activeFilterTagIds) {
                    showTagPopover = true
                }
            } else if isHovered {
                // 无标签时，hover 显示添加按钮
                Button {
                    showTagPopover = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "tag")
                            .font(.system(size: 10))
                        Text("添加标签")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(Color.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Metadata
    
    private var metadataView: some View {
        HStack(spacing: 8) {
            ForEach(Array(card.metadata.keys.sorted()), id: \.self) { key in
                if let value = card.metadata[key] {
                    Text("\(key): \(value)")
                        .font(.system(size: 9))
                        .foregroundColor(DesignTokens.Colors.textPlaceholder)
                }
            }
        }
    }
    
    // MARK: - Action Button
    
    /// 卡片操作按钮（hover 时显示背景）
    private func cardActionButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 20, height: 20)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Actions
    
    /// 复制内容到剪贴板
    private func copyContent() {
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(card.content, forType: .string) else { return }
        
        // 触觉反馈（如果支持）
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        
        // 动画：卡片轻微放大 + 显示浮动提示
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            copyScale = 1.02
            showCopied = true
        }
        
        // 恢复卡片大小
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                copyScale = 1.0
            }
            
            // 1.2秒后隐藏提示
            try? await Task.sleep(for: .milliseconds(1200))
            withAnimation(.easeOut(duration: 0.25)) {
                showCopied = false
            }
        }
    }
    
    /// 复制成功浮动提示（紧凑 + 半透明）
    private var copyFeedbackBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
            Text("已复制")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(.green)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
                .overlay(
                    Capsule()
                        .stroke(Color.green.opacity(0.4), lineWidth: 0.5)
                )
        )
        .offset(y: -6)
    }
    
    /// Todo/Done/Note 标记徽章
    private var recordTypeBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: card.recordType.icon)
                .font(.system(size: 8))
            Text(card.recordType.displayName)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundColor(card.recordType.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(card.recordType.color.opacity(0.15))
        .clipShape(Capsule())
    }
    
    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(showCopied ? 0.15 : (isHovered ? 0.1 : 0.03)))
            
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(isHovered ? 0.2 : 0.08), lineWidth: 1)
        }
    }
    
    private var canReprocess: Bool {
        switch card.stage {
        case .asr, .llm: return true
        default: return false
        }
    }
    
    private func reprocess() {
        // TODO: 实现重新处理逻辑
    }
}

// MARK: - Filter Chip

/// 过滤标签按钮
struct FilterChip: View {
    let title: String
    let count: Int
    let isActive: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(isActive ? Color.white.opacity(0.3) : color.opacity(0.3))
                        )
                }
            }
            .foregroundColor(isActive ? .white : color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isActive ? color : color.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(color.opacity(isActive ? 0 : 0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .fixedSize()  // 防止被压缩折叠
    }
}

// MARK: - Source App Icon View

/// 来源应用图标视图（带光晕效果 + hover 覆盖标签）
struct SourceAppIconView: View {
    let sourceApp: SourceAppInfo
    let glowColor: Color
    var typeName: String = ""  // 类型名称（转录/润色）
    
    @State private var isHovered = false
    
    /// hover 提示文本
    private var hoverText: String {
        if !typeName.isEmpty && !sourceApp.name.isEmpty {
            return "\(sourceApp.name) · \(typeName)"
        } else if !typeName.isEmpty {
            return typeName
        } else {
            return sourceApp.name
        }
    }
    
    var body: some View {
        ZStack {
            // 光晕效果
            Circle()
                .fill(glowColor.opacity(0.4))
                .frame(width: 26, height: 26)
                .blur(radius: 4)
            
            // 应用图标
            Group {
                if let icon = sourceApp.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .frame(width: 18, height: 18)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .frame(width: 26, height: 26)
        .contentShape(Rectangle())  // 扩大 hover 响应区域
        .onHover { hovering in
            // 🍑 移除动画，避免卡死
            isHovered = hovering
        }
        // 覆盖标签（用 overlay 实现悬浮）
        .overlay(alignment: .leading) {
            if isHovered && !hoverText.isEmpty {
                HStack(spacing: 6) {
                    // 小图标
                    Group {
                        if let icon = sourceApp.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            Image(systemName: "app.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .frame(width: 14, height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    
                    Text(hoverText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    ZStack {
                        // 磨砂背景
                        VisualEffectBlur(material: .hudWindow, cornerRadius: 6)
                        // 渐变遮罩
                        LinearGradient(
                            colors: [
                                glowColor.opacity(0.3),
                                glowColor.opacity(0.1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))
                .fixedSize()
                .allowsHitTesting(false)  // 不响应鼠标，防止闪烁
            }
        }
        .zIndex(100)  // 确保在最上层
    }
}

// MARK: - Selectable Text (NSTextView wrapper)

/// 可选择文本视图
struct SelectableText: NSViewRepresentable {
    let text: String
    var font: NSFont = .systemFont(ofSize: 13)
    var foregroundColor: NSColor = DesignTokens.Colors.NS.textPrimary
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }
        
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textColor = foregroundColor
        textView.font = font
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        
        // 禁用滚动，让外层 ScrollView 处理
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        if textView.string != text {
            textView.string = text
        }
        textView.textColor = foregroundColor
        textView.font = font
    }
    
    func font(_ font: Font) -> SelectableText {
        var copy = self
        // 简单转换，实际使用中可能需要更精确的转换
        copy.font = .systemFont(ofSize: 13)
        return copy
    }
    
    func foregroundColor(_ color: Color) -> SelectableText {
        var copy = self
        copy.foregroundColor = NSColor(color)
        return copy
    }
}

// VisualEffectBackground 已在 FloatingCapsuleView.swift 中定义

// MARK: - Preview

#Preview {
    let state = MessagePanelState()
    
    // 添加测试数据
    Task { @MainActor in
        state.addWelcome("Apple Speech is coming!")
        state.addWelcome("gpt-4o-mini is coming!")
        state.addASRResult(
            model: "Apple Speech",
            content: "这一下像左边这种就是图片上这种悬浮于整个屏幕的靠左边边角的悬浮框是如何实现的？",
            duration: 35.36
        )
        state.addLLMResult(
            model: "Gemini",
            content: "左侧这种悬浮于整个屏幕的靠左边边角的悬浮框是如何实现的？它里面的东西像一个管道一样...",
            processingTime: 1.2
        )
    }
    
    return MessagePanelView(state: state)
        .frame(height: 600)
        .padding()
        .background(Color.gray.opacity(0.3))
}
