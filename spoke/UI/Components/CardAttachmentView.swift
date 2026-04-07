import AppKit
import SwiftUI

@MainActor
struct CardAttachmentViewDependencies {
    let imageCache: AttachmentImageCache
    let removeAttachment: (UUID, UUID) -> Void
    let copyImage: (NSImage) -> Void
    let saveImageToDesktop: (NSImage, UUID) -> Void
}

// MARK: - Card Attachment View

/// 卡片附件视图
/// 采用流式布局，尽可能多地显示图片
/// 折叠状态：一行内排列 + 右下角数量提示
/// 展开状态：多行流式布局
struct CardAttachmentView: View {
    let attachments: [CardAttachment]
    let cardId: UUID
    let isExpanded: Bool
    private let dependencies: CardAttachmentViewDependencies
    
    /// 缩略图固定高度
    private let thumbnailHeight: CGFloat = 60
    /// 图片间距
    private let spacing: CGFloat = 6
    /// 可用宽度（卡片宽度 - padding）
    private let availableWidth: CGFloat = MessagePanelState.panelWidth - 28 - 16  // padding + 边距

    init(
        attachments: [CardAttachment],
        cardId: UUID,
        isExpanded: Bool,
        dependencies: CardAttachmentViewDependencies
    ) {
        self.attachments = attachments
        self.cardId = cardId
        self.isExpanded = isExpanded
        self.dependencies = dependencies
    }

    @MainActor
    init(
        attachments: [CardAttachment],
        cardId: UUID,
        isExpanded: Bool
    ) {
        self.init(
            attachments: attachments,
            cardId: cardId,
            isExpanded: isExpanded,
            dependencies: .live
        )
    }
    
    var body: some View {
        if attachments.isEmpty {
            EmptyView()
        } else if isExpanded {
            expandedView
        } else {
            collapsedView
        }
    }
    
    // MARK: - Collapsed View
    
    /// 折叠状态：一行内尽可能多地显示图片
    private var collapsedView: some View {
        let (visibleAttachments, remaining) = calculateVisibleAttachments(maxRows: 1)
        
        return ZStack(alignment: .bottomTrailing) {
            HStack(spacing: spacing) {
                ForEach(visibleAttachments) { attachment in
                    CardAttachmentThumbnail(
                        attachment: attachment,
                        cardId: cardId,
                        fixedHeight: thumbnailHeight,
                        dependencies: dependencies
                    )
                }
                Spacer(minLength: 0)
            }
            
            // 右下角数量提示
            if remaining > 0 {
                Text("+\(remaining)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.6))
                    )
                    .padding(4)
            }
        }
    }
    
    // MARK: - Expanded View
    
    /// 展开状态：多行流式布局
    private var expandedView: some View {
        AttachmentFlowLayout(spacing: spacing) {
            ForEach(attachments) { attachment in
                CardAttachmentThumbnail(
                    attachment: attachment,
                    cardId: cardId,
                    fixedHeight: thumbnailHeight,
                    showDeleteButton: true,
                    dependencies: dependencies
                )
            }
        }
    }
    
    // MARK: - Layout Calculation
    
    /// 计算一行内能显示多少张图片
    private func calculateVisibleAttachments(maxRows: Int) -> (visible: [CardAttachment], remaining: Int) {
        var visible: [CardAttachment] = []
        var currentRowWidth: CGFloat = 0
        var rows = 1
        
        // 预留 +N 标签的空间
        let reservedWidth: CGFloat = 50
        let effectiveWidth = availableWidth - reservedWidth
        
        for attachment in attachments {
            let width = thumbnailHeight * attachment.aspectRatio
            
            if currentRowWidth + width + (visible.isEmpty ? 0 : spacing) <= effectiveWidth {
                visible.append(attachment)
                currentRowWidth += width + (visible.count > 1 ? spacing : 0)
            } else if rows < maxRows {
                rows += 1
                currentRowWidth = width
                visible.append(attachment)
            } else {
                break
            }
        }
        
        return (visible, attachments.count - visible.count)
    }
}

