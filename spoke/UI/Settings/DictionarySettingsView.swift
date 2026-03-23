import SwiftUI

private typealias DS = DesignTokens

@MainActor
struct DictionarySettingsDependencies {
    let dictionaryService: DictionaryService
    let transcriptionManager: TranscriptionManager
    let vocabularyService: VocabularyService
}

// MARK: - Dictionary Settings Content

/// 词典设置页面
/// 参考设计：橙色主题、卡片式列表、Tab 筛选
struct DictionarySettingsContent: View {
    @ObservedObject private var dictionaryService: DictionaryService
    @ObservedObject private var vocabularyService: VocabularyService
    private let dependencies: DictionarySettingsDependencies
    
    @State private var selectedFilter: DictionaryFilter = .all
    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var showBatchImportSheet = false
    @State private var editingEntry: DictionaryEntry?
    @State private var selectedEntries: Set<UUID> = []
    
    @State private var showVocabularyList = false

    @MainActor
    init() {
        self.init(dependencies: .live)
    }

    @MainActor
    init(dependencies: DictionarySettingsDependencies) {
        self.dependencies = dependencies
        self._dictionaryService = ObservedObject(wrappedValue: dependencies.dictionaryService)
        self._vocabularyService = ObservedObject(wrappedValue: dependencies.vocabularyService)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            // 标题和描述
            headerSection
            
            // 生词列表入口
            vocabularyListEntry
            
            // 筛选标签和搜索
            filterAndSearchSection
            
            // 词典列表
            dictionaryListSection
            
            // 待确认热词推荐（如果有）
            if !dictionaryService.recommendedHotwords.isEmpty && selectedFilter != .manual {
                hotwordRecommendationSection
            }
        }
        .sheet(isPresented: $showVocabularyList) {
            VocabularyListSheet(isPresented: $showVocabularyList)
        }
        .sheet(isPresented: $showAddSheet) {
            AddDictionaryEntrySheet(isPresented: $showAddSheet)
        }
        .sheet(isPresented: $showBatchImportSheet) {
            BatchImportSheet(isPresented: $showBatchImportSheet)
        }
        .sheet(item: $editingEntry) { entry in
            EditDictionaryEntrySheet(entry: entry, isPresented: Binding(
                get: { editingEntry != nil },
                set: { if !$0 { editingEntry = nil } }
            ))
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("词典")
                        .font(DS.Typography.titleLarge)
                        .foregroundStyle(DS.Colors.textPrimary)
                    
                    Text("手动维护热词词典，确保专有名词在转写与润色时始终准确输出。")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                
                Spacer()
                
                // 新增热词按钮
            Menu {
                Button {
                    showAddSheet = true
                } label: {
                    Label("添加单个词条", systemImage: "plus")
                }
                Button {
                    showBatchImportSheet = true
                } label: {
                    Label("批量导入", systemImage: "doc.text")
                }
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "plus")
                        .font(.system(size: DS.Typography.fontSizeCaption, weight: .semibold))
                    Text("新增热词")
                        .font(.system(size: DS.Typography.fontSizeButton, weight: .semibold))
                }
                .foregroundStyle(DS.Colors.textPrimary)
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.lg)
                .background(
                    DS.Gradients.ctaWarm
                )
                .cornerRadius(DS.CornerRadius.md)
            }
            .buttonStyle(.plain)
            }
            
            // 词典设置开关
            dictionarySettingsRow
        }
        .padding(.bottom, DS.Spacing.xs)
    }
    
    private var dictionarySettingsRow: some View {
        VStack(spacing: DS.Spacing.lg) {
            // 第一行：开关和状态
            HStack(spacing: DS.Spacing.xl) {
                // 词典注入开关
                HStack(spacing: DS.Spacing.md) {
                    Toggle("词典注入", isOn: Binding(
                        get: { dependencies.transcriptionManager.isDictionaryInjectionEnabled },
                        set: { newValue in
                            dependencies.transcriptionManager.isDictionaryInjectionEnabled = newValue
                            if newValue {
                                // 开启时重新准备词典
                                runDictionarySettingsAsync {
                                    await dependencies.transcriptionManager.prepareDictionary()
                                }
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .tint(DS.Colors.warning)
                    
                    Image(systemName: "questionmark.circle")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .help("启用后，词典会在转录阶段生效，提高专有名词识别准确率")
                }
                
                Divider()
                    .frame(height: DS.Spacing.xl)
                
                // 热词学习开关
                HStack(spacing: DS.Spacing.md) {
                    Toggle("热词学习", isOn: Binding(
                        get: { UserDefaults.standard.isHotwordLearningEnabled },
                        set: { UserDefaults.standard.isHotwordLearningEnabled = $0 }
                    ))
                    .toggleStyle(.switch)
                    .tint(DS.Colors.accentPrimary)
                    
                    Image(systemName: "questionmark.circle")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .help("启用后，自动分析转录内容，推荐高频专有名词")
                }
                
                Spacer()
                
                // 词典状态
                dictionaryStatusBadge
            }
            
            // 第二行：权重选择（只在词典注入开启时显示）
            if dependencies.transcriptionManager.isDictionaryInjectionEnabled {
                HStack(spacing: DS.Spacing.lg) {
                    Text("识别强度")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                    
                    // Apple HIG: Segmented Control 适合 2-5 个互斥选项
                    Picker("", selection: Binding(
                        get: { UserDefaults.standard.dictionaryWeightLevel },
                        set: { newValue in
                            UserDefaults.standard.dictionaryWeightLevel = newValue
                            // 权重变化需要重新准备词典
                            runDictionarySettingsAsync {
                                await dependencies.transcriptionManager.prepareDictionary()
                            }
                        }
                    )) {
                        ForEach(DictionaryWeightLevel.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                    
                    // 当前级别说明
                    Text(UserDefaults.standard.dictionaryWeightLevel.description)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(DS.Colors.textSecondary.opacity(0.8))
                    
                    Spacer()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.textSecondary)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.lg)
        .background(DS.Colors.settingsCardBorder.opacity(0.5))
        .cornerRadius(DS.CornerRadius.md)
        .animation(DS.Animation.normal, value: dependencies.transcriptionManager.isDictionaryInjectionEnabled)
    }
    
    private var dictionaryStatusBadge: some View {
        HStack(spacing: DS.Spacing.sm) {
            Circle()
                .fill(dependencies.transcriptionManager.isDictionaryPrepared ? DS.Colors.success : DS.Colors.warning)
                .frame(width: DS.Spacing.sm, height: DS.Spacing.sm)
            
            Text(dependencies.transcriptionManager.isDictionaryPrepared ? "已就绪" : "待准备")
                .font(DS.Typography.captionSmall)
                .foregroundStyle(DS.Colors.textSecondary)
        }
    }
    
    // MARK: - Filter and Search Section
    
    private var filterAndSearchSection: some View {
        HStack(spacing: DS.Spacing.lg) {
            // 筛选标签
            HStack(spacing: DS.Spacing.md) {
                ForEach(DictionaryFilter.allCases, id: \.self) { filter in
                    FilterButton(
                        title: filter.displayName,
                        icon: filter.icon,
                        isSelected: selectedFilter == filter,
                        action: { selectedFilter = filter }
                    )
                }
            }
            
            Spacer()
            
            // 搜索框
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DS.Colors.textSecondary)
                    .font(DS.Typography.caption)
                
                TextField("搜索词条...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.button)
                    .foregroundStyle(DS.Colors.textPrimary)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DS.Colors.textSecondary)
                            .font(DS.Typography.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Colors.settingsCardBackground)
            .cornerRadius(DS.CornerRadius.md)
            .frame(width: 200)
        }
    }
    
    // MARK: - Dictionary List Section
    
    private var dictionaryListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 说明卡片
            introCard
            
            // 词条列表
            if filteredEntries.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredEntries) { entry in
                            DictionaryEntryRow(
                                entry: entry,
                                isSelected: selectedEntries.contains(entry.id),
                                onEdit: { editingEntry = entry },
                                onDelete: { dictionaryService.deleteEntry(entry) },
                                onToggleSelect: {
                                    if selectedEntries.contains(entry.id) {
                                        selectedEntries.remove(entry.id)
                                    } else {
                                        selectedEntries.insert(entry.id)
                                    }
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 400)
            }
            
            // 批量操作栏
            if !selectedEntries.isEmpty {
                batchActionsBar
            }
        }
    }
    
    // MARK: - Intro Card (说明卡片)
    
    private var introCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("让小凹记住你的表达")
                .font(.system(size: DS.Typography.fontSizeContent, weight: .semibold))
                .foregroundStyle(DS.Colors.textPrimary)
            
            Text("小凹会自动学习你常用的术语，也支持手动维护。添加行业词汇、公司名称或口头表达，让润色与注入更符合你的习惯。")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textSecondary)
                .lineLimit(2)
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.CornerRadius.lg)
                .fill(DS.Colors.warning.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.CornerRadius.lg)
                        .stroke(DS.Colors.warning.opacity(0.2), lineWidth: DS.BorderWidth.thin)
                )
        )
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "book.closed")
                .font(.system(size: DS.Layout.iconSizeXLarge))
                .foregroundStyle(DS.Colors.textSecondary.opacity(0.5))
            
            Text("暂无词条")
                .font(.system(size: DS.Typography.fontSizeContent, weight: .medium))
                .foregroundStyle(DS.Colors.textSecondary)
            
            Text("点击「新增热词」添加你的专属词汇")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textSecondary.opacity(0.7))
            
            Button {
                showAddSheet = true
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "plus")
                    Text("添加第一个词条")
                }
                .font(DS.Typography.button)
                .foregroundStyle(DS.Colors.warning)
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.md)
                .background(DS.Colors.warning.opacity(0.1))
                .cornerRadius(DS.CornerRadius.md)
            }
            .buttonStyle(.plain)
            .padding(.top, DS.Spacing.md)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xxxl)
    }
    
    // MARK: - Batch Actions Bar
    
    private var batchActionsBar: some View {
        HStack {
            Text("\(selectedEntries.count) 个已选择")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textSecondary)
            
            Spacer()
            
            Button {
                selectedEntries.removeAll()
            } label: {
                Text("取消选择")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.accentPrimary)
            }
            .buttonStyle(.plain)
            
            Button {
                dictionaryService.deleteEntries(selectedEntries)
                selectedEntries.removeAll()
            } label: {
                Text("删除选中")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.error)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.lg)
        .background(DS.Colors.settingsCardBorder.opacity(0.5))
        .cornerRadius(DS.CornerRadius.md)
    }
    
    // MARK: - Hotword Recommendation Section
    
    private var hotwordRecommendationSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(DS.Colors.warning)
                Text("热词推荐")
                    .font(DS.Typography.caption.weight(.medium))
                    .foregroundStyle(DS.Colors.textSecondary)
                
                Text("(\(dictionaryService.recommendedHotwords.count))")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(DS.Colors.textSecondary.opacity(0.7))
            }
            .padding(.leading, DS.Spacing.xs)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.md) {
                    ForEach(dictionaryService.recommendedHotwords) { hotword in
                        HotwordChip(
                            hotword: hotword,
                            onConfirm: { corrected in
                                dictionaryService.confirmHotword(hotword, correctedWord: corrected)
                            },
                            onDismiss: {
                                dictionaryService.dismissHotword(hotword)
                            }
                        )
                    }
                }
            }
        }
        .padding(DS.Spacing.xl)
        .background(DS.Colors.settingsCardBackground)
        .cornerRadius(DS.CornerRadius.lg)
    }
    
    // MARK: - Computed Properties
    
    private var filteredEntries: [DictionaryEntry] {
        var result = dictionaryService.entries
        
        // 按来源筛选
        switch selectedFilter {
        case .all:
            break
        case .auto:
            result = result.filter { $0.source == .auto }
        case .manual:
            result = result.filter { $0.source == .manual }
        }
        
        // 搜索筛选
        if !searchText.isEmpty {
            result = dictionaryService.search(searchText)
                .filter { entry in
                    switch selectedFilter {
                    case .all: return true
                    case .auto: return entry.source == .auto
                    case .manual: return entry.source == .manual
                    }
                }
        }
        
        return result
    }
}

