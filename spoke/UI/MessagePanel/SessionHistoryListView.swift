import AppKit
import SwiftUI

private typealias DS = DesignTokens

// MARK: - History Group View

/// 历史记录分组视图（卡片叠放风格）
/// 折叠时显示最新一条 + 叠放装饰，展开显示全部
struct HistoryGroupView: View {
    let type: SessionRecordType
    let records: [SessionRecord]
    var onRecordTap: ((SessionRecord) -> Void)?
    var onClearType: (() -> Void)?
    var onDeleteRecord: ((UUID) -> Void)?
    
    @State private var isExpanded = false
    
    /// 最新的三条记录（用于叠放效果）
    private var topRecords: [SessionRecord] {
        Array(records.prefix(3))
    }
    
    var body: some View {
        VStack(spacing: DS.BorderWidth.none) {
            if isExpanded {
                // 展开：显示所有记录
                expandedContent
            } else {
                // 折叠：叠放卡片
                stackedCardsView
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.CornerRadius.lg, style: .continuous))
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isExpanded)
    }
    
    // MARK: - Layout Constants
    
    private enum StackLayout {
        static let verticalOffset = DS.Spacing.md
        static let horizontalPadding = DS.Spacing.sm
        static let placeholderHeight = DS.Layout.sessionHistoryPlaceholderHeight
        static let cornerRadius = DS.CornerRadius.xl
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
            .fill(DS.Colors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: StackLayout.cornerRadius, style: .continuous)
                    .strokeBorder(DS.Colors.borderPrimary, lineWidth: DS.BorderWidth.hairline)
            )
            .frame(height: StackLayout.placeholderHeight)
            .padding(.horizontal, CGFloat(layerIndex) * StackLayout.horizontalPadding)
            .offset(y: CGFloat(layerIndex) * StackLayout.verticalOffset)
    }
    
    // MARK: - Expanded Content（展开状态）
    
    private var expandedContent: some View {
        VStack(spacing: DS.Spacing.md) {
            // 分类标题 + 收起按钮（通知中心风格）
            HStack(alignment: .center, spacing: DS.Spacing.lg) {
                // Chat 分类标题（和 Pipeline 对齐）
                Text(type.displayTitle)
                    .font(DS.Typography.titleLarge)
                    .foregroundStyle(DS.Colors.textPrimary)
                
                Spacer()
                
                // 收起按钮（hover 效果）
                HoverTextIconButton(text: "收起", systemImage: "chevron.up") {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        isExpanded = false
                    }
                }
                
                // × 按钮（hover 效果）
                HoverCloseButton(action: { onClearType?() }, size: DS.Layout.iconSizeLarge, iconSize: DS.Typography.fontSizeTimestamp)
            }
            .padding(.horizontal, DS.Spacing.xs)  // 和 Pipeline 对齐
            .padding(.vertical, DS.Spacing.md)
            
            // 所有记录
            ForEach(records) { record in
                HistoryRecordCard(
                    record: record,
                    style: .normal,
                    onTap: { onRecordTap?(record) },
                    onDelete: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            onDeleteRecord?(record.id)
                        }
                    }
                )
            }
        }
        .padding(.bottom, DS.Spacing.md)
    }
}

// MARK: - Card Style

enum HistoryCardStyle {
    case normal
    case prominent
}

// MARK: - History Record Card

/// 单条历史记录卡片（HUD 风格：毛玻璃 + 白色细边框）
/// 点击即复制内容到剪贴板，hover 显示删除按钮
struct HistoryRecordCard: View {
    let record: SessionRecord
    var style: HistoryCardStyle = .normal
    var onTap: (() -> Void)?
    var onDelete: (() -> Void)?
    
    @State private var isHovered = false
    @State private var showCopied = false
    
    var body: some View {
        Button {
            copyContent()
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // 头部行：标题 + 时间
                HStack(alignment: .center, spacing: DS.Spacing.md) {
                    Text(record.title)
                        .font((style == .prominent ? DS.Typography.content : DS.Typography.button).weight(.semibold))
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: DS.Spacing.md)

                    Text(record.detailedTime)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(DS.Colors.textPlaceholder)

                    if onDelete != nil {
                        DS.Colors.clear.frame(width: DS.Layout.iconSizeStandard, height: DS.Layout.iconSizeStandard)
                    }
                }

                // 预览文本（独立一行，固定占位3行高度）
                Text(record.preview)
                    .font(DS.Typography.button)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(3)
                    .frame(height: DS.Layout.toolbarHeight + DS.Spacing.lg + DS.Spacing.xxs, alignment: .topLeading) // 3行 * 18pt/行 = 54pt
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DS.Spacing.lg + DS.Spacing.xxs)
        .padding(.vertical, DS.Spacing.lg)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.CornerRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.CornerRadius.xl, style: .continuous)
                .strokeBorder(isHovered ? DS.Colors.borderSecondary : DS.Colors.borderPrimary, lineWidth: DS.BorderWidth.hairline)
        )
        .overlay(alignment: .topTrailing) {
            if onDelete != nil {
                Button(action: { onDelete?() }, label: {
                    Image(systemName: "xmark")
                        .font(DS.Typography.timestamp.weight(.medium))
                        .foregroundStyle(DS.Colors.textPlaceholder)
                        .frame(width: DS.Layout.iconSizeStandard, height: DS.Layout.iconSizeStandard)
                        .background(DS.Colors.chipBackground)
                        .clipShape(Circle())
                })
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
                .animation(.easeInOut(duration: 0.12), value: isHovered)
                .padding(.top, DS.Spacing.lg)
                .padding(.trailing, DS.Spacing.lg + DS.Spacing.xxs)
            }
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
            VisualEffectBlur(material: .hudWindow, cornerRadius: DS.CornerRadius.xl)
            
            // 深色叠加 (复制时短暂变亮)
            showCopied ? DS.Colors.buttonHoverStrong : (isHovered ? DS.Colors.overlayDark : DS.Colors.overlayLight)
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
        runSessionHistoryCopyFeedback {
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
        SessionRecord(type: .transcription, title: "测试转录", preview: "这是一段转录文本")
    ]
    
    return VStack(spacing: DS.Spacing.lg) {
        HistoryGroupView(
            type: .conversation,
            records: testRecords.filter { $0.type == .conversation },
            onDeleteRecord: { _ in }
        )
        HistoryGroupView(
            type: .transcription,
            records: testRecords.filter { $0.type == .transcription },
            onDeleteRecord: { _ in }
        )
    }
    .frame(width: DS.Layout.sessionHistoryPreviewWidth)
    .padding(DS.Spacing.md)
    .background(DS.Colors.overlayDark)
}
