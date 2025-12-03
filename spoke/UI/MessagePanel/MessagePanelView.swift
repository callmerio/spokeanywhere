import SwiftUI
import AppKit

// MARK: - Message Panel View

/// 消息面板主视图
struct MessagePanelView: View {
    @ObservedObject var state: MessagePanelState
    @ObservedObject var historyService = SessionHistoryService.shared
    
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
                
                // Pipeline 卡片（在最下面）
                ForEach(state.cards) { card in
                    MessageCardView(card: card)
                }
            }
        }
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
/// 点击即复制内容到剪贴板
struct MessageCardView: View {
    let card: MessageCard
    @State private var isHovered = false
    @State private var showCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 头部：阶段标签 + 时间
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
                
                Spacer()
                
                // 时间戳
                Text(card.formattedTime)
                    .font(.system(size: 10))
                    .foregroundColor(HUDTheme.textPlaceholder)
                
                // 重新润色按钮（悬浮显示）
                if isHovered && canReprocess {
                    Button(action: reprocess) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                            .foregroundColor(HUDTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            
            // 内容区域（可选择文本）
            Text(card.content)
                .font(.system(size: 13))
                .foregroundColor(HUDTheme.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            
            // 元数据
            if !card.metadata.isEmpty {
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
        }
        .padding(14)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            copyContent()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    /// 复制内容到剪贴板
    private func copyContent() {
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(card.content, forType: .string) else { return }
        
        // 视觉反馈（使用 Task 避免 View 销毁后闭包执行问题）
        withAnimation(.easeOut(duration: 0.15)) {
            showCopied = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.easeIn(duration: 0.2)) {
                showCopied = false
            }
        }
    }
    
    private var cardBackground: some View {
        ZStack {
            // 1. 底色：平时几乎透明，hover/复制时变亮
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(showCopied ? 0.15 : (isHovered ? 0.1 : 0.03)))
            
            // 2. 描边：给卡片一个极细的边缘，防止糊在一起
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(isHovered ? 0.2 : 0.08), lineWidth: 1)
        }
    }
    
    private var canReprocess: Bool {
        switch card.stage {
        case .asr: return true
        case .llm: return true
        default: return false
        }
    }
    
    private func reprocess() {
        // TODO: 实现重新处理逻辑
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
