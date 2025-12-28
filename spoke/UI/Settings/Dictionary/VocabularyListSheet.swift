import SwiftUI

private typealias DS = DesignTokens

// MARK: - 生词列表 Sheet

struct VocabularyListSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var vocabularyService = VocabularyService.shared
    @State private var searchText = ""
    
    private var filteredItems: [VocabularyItem] {
        if searchText.isEmpty {
            return vocabularyService.items
        }
        return vocabularyService.items.filter {
            $0.word.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("生词本")
                    .font(DS.Typography.title)
                    .foregroundStyle(DS.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: DS.Layout.iconSizeStandard))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(DS.Spacing.xl)
            .background(DS.Colors.settingsBackground)
            
            Divider()
            
            // 搜索框
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "magnifyingglass")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                
                TextField("搜索生词...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.button)
            }
            .padding(DS.Spacing.lg)
            .background(DS.Colors.settingsCardBackground)
            .cornerRadius(DS.CornerRadius.md)
            .padding(DS.Spacing.xl)
            
            // 列表
            if filteredItems.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: DS.Layout.iconSizeXLarge))
                        .foregroundStyle(DS.Colors.textSecondary.opacity(0.5))
                    Text(searchText.isEmpty ? "暂无生词" : "未找到匹配的生词")
                        .font(DS.Typography.button)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredItems) { item in
                            VocabularyItemRow(item: item) {
                                vocabularyService.remove(item.id)
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                }
            }
            
            Divider()
            
            // 底部操作栏
            HStack {
                Text("\(vocabularyService.items.count) 个生词")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                
                Spacer()
                
                if !vocabularyService.items.isEmpty {
                    Button {
                        vocabularyService.clearAll()
                    } label: {
                        Text("清空全部")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.error.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DS.Spacing.xl)
            .background(DS.Colors.settingsBackground)
        }
        .frame(width: 400, height: 500)
        .background(DS.Colors.settingsPanelSecondary)
    }
}

// MARK: - 生词条目行

struct VocabularyItemRow: View {
    let item: VocabularyItem
    let onRemove: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: DS.Spacing.lg) {
            Text(item.word)
                .font(DS.Typography.content)
                .foregroundStyle(DS.Colors.textPrimary)
            
            Spacer()
            
            Text(item.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(DS.Typography.captionSmall)
                .foregroundStyle(DS.Colors.textSecondary.opacity(0.6))
            
            if isHovered {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "trash")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(DS.Colors.error.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.CornerRadius.md)
                .fill(isHovered ? DS.Colors.rowHover : Color.clear)
        )
        .onHover { isHovered = $0 }
    }
}
