import SwiftUI
import AppKit

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
            
            // 过滤按钮组
            filterButtons
            
            // 清空全部按钮（hover 效果）
            let totalCount = state.cards.count + historyService.records.count
            HoverCloseButton(action: clearAll, size: 24, iconSize: 10)
                .opacity(totalCount > 0 ? 1 : 0.5)
                .disabled(totalCount == 0)
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
                withAnimation(.easeInOut(duration: 0.2)) {
                    state.filterMode = state.filterMode == .todo ? .all : .todo
                }
            }
            
            FilterChip(
                title: "Note",
                count: state.noteCount,
                isActive: state.filterMode == .note,
                color: .blue
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    state.filterMode = state.filterMode == .note ? .all : .note
                }
            }
        }
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
                
                // Pipeline 卡片（在最下面，根据过滤模式显示）
                ForEach(state.filteredCards) { card in
                    MessageCardView(card: card) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            state.removeCard(card.id)
                        }
                    }
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
                    .foregroundColor(HUDTheme.textSecondary)
                
                Spacer()
                
                // 快捷键提示
                Text("⌥T")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(HUDTheme.textPlaceholder)
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
    var onDelete: (() -> Void)?
    
    @State private var isHovered = false
    @State private var showCopied = false
    @State private var isExpanded = false
    @State private var copyScale: CGFloat = 1.0
    
    /// 折叠时显示的最大行数
    private let collapsedMaxLines = 6
    /// 每行大约的字符数（用于估算是否需要折叠）
    private let charsPerLine = 25
    
    /// 是否需要折叠（内容超过阈值）
    private var needsCollapse: Bool {
        // 估算行数：总字符数 / 每行字符数
        let estimatedLines = card.content.count / charsPerLine
        return estimatedLines > collapsedMaxLines
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // 卡片主体
            VStack(alignment: .leading, spacing: 8) {
                // 头部：阶段标签 + 时间 + 操作按钮
                headerView
                
                // 内容区域（支持折叠）
                contentView
                
                // 元数据
                if !card.metadata.isEmpty {
                    metadataView
                }
            }
            .padding(14)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(copyScale)
            
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
            // 点击卡片：
            // - 折叠状态 → 展开
            // - 展开状态或无需折叠 → 复制
            if needsCollapse && !isExpanded {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded = true
                }
            } else {
                copyContent()
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
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
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            // 阶段标签
            HStack(spacing: 4) {
                Circle()
                    .fill(card.stage.color)
                    .frame(width: 6, height: 6)
                
                Text(card.stage.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(HUDTheme.textSecondary)
            }
            
            // Today/Note 标记
            if card.recordType.isPinned {
                recordTypeBadge
            }
            
            Spacer()
            
            // 时间戳
            Text(card.formattedTime)
                .font(.system(size: 10))
                .foregroundColor(HUDTheme.textPlaceholder)
            
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
                            icon: isExpanded ? "chevron.up" : "chevron.down",
                            action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }
                        )
                    }
                    
                    // 删除按钮
                    cardActionButton(icon: "xmark", action: { onDelete?() })
                }
                .transition(.opacity)
            }
        }
    }
    
    // MARK: - Content
    
    private var contentView: some View {
        ZStack(alignment: .topLeading) {
            // 文本内容（固定从顶部开始显示）
            // 有高亮标记时使用 HighlightedContentText，否则使用 DictionarySelectableText
            Group {
                if !card.highlights.isEmpty {
                    HighlightedContentText(
                        text: card.content,
                        highlights: card.highlights,
                        font: .systemFont(ofSize: 13),
                        foregroundColor: HUDTheme.NS.textPrimary
                    )
                } else {
                    DictionarySelectableText(
                        text: card.content,
                        font: .systemFont(ofSize: 13),
                        foregroundColor: HUDTheme.NS.textPrimary
                    )
                }
            }
            .frame(minHeight: 20, alignment: .topLeading)
            .frame(maxHeight: isExpanded || !needsCollapse ? nil : CGFloat(collapsedMaxLines * 20), alignment: .topLeading)
            .clipped()
            // 使用 mask 实现文字渐隐效果
            .mask(
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        // 上方正常显示区域
                        Rectangle()
                            .frame(height: needsCollapse && !isExpanded ? geo.size.height - 30 : geo.size.height)
                        
                        // 底部渐隐区域（只在折叠时生效）
                        if needsCollapse && !isExpanded {
                            LinearGradient(
                                colors: [.white, .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 30)
                        }
                    }
                }
            )
            
            // 折叠状态下，透明覆盖层拦截点击（NSTextView 会吃掉点击事件）
            if needsCollapse && !isExpanded {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded = true
                        }
                    }
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
                        .foregroundColor(HUDTheme.textPlaceholder)
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
                .foregroundColor(HUDTheme.textSecondary)
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
    }
}

// MARK: - Selectable Text (NSTextView wrapper)

/// 可选择文本视图
struct SelectableText: NSViewRepresentable {
    let text: String
    var font: NSFont = .systemFont(ofSize: 13)
    var foregroundColor: NSColor = HUDTheme.NS.textPrimary
    
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
