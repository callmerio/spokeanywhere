import SwiftUI
import AppKit

// MARK: - Message Panel View

/// 消息面板主视图
struct MessagePanelView: View {
    @ObservedObject var state: MessagePanelState
    
    var body: some View {
        VStack(spacing: 12) {
            // 头部标题栏
            headerView
            
            // 消息列表
            messageListView
            
            // 底部快捷提问按钮
            askButton
        }
        .padding(12)
        .frame(width: MessagePanelState.panelWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .offset(x: state.slideOffset)  // 滑动动画
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Text("Pipeline")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(HUDTheme.textPrimary)
            
            Spacer()
            
            // 卡片数量
            if !state.cards.isEmpty {
                Text("\(state.cards.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(HUDTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Capsule())
            }
            
            // 清空按钮
            Button(action: { state.clearAll() }) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(HUDTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .opacity(state.cards.isEmpty ? 0.3 : 1)
            .disabled(state.cards.isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(widgetBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    // MARK: - Message List
    
    private var messageListView: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(state.cards) { card in
                    MessageCardView(card: card)
                }
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
        ZStack {
            // 毛玻璃效果
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
            // 深色叠加，类似通知中心小组件
            Color.black.opacity(0.35)
        }
    }
}

// MARK: - Message Card View

/// 单个消息卡片视图（小组件风格）
struct MessageCardView: View {
    let card: MessageCard
    @State private var isHovered = false
    
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
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private var cardBackground: some View {
        ZStack {
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
            Color.black.opacity(isHovered ? 0.4 : 0.35)
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
