import AppKit
import SwiftUI

@MainActor
struct MessageCardViewDependencies {
    let hoverState: MessagePanelHoverState
    let resolveTags: ([UUID]) -> [CardTag]
    let setRecordType: (UUID, CardRecordType) -> Void
    let pasteImageFromClipboard: (UUID) -> Bool
    let addAttachment: (NSImage, UUID) -> Void
    let generateSummary: (UUID, Bool) -> Void
}

/// 单条消息卡片
/// 支持折叠/展开、复制、删除
struct MessageCardView: View {
    let card: MessageCard
    let activeFilterTagIds: Set<UUID>  // 从外部传入，避免在 TagListView 中观察整个 state
    let dependencies: MessageCardViewDependencies
    var onDelete: (() -> Void)?

    @State private var isHovered = false
    @State private var showCopied = false
    @State private var isExpanded = false
    @State private var isShowingOriginal = false  // 点击展开原文（摘要模式）
    @State private var copyScale: CGFloat = 1.0
    @State private var showTagPopover = false
    @State private var isDropTargeted = false

    /// 超过此行数才触发折叠
    private let collapsedMaxLines = 3
    /// 折叠后实际显示的行数（高度）
    private let collapsedDisplayLines = 3
    /// 每行高度（13pt 字体 + SwiftUI 默认行间距 ≈ 16pt）
    private let lineHeight: CGFloat = 16
    /// 每行大约的字符数（用于估算是否需要折叠）
    private let charsPerLine = 25
}

extension MessageCardView {
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
                dependencies.hoverState.hoveredCardId = card.id
            } else if dependencies.hoverState.hoveredCardId == card.id {
                dependencies.hoverState.hoveredCardId = nil
            }
        }
        .contextMenu {
            // 状态切换菜单（仅 ASR/LLM 卡片显示）
            if card.stage.isTranscriptionResult {
                // Todo 相关操作
                if card.recordType != .todo {
                    Button {
                        dependencies.setRecordType(card.id, .todo)
                    } label: {
                        Label("设为 Todo", systemImage: "circle")
                    }
                }

                // Done 相关操作（仅 Todo 类别显示）
                if card.recordType == .todo {
                    Button {
                        dependencies.setRecordType(card.id, .done)
                    } label: {
                        Label("标记完成", systemImage: "checkmark.circle.fill")
                    }
                }

                // Done → Todo（重新激活）
                if card.recordType == .done {
                    Button {
                        dependencies.setRecordType(card.id, .todo)
                    } label: {
                        Label("重新激活", systemImage: "arrow.uturn.backward.circle")
                    }
                }

                // Note 操作
                if card.recordType != .note {
                    Button {
                        dependencies.setRecordType(card.id, .note)
                    } label: {
                        Label("设为 Note", systemImage: "bookmark")
                    }
                }

                // 取消标记（回到 Normal）
                if card.recordType.isPinned {
                    Divider()
                    Button {
                        dependencies.setRecordType(card.id, .normal)
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
                    _ = dependencies.pasteImageFromClipboard(card.id)
                } label: {
                    Label("粘贴图片", systemImage: "photo.on.rectangle")
                }

                Divider()
            }

            // 总结相关操作（所有卡片都可以）
            if card.summary == nil || card.summary?.isEmpty == true {
                // 没有摘要时显示"总结"
                Button {
                    dependencies.generateSummary(card.id, false)
                } label: {
                    Label("总结", systemImage: "text.quote")
                }
            } else {
                // 有摘要时显示"重新总结"
                Button {
                    dependencies.generateSummary(card.id, true)
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
}

extension MessageCardView {
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
                            dependencies.addAttachment(image, card.id)
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
                            dependencies.addAttachment(image, card.id)
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
            dependencies.addAttachment(image, card.id)
            return true
        }

        return false
    }
}

extension MessageCardView {
    // MARK: - Header

    /// 卡片标题（显示模型名/阶段名，summary 在正文显示）
    private var cardTitle: String {
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
}

extension MessageCardView {
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
            VStack(alignment: .leading, spacing: 2) {
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
                            .lineLimit(nil)  // 禁用省略号，让 mask 处理渐变
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(minHeight: 20, alignment: .topLeading)
                // 折叠时固定高度，用 height 而非 maxHeight 确保 mask 对齐
                .frame(
                    height: needsCollapse && !isExpanded && !shouldShowSummary
                        ? CGFloat(collapsedDisplayLines) * lineHeight
                        : nil,
                    alignment: .topLeading
                )
                .clipped()
                // 折叠时底部渐隐效果：前2.5行完整显示，第3行后半渐变消失
                .mask {
                    if needsCollapse && !isExpanded && !shouldShowSummary {
                        VStack(spacing: 0) {
                            // 前2行 + 第3行的1/2完整显示
                            Rectangle()
                                .frame(height: CGFloat(collapsedDisplayLines) * lineHeight - lineHeight * 0.5)
                            // 第3行后1/2渐变消失
                            LinearGradient(
                                colors: [.white, .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: lineHeight * 0.5)
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
}

extension MessageCardView {
    // MARK: - Tags

    /// 从 TagLibrary 获取卡片标签
    private var cardTags: [CardTag] {
        dependencies.resolveTags(card.tagIds)
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
}

extension MessageCardView {
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
}

extension MessageCardView {
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
}

extension MessageCardView {
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