// MARK: - Attachment Flow Layout

/// 附件流式布局（类似 FlowLayout，但针对固定高度图片优化）- 使用 cache 避免重复计算
struct AttachmentFlowLayout: Layout {
    let spacing: CGFloat
    
    // MARK: - Cache 结构
    
    struct CacheData {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        var proposalWidth: CGFloat = 0
        var subviewCount: Int = 0
    }
    
    func makeCache(subviews: Subviews) -> CacheData {
        CacheData()
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) -> CGSize {
        updateCacheIfNeeded(proposal: proposal, subviews: subviews, cache: &cache)
        return cache.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) {
        updateCacheIfNeeded(proposal: proposal, subviews: subviews, cache: &cache)
        
        for (index, position) in cache.positions.enumerated() where index < subviews.count {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }
    
    /// 仅在必要时更新缓存
    private func updateCacheIfNeeded(proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) {
        // 处理 nil 或 infinity 的情况，使用一个较大的有限值
        let proposalWidth: CGFloat
        if let width = proposal.width, width.isFinite {
            proposalWidth = width
        } else {
            proposalWidth = 10000
        }
        
        guard cache.proposalWidth != proposalWidth || cache.subviewCount != subviews.count else {
            return
        }
        
        var positions: [CGPoint] = []
        positions.reserveCapacity(subviews.count)
        
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > proposalWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            totalWidth = max(totalWidth, currentX - spacing)
        }
        
        cache.size = CGSize(width: totalWidth, height: currentY + rowHeight)
        cache.positions = positions
        cache.proposalWidth = proposalWidth
        cache.subviewCount = subviews.count
    }
}

// MARK: - Attachment Thumbnail

/// 单个卡片附件缩略图
struct CardAttachmentThumbnail: View {
    let attachment: CardAttachment
    let cardId: UUID
    /// 固定高度模式（用于流式布局）
    var fixedHeight: CGFloat?
    /// 最大宽度模式（传统模式）
    var maxWidth: CGFloat = 120
    var showDeleteButton: Bool = false
    private let dependencies: CardAttachmentViewDependencies
    
    @State private var thumbnail: NSImage?
    @State private var isHovered = false
    @State private var showFullImage = false

    init(
        attachment: CardAttachment,
        cardId: UUID,
        fixedHeight: CGFloat? = nil,
        maxWidth: CGFloat = 120,
        showDeleteButton: Bool = false,
        dependencies: CardAttachmentViewDependencies
    ) {
        self.attachment = attachment
        self.cardId = cardId
        self.fixedHeight = fixedHeight
        self.maxWidth = maxWidth
        self.showDeleteButton = showDeleteButton
        self.dependencies = dependencies
    }