// MARK: - Dictionary Filter

enum DictionaryFilter: CaseIterable {
    case all
    case auto
    case manual
    
    var displayName: String {
        switch self {
        case .all: return "所有"
        case .auto: return "自动添加"
        case .manual: return "手动添加"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "line.3.horizontal.decrease"
        case .auto: return "sparkles"
        case .manual: return "pencil"
        }
    }
}

// MARK: - Filter Button

struct FilterButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: DS.Layout.iconSizeSmall))
                Text(title)
                    .font(DS.Typography.caption)
            }
            .foregroundStyle(isSelected ? DS.Colors.warning : DS.Colors.textSecondary)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .background(isSelected ? DS.Colors.warning.opacity(0.15) : DS.Colors.rowHover)
            .cornerRadius(DS.CornerRadius.xl)
            .overlay(
                RoundedRectangle(cornerRadius: DS.CornerRadius.xl)
                    .stroke(isSelected ? DS.Colors.warning.opacity(0.3) : Color.clear, lineWidth: DS.BorderWidth.thin)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dictionary Entry Row

struct DictionaryEntryRow: View {
    let entry: DictionaryEntry
    let isSelected: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: DS.Spacing.lg) {
            // 来源图标
            Image(systemName: entry.source.icon)
                .font(DS.Typography.caption)
                .foregroundStyle(entry.source == .auto ? DS.Colors.warning : DS.Colors.accentPrimary)
                .frame(width: DS.Layout.iconSizeStandard)
            
            // 词条内容
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.word)
                    .font(.system(size: DS.Typography.fontSizeContent, weight: .medium))
                    .foregroundStyle(DS.Colors.textPrimary)
                
                if !entry.corrections.isEmpty {
                    Text("纠错: " + entry.corrections.joined(separator: ", "))
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // 频率标签
            if entry.frequency > 0 {
                Text("\(entry.frequency)次")
                    .font(DS.Typography.timestamp)
                    .foregroundStyle(DS.Colors.textSecondary.opacity(0.7))
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(DS.Colors.settingsCardBackground)
                    .cornerRadius(DS.CornerRadius.xs)
            }
            
            // 操作按钮（悬浮显示）
            if isHovered {
                HStack(spacing: DS.Spacing.md) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.error.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity)
            }
            
            // 箭头
            Image(systemName: "chevron.right")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textSecondary.opacity(0.5))
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.CornerRadius.md)
                .fill(isHovered ? DS.Colors.rowHover : DS.Colors.settingsCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.CornerRadius.md)
                .stroke(DS.Colors.settingsCardBorder, lineWidth: DS.BorderWidth.thin)
        )
        .onHover { hovering in
            withAnimation(DS.Animation.fast) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onEdit()
        }
    }
}

