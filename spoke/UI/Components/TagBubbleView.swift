import SwiftUI

// MARK: - Tag Bubble View

/// 单个标签气泡视图
/// 支持右键菜单：编辑名称、更换颜色、删除
/// 支持点击切换筛选状态
struct TagBubbleView: View {
    let tag: CardTag
    let cardId: UUID?
    var onRemoveFromCard: (() -> Void)?
    var isFilterActive: Bool = false
    var onFilterToggle: (() -> Void)?
    
    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editingName = ""
    
    var body: some View {
        if isEditing {
            editingView
        } else {
            bubbleView
        }
    }
    
    // MARK: - Bubble View
    
    private var bubbleView: some View {
        Text(tag.name)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(tag.color.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tag.color.color.opacity(isFilterActive ? 0.4 : (isHovered ? 0.25 : 0.15)))
            )
            .overlay(
                Capsule()
                    .stroke(tag.color.color.opacity(isFilterActive ? 0.6 : 0.3), lineWidth: isFilterActive ? 1.5 : 1)
            )
            .scaleEffect(isFilterActive ? 1.05 : 1.0)
            .contentShape(Capsule())
            .onTapGesture {
                onFilterToggle?()
            }
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
                            TagLibrary.shared.updateTagColor(tag.id, color: color)
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
                        MessagePanelState.shared.removeTag(tag.id, from: cardId)
                    } label: {
                        Label("从卡片移除", systemImage: "minus.circle")
                    }
                }
                
                // 删除标签（全局）
                Button(role: .destructive) {
                    TagLibrary.shared.deleteTag(tag.id)
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
                    .foregroundColor(.green)
            }
            .buttonStyle(.plain)
            
            Button {
                isEditing = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.red)
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
            TagLibrary.shared.updateTagName(tag.id, name: trimmed)
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
    let activeFilterTagIds: Set<UUID>  // 从外部传入，避免观察整个 state
    var onAddTag: (() -> Void)?
    
    @State private var isHoveringAdd = false
    
    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(tags) { tag in
                TagBubbleView(
                    tag: tag,
                    cardId: cardId,
                    isFilterActive: activeFilterTagIds.contains(tag.id),
                    onFilterToggle: {
                        MessagePanelState.shared.toggleTagFilter(tag.id)
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
                .foregroundColor(Color.white.opacity(isHoveringAdd ? 0.8 : 0.4))
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(Color.white.opacity(isHoveringAdd ? 0.15 : 0.08))
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
    @Binding var isPresented: Bool
    
    @ObservedObject private var tagLibrary = TagLibrary.shared
    @State private var newTagName = ""
    @State private var searchQuery = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
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
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // 最近使用
            if !tagLibrary.recentTags.isEmpty && searchQuery.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("最近使用")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    FlowLayout(spacing: 6) {
                        ForEach(tagLibrary.recentTags) { tag in
                            TagBubbleButton(tag: tag) {
                                addExistingTag(tag)
                            }
                        }
                    }
                }
            }
            
            // 搜索结果
            let filteredTags = tagLibrary.search(searchQuery)
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
            if !searchQuery.isEmpty && tagLibrary.tag(named: searchQuery) == nil {
                Button {
                    createAndAdd()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                        Text("创建「\(searchQuery)」")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 220)
        .onAppear {
            isInputFocused = true
        }
    }
    
    private func createAndAdd() {
        MessagePanelState.shared.createAndAddTag(name: searchQuery, to: cardId)
        searchQuery = ""
        isPresented = false
    }
    
    private func addExistingTag(_ tag: CardTag) {
        MessagePanelState.shared.addTag(tag.id, to: cardId)
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
    VStack(spacing: 20) {
        // 单个标签
        TagBubbleView(
            tag: CardTag(name: "macOS", color: .blue),
            cardId: nil
        )
        
        // 标签列表
        TagListView(
            tags: [
                CardTag(name: "Swift", color: .orange),
                CardTag(name: "macOS", color: .blue),
                CardTag(name: "紧急", color: .red)
            ],
            cardId: UUID(),
            activeFilterTagIds: []
        )
        .frame(width: 200)
        
        // 激活的筛选标签
        ActiveFilterTagBubble(tag: CardTag(name: "Swift", color: .orange)) {
            print("Remove filter")
        }
    }
    .padding()
    .background(Color.black)
}
