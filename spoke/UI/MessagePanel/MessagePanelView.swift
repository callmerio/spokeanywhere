import AppKit
import SwiftUI

// MARK: - Hover State (用于键盘事件)

@MainActor
struct MessagePanelHoverStateDependencies {
    let isPanelVisible: () -> Bool
    let addAttachmentToCard: (NSImage, UUID) -> Void
    let triggerClipboardPipeline: () -> Void
}

@MainActor
struct MessagePanelViewDependencies {
    let restoreConversation: (SessionRecord) -> Void
}

/// 追踪当前 hover 的卡片（用于 Cmd+V 粘贴图片/文本）
@MainActor
final class MessagePanelHoverState: ObservableObject {
    static let shared = MessagePanelHoverState()
    
    @Published var hoveredCardId: UUID?
    /// 鼠标是否在 Panel 区域内
    @Published var isMouseInPanel: Bool = false
    
    nonisolated(unsafe) private var localMonitor: Any?
    nonisolated(unsafe) private var globalMonitor: Any?
    private var dependencies = MessagePanelHoverStateDependencies(
        isPanelVisible: { false },
        addAttachmentToCard: { _, _ in },
        triggerClipboardPipeline: {}
    )
    
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

    func configure(dependencies: MessagePanelHoverStateDependencies) {
        self.dependencies = dependencies
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
        if isMouseInPanel && dependencies.isPanelVisible() {
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
            dependencies.addAttachmentToCard(image, cardId)
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
        dependencies.triggerClipboardPipeline()
        return true
    }
}

// MARK: - Message Panel View

/// 消息面板主视图
struct MessagePanelView: View {
    @ObservedObject var state: MessagePanelState
    @ObservedObject var historyService: SessionHistoryService
    @ObservedObject var hoverState: MessagePanelHoverState
    @StateObject private var dictionaryHandler: AddToDictionaryHandler
    private let hidePanel: () -> Void
    private let startQuickAsk: () -> Void
    private let dependencies: MessagePanelViewDependencies
    private let cardDependencies: MessageCardViewDependencies

    init(
        state: MessagePanelState,
        historyService: SessionHistoryService,
        dictionaryHandler: AddToDictionaryHandler,
        hoverState: MessagePanelHoverState,
        hidePanel: @escaping () -> Void,
        startQuickAsk: @escaping () -> Void,
        dependencies: MessagePanelViewDependencies,
        cardDependencies: MessageCardViewDependencies
    ) {
        self.state = state
        self.historyService = historyService
        self.hoverState = hoverState
        self._dictionaryHandler = StateObject(wrappedValue: dictionaryHandler)
        self.hidePanel = hidePanel
        self.startQuickAsk = startQuickAsk
        self.dependencies = dependencies
        self.cardDependencies = cardDependencies
    }
    
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
            hoverState.isMouseInPanel = isHovering
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
                badgeCount: state.todoCount,
                isActive: state.filterMode == .todo,
                color: .orange
            ) {
                state.filterMode = state.filterMode == .todo ? .all : .todo
                state.resetPagination()
            }
            
            FilterChip(
                title: "Note",
                badgeCount: state.noteCount,
                isActive: state.filterMode == .note,
                color: .blue
            ) {
                state.filterMode = state.filterMode == .note ? .all : .note
                state.resetPagination()
            }
            
            // 关闭按钮（隐藏面板）
            HoverCloseButton(action: {
                hidePanel()
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
                    MessageCardView(
                        card: card,
                        activeFilterTagIds: state.activeFilterTagIds,
                        dependencies: cardDependencies
                    ) {
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
        hidePanel()
    }
    
    /// 恢复对话窗口
    private func restoreConversation(_ record: SessionRecord) {
        dependencies.restoreConversation(record)
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
        startQuickAsk()
    }
    
    // MARK: - Widget Background
    
    private var widgetBackground: some View {
        // Header 完全透明
        Color.clear
    }
}

// MARK: - Message Card View

/// 单个消息卡片视图（小组件风格）
// VisualEffectBackground 已在 FloatingCapsuleView.swift 中定义

// MARK: - Preview

#Preview {
    let state = MessagePanelState()
    let previewDependencies = MessagePanelViewDependencies(
        restoreConversation: { _ in }
    )
    let previewCardDependencies = MessageCardViewDependencies(
        hoverState: .shared,
        resolveTags: { TagLibrary.shared.tags(for: $0) },
        setRecordType: { state.setRecordType($0, type: $1) },
        pasteImageFromClipboard: { state.pasteImageFromClipboard(to: $0) },
        addAttachment: { image, id in state.addAttachment(image, to: id) },
        generateSummary: { id, regenerate in
            Task { await SummaryService.shared.generateSummary(for: id, regenerate: regenerate) }
        }
    )
    
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
    
    return MessagePanelView(
        state: state,
        historyService: .shared,
        dictionaryHandler: .shared,
        hoverState: .shared,
        hidePanel: {},
        startQuickAsk: {},
        dependencies: previewDependencies,
        cardDependencies: previewCardDependencies
    )
        .frame(height: 600)
        .padding()
        .background(Color.gray.opacity(0.3))
}