// MARK: - Hotword Chip

struct HotwordChip: View {
    let hotword: DictionaryEntry
    let onConfirm: (String?) -> Void
    let onDismiss: () -> Void
    
    @State private var showEditPopover = false
    @State private var correctedWord = ""
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Text(hotword.word)
                .font(DS.Typography.button)
                .foregroundStyle(DS.Colors.textPrimary)
            
            Text("×\(hotword.frequency)")
                .font(DS.Typography.timestamp)
                .foregroundStyle(DS.Colors.warning)
            
            // 确认按钮
            Button {
                showEditPopover = true
                correctedWord = hotword.word
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: DS.Typography.fontSizeTimestamp, weight: .bold))
                    .foregroundStyle(DS.Colors.success)
            }
            .buttonStyle(.plain)
            
            // 忽略按钮
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: DS.Typography.fontSizeTimestamp, weight: .bold))
                    .foregroundStyle(DS.Colors.error.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Colors.chipBackground)
        .cornerRadius(DS.CornerRadius.xxl)
        .popover(isPresented: $showEditPopover) {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Text("确认词形")
                    .font(DS.Typography.button.weight(.semibold))
                
                TextField("正确词形", text: $correctedWord)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                
                Text("转录可能识别成: \(hotword.word)")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(DS.Colors.textSecondary)
                
                HStack {
                    Button("取消") {
                        showEditPopover = false
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("确认") {
                        onConfirm(correctedWord.isEmpty ? nil : correctedWord)
                        showEditPopover = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.Colors.warning)
                }
            }
            .padding(DS.Spacing.xl)
            .frame(width: 260)
        }
    }
}

