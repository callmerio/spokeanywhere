import SwiftUI

private typealias DS = DesignTokens

@MainActor
struct TagBubbleDependencies {
    let updateTagName: (UUID, String) -> Void
    let updateTagColor: (UUID, TagColor) -> Void
    let deleteTag: (UUID) -> Void
    let removeTagFromCard: (UUID, UUID) -> Void
    let toggleTagFilter: (UUID) -> Void
    let recentTags: () -> [CardTag]
    let searchTags: (String) -> [CardTag]
    let tagNamed: (String) -> CardTag?
    let createAndAddTag: (String, UUID) -> Void
    let addTagToCard: (UUID, UUID) -> Void
}

@MainActor
extension TagBubbleDependencies {
    static func makeLive(
        tagLibrary: TagLibrary,
        messagePanelState: MessagePanelState
    ) -> TagBubbleDependencies {
        TagBubbleDependencies(
            updateTagName: { tagLibrary.updateTagName($0, name: $1) },
            updateTagColor: { tagLibrary.updateTagColor($0, color: $1) },
            deleteTag: { tagLibrary.deleteTag($0) },
            removeTagFromCard: { messagePanelState.removeTag($0, from: $1) },
            toggleTagFilter: { messagePanelState.toggleTagFilter($0) },
            recentTags: { tagLibrary.recentTags },
            searchTags: { tagLibrary.search($0) },
            tagNamed: { tagLibrary.tag(named: $0) },
            createAndAddTag: { messagePanelState.createAndAddTag(name: $0, to: $1) },
            addTagToCard: { messagePanelState.addTag($0, to: $1) }
        )
    }

    static let preview = TagBubbleDependencies(
        updateTagName: { _, _ in },
        updateTagColor: { _, _ in },
        deleteTag: { _ in },
        removeTagFromCard: { _, _ in },
        toggleTagFilter: { _ in },
        recentTags: { [] },
        searchTags: { _ in [] },
        tagNamed: { _ in nil },
        createAndAddTag: { _, _ in },
        addTagToCard: { _, _ in }
    )
}

// MARK: - Tag Bubble View

/// 单个标签气泡视图
/// 支持右键菜单：编辑名称、更换颜色、删除
/// 支持点击切换筛选状态
struct TagBubbleView: View {
    let tag: CardTag
    let cardId: UUID?
    private let dependencies: TagBubbleDependencies
    var onRemoveFromCard: (() -> Void)?
    var isFilterActive: Bool = false
    var onFilterToggle: (() -> Void)?
    
    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editingName = ""

    @MainActor
    init(
        tag: CardTag,
        cardId: UUID?,
        onRemoveFromCard: (() -> Void)? = nil,
        isFilterActive: Bool = false,
        onFilterToggle: (() -> Void)? = nil
    ) {
        self.init(
            tag: tag,
            cardId: cardId,
            dependencies: .live,
            onRemoveFromCard: onRemoveFromCard,
            isFilterActive: isFilterActive,
            onFilterToggle: onFilterToggle
        )
    }

    init(
        tag: CardTag,
        cardId: UUID?,
        dependencies: TagBubbleDependencies,
        onRemoveFromCard: (() -> Void)? = nil,
        isFilterActive: Bool = false,
        onFilterToggle: (() -> Void)? = nil
    ) {
        self.tag = tag
        self.cardId = cardId
        self.dependencies = dependencies
        self.onRemoveFromCard = onRemoveFromCard
        self.isFilterActive = isFilterActive
        self.onFilterToggle = onFilterToggle
    }
    
    var body: some View {
        if isEditing {
            editingView
        } else {
            bubbleView
        }
    }
    
    // MARK: - Bubble View
    
