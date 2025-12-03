import SwiftUI
import AppKit

// MARK: - History Group View

/// 历史记录分组视图（卡片叠放风格）
/// 折叠时显示最新一条 + 叠放装饰，展开显示全部
struct HistoryGroupView: View {
    let type: SessionRecordType
    let records: [SessionRecord]
    var onRecordTap: ((SessionRecord) -> Void)?
    var onClearType: (() -> Void)?
    
    @State private var isExpanded = false
    
    /// 最新的三条记录（用于叠放效果）
    private var topRecords: [SessionRecord] {
        Array(records.prefix(3))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                // 展开：显示所有记录
                expandedContent
            } else {
                // 折叠：叠放卡片
                stackedCardsView
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isExpanded)
    }
    
    // MARK: - Layout Constants
    
    private enum StackLayout {
        static let verticalOffset: CGFloat = 8
        static let horizontalPadding: CGFloat = 6
        static let placeholderHeight: CGFloat = 60
        static let cornerRadius: CGFloat = 16
    }
    
    // MARK: - Stacked Cards（折叠状态 - 向下三卡片叠放）
    
    private var stackedCardsView: some View {
        ZStack(alignment: .top) {
            // 第一层（最顶）- 显示完整内容
            if let first = topRecords.first {
                HistoryRecordCard(
                    record: first,
                    style: .prominent,
                    onTap: {
                        if records.count > 1 {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                isExpanded = true
                            }
                        } else {
                            onRecordTap?(first)
                        }
                    }
                )
                .zIndex(10)
            }
            
            // 第二层（中间）- 向下偏移
            if topRecords.count > 1 {
                stackedCardPlaceholder(layerIndex: 1)
                    .zIndex(5)
            }
            
            // 第三层（最底）- 向下偏移更多
            if topRecords.count > 2 {
                stackedCardPlaceholder(layerIndex: 2)
                    .zIndex(1)
            }
        }
        .padding(.bottom, stackBottomPadding)
    }
    
    /// 底部留白（让底层卡片露出）
    private var stackBottomPadding: CGFloat {
        CGFloat(min(topRecords.count - 1, 2)) * StackLayout.verticalOffset
    }
    
    /// 叠放卡片占位
    private func stackedCardPlaceholder(layerIndex: Int) -> some View {
        RoundedRectangle(cornerRadius: StackLayout.cornerRadius, style: .continuous)
            .fill(Color(white: 0.1))
            .overlay(
                RoundedRectangle(cornerRadius: StackLayout.cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            )
            .frame(height: StackLayout.placeholderHeight)
            .padding(.horizontal, CGFloat(layerIndex) * StackLayout.horizontalPadding)
            .offset(y: CGFloat(layerIndex) * StackLayout.verticalOffset)
    }
    
    // MARK: - Expanded Content（展开状态）
    
    private var expandedContent: some View {
        VStack(spacing: 8) {
            // 分类标题 + 收起按钮（通知中心风格）
            HStack(alignment: .center, spacing: 12) {
                // Chat 分类标题（和 Pipeline 对齐）
                Text(type.displayTitle)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // 收起按钮（hover 效果）
                HoverTextIconButton(text: "收起", systemImage: "chevron.up") {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        isExpanded = false
                    }
                }
                
                // × 按钮（hover 效果）
                HoverCloseButton(action: { onClearType?() }, size: 24, iconSize: 10)
            }
            .padding(.horizontal, 4)  // 和 Pipeline 对齐
            .padding(.vertical, 8)
            
            // 所有记录
            ForEach(records) { record in
                HistoryRecordCard(
                    record: record,
                    style: .normal,
                    onTap: { onRecordTap?(record) }
                )
            }
        }
        .padding(.bottom, 8)
    }
    
}

// MARK: - Card Style

enum HistoryCardStyle {
    case normal
    case prominent
}

// MARK: - History Record Card

/// 单条历史记录卡片（HUD 风格：毛玻璃 + 白色细边框）
/// 点击即复制内容到剪贴板
struct HistoryRecordCard: View {
    let record: SessionRecord
    var style: HistoryCardStyle = .normal
    var onTap: (() -> Void)?
    
    @State private var isHovered = false
    @State private var showCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // 内容区
                VStack(alignment: .leading, spacing: 6) {
                    // 标题
                    Text(record.title)
                        .font(.system(size: style == .prominent ? 14 : 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    // 预览
                    if !record.preview.isEmpty {
                        Text(record.preview)
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.6))
                            .lineLimit(3)  // 统一支持 3 行内容
                    }
                }
                
                Spacer(minLength: 8)
                
                // 时间
                Text(record.detailedTime)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(isHovered ? 0.15 : 0.1), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            copyContent()
            onTap?()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
    
    private var cardBackground: some View {
        ZStack {
            // 毛玻璃效果
            VisualEffectBlur(material: .hudWindow, cornerRadius: 16)
            
            // 深色叠加 (复制时短暂变亮)
            Color.black.opacity(showCopied ? 0.15 : (isHovered ? 0.25 : 0.3))
        }
    }
    
    /// 复制内容到剪贴板
    private func copyContent() {
        let textToCopy: String
        switch record.type {
        case .transcription:
            textToCopy = record.transcriptionText ?? record.preview
        case .conversation:
            // 复制最后一条 AI 回复
            if let lastAssistant = record.messages.last(where: { $0.role == .assistant }) {
                textToCopy = lastAssistant.content
            } else {
                textToCopy = record.preview
            }
        }
        
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(textToCopy, forType: .string) else { return }
        
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
}

// MARK: - Preview

#Preview {
    let testRecords = [
        SessionRecord(type: .conversation, title: "测试对话", preview: "您好！我是 AI 助手。"),
        SessionRecord(type: .transcription, title: "测试转录", preview: "这是一段转录文本"),
    ]
    
    return VStack(spacing: 12) {
        HistoryGroupView(
            type: .conversation,
            records: testRecords.filter { $0.type == .conversation }
        )
        HistoryGroupView(
            type: .transcription,
            records: testRecords.filter { $0.type == .transcription }
        )
    }
    .frame(width: 360)
    .padding()
    .background(Color.gray.opacity(0.3))
}