// MARK: - AddDictionaryEntrySheet
// 已移至: spoke/UI/Settings/Dictionary/AddDictionaryEntrySheet.swift

// MARK: - BatchImportSheet
// 已移至: spoke/UI/Settings/Dictionary/BatchImportSheet.swift

// MARK: - EditDictionaryEntrySheet
// 已移至: spoke/UI/Settings/Dictionary/EditDictionaryEntrySheet.swift

// MARK: - TrainingPhraseCard
// 已移至: spoke/UI/Settings/Dictionary/EditDictionaryEntrySheet.swift

// MARK: - 生词列表入口

extension DictionarySettingsContent {
    var vocabularyListEntry: some View {
        Button {
            showVocabularyList = true
        } label: {
            HStack(spacing: DS.Spacing.lg) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: DS.Layout.iconSizeStandard))
                    .foregroundStyle(DS.Colors.error)
                
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("生词本")
                        .font(.system(size: DS.Typography.fontSizeContent, weight: .medium))
                        .foregroundStyle(DS.Colors.textPrimary)
                    
                    Text("查词时自动收藏的生词，同步到实时字幕高亮")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                
                Spacer()
                
                Text("\(vocabularyService.items.count) 个")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: DS.Layout.iconSizeSmall, weight: .semibold))
                    .foregroundStyle(DS.Colors.textSecondary.opacity(0.5))
            }
            .padding(DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.CornerRadius.md)
                    .fill(DS.Colors.rowHover)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - VocabularyListSheet
// 已移至: spoke/UI/Settings/Dictionary/VocabularyListSheet.swift