    private var bubbleView: some View {
        Button {
            onFilterToggle?()
        } label: {
            Text(tag.name)
                .font(DS.Typography.captionSmall)
                .foregroundColor(tag.color.color)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .background(
                    Capsule()
                        .fill(tag.color.color.opacity(isFilterActive ? 0.4 : (isHovered ? 0.25 : 0.15)))
                )
                .overlay(
                    Capsule()
                        .stroke(
                            tag.color.color.opacity(isFilterActive ? 0.6 : 0.3),
                            lineWidth: isFilterActive ? (DS.BorderWidth.thin + DS.BorderWidth.hairline) : DS.BorderWidth.thin
                        )
                )
                .scaleEffect(isFilterActive ? 1.05 : 1.0)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            // 编辑名称
            Button {
                editingName = tag.name
                isEditing = true
            } label: {
                Label("编辑名称", systemImage: "pencil")
            }
            
            Divider()
            
            // 颜色选择子菜单
            Menu {
                ForEach(TagColor.allCases, id: \.self) { color in
                    Button {
                        dependencies.updateTagColor(tag.id, color)
                    } label: {
                        HStack {
                            Circle()
                                .fill(color.color)
                                .frame(width: 12, height: 12)
                            Text(color.displayName)
                            if tag.color == color {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("更换颜色", systemImage: "paintpalette")
            }
            
            Divider()
            
            // 从卡片移除（如果有 cardId）
            if let cardId = cardId {
                Button {
                    onRemoveFromCard?()
                    dependencies.removeTagFromCard(tag.id, cardId)
                } label: {
                    Label("从卡片移除", systemImage: "minus.circle")
                }
            }
            
            // 删除标签（全局）
            Button(role: .destructive) {
                dependencies.deleteTag(tag.id)
            } label: {
                Label("删除标签", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Editing View
    
    private var editingView: some View {
        HStack(spacing: 4) {
            TextField("", text: $editingName)
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(tag.color.color)
                .frame(minWidth: 40, maxWidth: 120)
                .onSubmit {
                    commitEdit()
                }
            
            Button {
                commitEdit()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(DS.Colors.success)
            }
            .buttonStyle(.plain)
            
            Button {
                isEditing = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(DS.Colors.error)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(tag.color.color.opacity(0.2))
        )
        .overlay(
            Capsule()
                .stroke(tag.color.color.opacity(0.5), lineWidth: 1)
        )
    }
    
    private func commitEdit() {
        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            dependencies.updateTagName(tag.id, trimmed)
        }
        isEditing = false
    }
}

// MARK: - Tag List View

/// 标签列表视图（水平流式布局）
/// 注意：不要在此观察 MessagePanelState，会导致所有卡片同时重绘造成卡顿
struct TagListView: View {
    let tags: [CardTag]
    let cardId: UUID
    private let dependencies: TagBubbleDependencies
    let activeFilterTagIds: Set<UUID>  // 从外部传入，避免观察整个 state
    var onAddTag: (() -> Void)?
    
    @State private var isHoveringAdd = false

    @MainActor
    init(
        tags: [CardTag],
        cardId: UUID,
        activeFilterTagIds: Set<UUID>,
        onAddTag: (() -> Void)? = nil
    ) {
        self.init(
            tags: tags,
            cardId: cardId,
            dependencies: .live,
            activeFilterTagIds: activeFilterTagIds,
            onAddTag: onAddTag
        )
    }

    init(
        tags: [CardTag],
        cardId: UUID,
        dependencies: TagBubbleDependencies,
        activeFilterTagIds: Set<UUID>,
        onAddTag: (() -> Void)? = nil
    ) {
        self.tags = tags
        self.cardId = cardId
        self.dependencies = dependencies
        self.activeFilterTagIds = activeFilterTagIds
        self.onAddTag = onAddTag
    }
    
    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(tags) { tag in
                TagBubbleView(
                    tag: tag,
                    cardId: cardId,
                    dependencies: dependencies,
                    isFilterActive: activeFilterTagIds.contains(tag.id),
                    onFilterToggle: {
                        dependencies.toggleTagFilter(tag.id)
                    }
                )
            }
            
            // 添加标签按钮
            addTagButton
        }
    }
    
    private var addTagButton: some View {
        Button {
            onAddTag?()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(isHoveringAdd ? DS.Colors.textPrimary : DS.Colors.textPlaceholder)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(isHoveringAdd ? DS.Colors.buttonHoverStrong : DS.Colors.chipBackground)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHoveringAdd = hovering
            }
        }
    }
}

// MARK: - Flow Layout

/// 水平流式布局（自动换行）- 使用 cache 避免重复计算
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    // MARK: - Cache 结构
    
    struct CacheData {
        var size: CGSize = .zero
        var frames: [CGRect] = []
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
        
        for (index, frame) in cache.frames.enumerated() where index < subviews.count {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }
    
    /// 仅在必要时更新缓存（proposal 或 subview 数量变化）
    private func updateCacheIfNeeded(proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) {
        // 处理 nil 或 infinity 的情况，使用一个较大的有限值
        let proposalWidth: CGFloat
        if let width = proposal.width, width.isFinite {
            proposalWidth = width
        } else {
            proposalWidth = 10000 // 使用有限的大值代替 infinity
        }
        
        // 检查是否需要重新计算
        guard cache.proposalWidth != proposalWidth || cache.subviewCount != subviews.count else {
            return
        }
        
        // 计算布局
        var frames: [CGRect] = []
        frames.reserveCapacity(subviews.count)
        
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            // 需要换行
            if currentX + size.width > proposalWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
            
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalHeight = currentY + lineHeight
        }
        
        // 更新缓存
        cache.size = CGSize(width: proposalWidth, height: totalHeight)
        cache.frames = frames
        cache.proposalWidth = proposalWidth
        cache.subviewCount = subviews.count
    }
}

// MARK: - Add Tag Popover

/// 添加标签弹窗
struct AddTagPopover: View {
    let cardId: UUID
    private let dependencies: TagBubbleDependencies
    @Binding var isPresented: Bool
    
    @State private var recentTags: [CardTag]
    @State private var searchQuery = ""
    @FocusState private var isInputFocused: Bool

    @MainActor
    init(cardId: UUID, isPresented: Binding<Bool>) {
        self.init(cardId: cardId, dependencies: .live, isPresented: isPresented)
    }

    init(
        cardId: UUID,
        dependencies: TagBubbleDependencies,
        isPresented: Binding<Bool>
    ) {
        self.cardId = cardId
        self.dependencies = dependencies
        self._isPresented = isPresented
        self._recentTags = State(initialValue: dependencies.recentTags())
    }
    
    var body: some View {
        let filteredTags = dependencies.searchTags(searchQuery)
        let matchingTag = dependencies.tagNamed(searchQuery)

        VStack(alignment: .leading, spacing: 12) {
            // 搜索/新建输入框
            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                
                TextField("搜索或新建标签...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isInputFocused)
                    .onSubmit {
                        if !searchQuery.isEmpty {
                            createAndAdd()
                        }
                    }
            }
            .padding(10)
            .background(DS.Colors.chipBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // 最近使用
            if !recentTags.isEmpty && searchQuery.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("最近使用")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    FlowLayout(spacing: 6) {
                        ForEach(recentTags) { tag in
                            TagBubbleButton(tag: tag) {
                                addExistingTag(tag)
                            }
                        }
                    }
                }
            }
            
            // 搜索结果
            if !searchQuery.isEmpty && !filteredTags.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("已有标签")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    FlowLayout(spacing: 6) {
                        ForEach(filteredTags) { tag in
                            TagBubbleButton(tag: tag) {
                                addExistingTag(tag)
                            }
                        }
                    }
                }
            }
            
            // 创建新标签提示
            if !searchQuery.isEmpty && matchingTag == nil {
                Button {
                    createAndAdd()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                        Text("创建「\(searchQuery)」")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(DS.Colors.accentPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 220)
        .onAppear {
            isInputFocused = true
            recentTags = dependencies.recentTags()
        }
    }
    
    private func createAndAdd() {
        dependencies.createAndAddTag(searchQuery, cardId)
        searchQuery = ""
        isPresented = false
    }
    
    private func addExistingTag(_ tag: CardTag) {
        dependencies.addTagToCard(tag.id, cardId)
        isPresented = false
    }
}

// MARK: - Tag Bubble Button

/// 可点击的标签气泡（用于选择）
struct TagBubbleButton: View {
    let tag: CardTag
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text(tag.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(tag.color.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(tag.color.color.opacity(isHovered ? 0.25 : 0.15))
                )
                .overlay(
                    Capsule()
                        .stroke(tag.color.color.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Active Filter Tag Bubble

/// 激活的筛选标签气泡（用于顶部状态栏）
/// 点击移除筛选，带 × 图标
struct ActiveFilterTagBubble: View {
    let tag: CardTag
    let onRemove: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 4) {
                Text(tag.name)
                    .font(.system(size: 10, weight: .medium))
                
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .opacity(isHovered ? 1 : 0.6)
            }
            .foregroundColor(tag.color.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tag.color.color.opacity(isHovered ? 0.35 : 0.25))
            )
            .overlay(
                Capsule()
                    .stroke(tag.color.color.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let previewDependencies = TagBubbleDependencies.preview

    VStack(spacing: 20) {
        // 单个标签
        TagBubbleView(
            tag: CardTag(name: "macOS", color: .blue),
            cardId: nil,
            dependencies: previewDependencies
        )
        
        // 标签列表
        TagListView(
            tags: [
                CardTag(name: "Swift", color: .orange),
                CardTag(name: "macOS", color: .blue),
                CardTag(name: "紧急", color: .red)
            ],
            cardId: UUID(),
            dependencies: previewDependencies,
            activeFilterTagIds: []
        )
        .frame(width: 200)
        
        // 激活的筛选标签
        ActiveFilterTagBubble(tag: CardTag(name: "Swift", color: .orange)) {
            print("Remove filter")
        }
    }
    .padding()
    .background(DS.Colors.settingsBackground)
}