    /// 计算显示尺寸
    private var displaySize: CGSize {
        let ratio = attachment.aspectRatio
        
        if let height = fixedHeight {
            // 固定高度模式：根据高度和宽高比计算宽度
            let width = height * ratio
            return CGSize(width: width, height: height)
        } else {
            // 最大宽度模式
            let width = min(maxWidth, attachment.originalWidth)
            let height = width / ratio
            return CGSize(width: width, height: height)
        }
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 缩略图
            Group {
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: displaySize.width, height: displaySize.height)
                        .clipped()
                } else {
                    // 占位
                    Rectangle()
                        .fill(DesignTokens.Colors.cardBackground)
                        .frame(width: displaySize.width, height: displaySize.height)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.6)
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(DesignTokens.Colors.borderPrimary, lineWidth: DesignTokens.BorderWidth.thin)
            )
            .onTapGesture {
                showFullImage = true
            }
            
            // 删除按钮（hover 时显示）
            if showDeleteButton && isHovered {
                Button {
                    dependencies.removeAttachment(attachment.id, cardId)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                }
                .buttonStyle(.plain)
                .padding(4)
                .transition(.opacity)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onAppear {
            loadThumbnail()
        }
        .contextMenu {
            Button {
                showFullImage = true
            } label: {
                Label("查看原图", systemImage: "eye")
            }
            
            Button {
                copyToClipboard()
            } label: {
                Label("复制图片", systemImage: "doc.on.doc")
            }
            
            Button {
                saveToDesktop()
            } label: {
                Label("保存到桌面", systemImage: "square.and.arrow.down")
            }
            
            Divider()
            
            Button(role: .destructive) {
                dependencies.removeAttachment(attachment.id, cardId)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .popover(isPresented: $showFullImage, arrowEdge: .trailing) {
            FullImagePopover(
                attachment: attachment,
                isPresented: $showFullImage,
                dependencies: dependencies
            )
        }
    }
    
    private func loadThumbnail() {
        runCardAttachmentThumbnailLoad(
            attachment: attachment,
            maxWidth: maxWidth,
            dependencies: dependencies
        ) { image in
            self.thumbnail = image
        }
    }
    
    private func copyToClipboard() {
        guard let image = dependencies.imageCache.original(for: attachment) else { return }
        dependencies.copyImage(image)
    }
    
    private func saveToDesktop() {
        guard let image = dependencies.imageCache.original(for: attachment) else { return }
        dependencies.saveImageToDesktop(image, attachment.id)
    }
}

// MARK: - Full Image Popover

/// 查看原图弹窗（Popover 样式，不影响 Pipeline 位置）
struct FullImagePopover: View {
    let attachment: CardAttachment
    @Binding var isPresented: Bool
    private let dependencies: CardAttachmentViewDependencies
    @State private var image: NSImage?

    init(
        attachment: CardAttachment,
        isPresented: Binding<Bool>,
        dependencies: CardAttachmentViewDependencies
    ) {
        self.attachment = attachment
        self._isPresented = isPresented
        self.dependencies = dependencies
    }

    /// 计算合适的显示尺寸
    private var displaySize: CGSize {
        let maxWidth: CGFloat = 400
        let maxHeight: CGFloat = 350
        let ratio = attachment.aspectRatio
        
        if ratio > 1 {
            // 横向图
            let width = min(maxWidth, attachment.originalWidth)
            return CGSize(width: width, height: width / ratio)
        } else {
            // 纵向图
            let height = min(maxHeight, attachment.originalHeight)
            return CGSize(width: height * ratio, height: height)
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // 图片
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: displaySize.width, height: displaySize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                ProgressView()
                    .frame(width: 200, height: 150)
            }
            
            // 操作按钮
            HStack(spacing: 12) {
                Button {
                    copyToClipboard()
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Button {
                    saveToDesktop()
                } label: {
                    Label("保存", systemImage: "square.and.arrow.down")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button {
                    isPresented = false
                } label: {
                    Text("关闭")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .onAppear {
            image = dependencies.imageCache.original(for: attachment)
        }
    }
    
    private func copyToClipboard() {
        guard let image = image else { return }
        dependencies.copyImage(image)
    }
    
    private func saveToDesktop() {
        guard let image = image else { return }
        dependencies.saveImageToDesktop(image, attachment.id)
    }
}

// MARK: - Drop Zone Overlay

/// 卡片拖拽区域提示覆盖层
struct CardDropOverlay: View {
    let isTargeted: Bool
    
    var body: some View {
        if isTargeted {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.accentColor.opacity(0.1))
                )
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 24))
                        Text("松开添加图片")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                )
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // 模拟附件
        let mockAttachment = CardAttachment(
            fileName: "test.png",
            originalWidth: 800,
            originalHeight: 600
        )
        
        // 折叠状态
        CardAttachmentView(
            attachments: [mockAttachment, mockAttachment],
            cardId: UUID(),
            isExpanded: false
        )
        
        // 展开状态
        CardAttachmentView(
            attachments: [mockAttachment],
            cardId: UUID(),
            isExpanded: true
        )
    }
    .padding()
    .background(Color.black)
}
