// swiftlint:disable file_length
// TODO: 未来重构 - 将此文件拆分为多个小文件
import SwiftUI

private typealias DS = DesignTokens

// MARK: - Dictionary Settings Content

/// 词典设置页面
/// 参考设计：橙色主题、卡片式列表、Tab 筛选
struct DictionarySettingsContent: View {
    @ObservedObject private var dictionaryService = DictionaryService.shared
    
    @State private var selectedFilter: DictionaryFilter = .all
    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var showBatchImportSheet = false
    @State private var editingEntry: DictionaryEntry?
    @State private var selectedEntries: Set<UUID> = []
    
    @State private var showVocabularyList = false
    
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
                        get: { TranscriptionManager.shared.isDictionaryInjectionEnabled },
                        set: { newValue in
                            TranscriptionManager.shared.isDictionaryInjectionEnabled = newValue
                            if newValue {
                                // 开启时重新准备词典
                                Task {
                                    await TranscriptionManager.shared.prepareDictionary()
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
            if TranscriptionManager.shared.isDictionaryInjectionEnabled {
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
                            Task {
                                await TranscriptionManager.shared.prepareDictionary()
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
        .animation(DS.Animation.normal, value: TranscriptionManager.shared.isDictionaryInjectionEnabled)
    }
    
    private var dictionaryStatusBadge: some View {
        HStack(spacing: DS.Spacing.sm) {
            Circle()
                .fill(TranscriptionManager.shared.isDictionaryPrepared ? DS.Colors.success : DS.Colors.warning)
                .frame(width: DS.Spacing.sm, height: DS.Spacing.sm)
            
            Text(TranscriptionManager.shared.isDictionaryPrepared ? "已就绪" : "待准备")
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

// MARK: - Add Dictionary Entry Sheet

struct AddDictionaryEntrySheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var dictionaryService = DictionaryService.shared
    
    @State private var word = ""
    @State private var correctionsText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            // 标题
            HStack {
                Text("添加词条")
                    .font(DS.Typography.title)
                    .foregroundStyle(DS.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: DS.Layout.iconSizeSmall, weight: .semibold))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            
            // 词条输入
            VStack(alignment: .leading, spacing: 8) {
                Text("期望词形")
                    .font(DS.Typography.caption.weight(.medium))
                    .foregroundStyle(DS.Colors.textSecondary)
                
                TextField("如: Anthropic, Claude, GPT-4", text: $word)
                    .textFieldStyle(.plain)
                    .padding(DS.Spacing.lg)
                    .background(DS.Colors.settingsCardBackground)
                    .cornerRadius(DS.CornerRadius.md)
            }
            
            // 纠错映射输入
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("纠错映射（可选）")
                        .font(DS.Typography.caption.weight(.medium))
                        .foregroundStyle(DS.Colors.textSecondary)
                    
                    Text("每行一个")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(DS.Colors.textSecondary.opacity(0.7))
                }
                
                TextEditor(text: $correctionsText)
                    .font(DS.Typography.button)
                    .scrollContentBackground(.hidden)
                    .padding(DS.Spacing.lg)
                    .background(DS.Colors.settingsCardBackground)
                    .cornerRadius(DS.CornerRadius.md)
                    .frame(height: 80)
                
                Text("转录引擎可能识别成的错误形式，后处理时会自动替换为正确词形")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(DS.Colors.textSecondary.opacity(0.7))
            }
            
            if showError {
                Text(errorMessage)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.error)
            }
            
            // 操作按钮
            HStack {
                Button("取消") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .tint(DS.Colors.textSecondary)
                
                Spacer()
                
                Button("添加") {
                    addEntry()
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Colors.warning)
                .disabled(word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(DS.Spacing.xxl)
        .frame(width: 400)
        .background(DS.Colors.settingsPanelBackground)
    }
    
    private func addEntry() {
        let corrections = correctionsText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if dictionaryService.addEntry(word: word, corrections: corrections) != nil {
            isPresented = false
        } else {
            showError = true
            errorMessage = "词条已存在或格式无效"
        }
    }
}

// MARK: - Batch Import Sheet

struct BatchImportSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var dictionaryService = DictionaryService.shared
    
    @State private var importText = ""
    @State private var importResult: DictionaryImportResult?
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            // 标题
            HStack {
                Text("批量导入")
                    .font(DS.Typography.title)
                    .foregroundStyle(DS.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: DS.Layout.iconSizeSmall, weight: .semibold))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            
            // 说明
            Text("每行一个词条，支持格式：")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textSecondary)
            
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("• 简单格式: 词条名")
                Text("• 带纠错: 词条名=错误形式1,错误形式2")
            }
            .font(.system(size: DS.Typography.fontSizeCaptionSmall, design: .monospaced))
            .foregroundStyle(DS.Colors.textSecondary.opacity(0.8))
            .padding(DS.Spacing.lg)
            .background(DS.Colors.settingsCardBorder.opacity(0.5))
            .cornerRadius(DS.CornerRadius.md)
            
            // 输入框
            TextEditor(text: $importText)
                .font(.system(size: DS.Typography.fontSizeButton, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(DS.Spacing.lg)
                .background(DS.Colors.settingsCardBackground)
                .cornerRadius(DS.CornerRadius.md)
                .frame(height: 200)
            
            // 导入结果
            if let result = importResult {
                HStack(spacing: DS.Spacing.xl) {
                    Label("\(result.successCount) 成功", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(DS.Colors.success)
                    
                    if result.duplicateCount > 0 {
                        Label("\(result.duplicateCount) 重复", systemImage: "arrow.triangle.2.circlepath")
                            .foregroundStyle(DS.Colors.warning)
                    }
                    
                    if result.errorCount > 0 {
                        Label("\(result.errorCount) 失败", systemImage: "xmark.circle.fill")
                            .foregroundStyle(DS.Colors.error)
                    }
                }
                .font(DS.Typography.caption)
            }
            
            // 操作按钮
            HStack {
                Button("取消") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .tint(DS.Colors.textSecondary)
                
                Spacer()
                
                Button("导入") {
                    importResult = dictionaryService.batchImport(from: importText)
                    if importResult?.successCount ?? 0 > 0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            isPresented = false
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Colors.warning)
                .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(DS.Spacing.xxl)
        .frame(width: 450)
        .background(DS.Colors.settingsPanelBackground)
    }
}

// MARK: - Edit Dictionary Entry Sheet

struct EditDictionaryEntrySheet: View {
    let entryId: UUID
    @Binding var isPresented: Bool
    @ObservedObject private var dictionaryService = DictionaryService.shared
    
    @State private var word: String
    @State private var correctionsText: String
    
    /// 从 service 获取最新数据（去重后会自动更新）
    private var entry: DictionaryEntry? {
        dictionaryService.entries.first { $0.id == entryId }
    }
    
    init(entry: DictionaryEntry, isPresented: Binding<Bool>) {
        self.entryId = entry.id
        self._isPresented = isPresented
        self._word = State(initialValue: entry.word)
        self._correctionsText = State(initialValue: entry.corrections.joined(separator: "\n"))
    }
    
    var body: some View {
        if let entry = entry {
            sheetContent(entry: entry)
        } else {
            // entry 被删除时关闭
            Color.clear.onAppear { isPresented = false }
        }
    }
    
    @ViewBuilder
    private func sheetContent(entry: DictionaryEntry) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            // 标题
            HStack {
                Text("编辑词条")
                    .font(DS.Typography.title)
                    .foregroundStyle(DS.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: DS.Layout.iconSizeSmall, weight: .semibold))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            
            // 词条信息
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: entry.source.icon)
                    .foregroundStyle(entry.source == .auto ? DS.Colors.warning : DS.Colors.accentPrimary)
                Text(entry.source.displayName)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(DS.Colors.textSecondary)
                
                Spacer()
                
                Text("创建于 \(entry.relativeCreatedAt)")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(DS.Colors.textSecondary.opacity(0.7))
            }
            
            // 词条输入
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("期望词形")
                    .font(DS.Typography.caption.weight(.medium))
                    .foregroundStyle(DS.Colors.textSecondary)
                
                TextField("词条名", text: $word)
                    .textFieldStyle(.plain)
                    .padding(DS.Spacing.lg)
                    .background(DS.Colors.settingsCardBackground)
                    .cornerRadius(DS.CornerRadius.md)
            }
            
            // 纠错映射输入
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("纠错映射（每行一个）")
                    .font(DS.Typography.caption.weight(.medium))
                    .foregroundStyle(DS.Colors.textSecondary)
                
                TextEditor(text: $correctionsText)
                    .font(DS.Typography.button)
                    .scrollContentBackground(.hidden)
                    .padding(DS.Spacing.lg)
                    .background(DS.Colors.settingsCardBackground)
                    .cornerRadius(DS.CornerRadius.md)
                    .frame(height: 80)
            }
            
            // 训练短语（预编译 LM 用）- Pipeline 风格卡片
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    Text("训练短语")
                        .font(DS.Typography.caption.weight(.medium))
                        .foregroundStyle(DS.Colors.textSecondary)
                    
                    if !entry.trainingPhrases.isEmpty {
                        Text("(\(entry.trainingPhrases.count))")
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(DS.Colors.textSecondary.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    if !entry.trainingPhrases.isEmpty {
                        Button(action: clearTrainingPhrases) {
                            Text("清空")
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(DS.Colors.error.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if entry.trainingPhrases.isEmpty {
                    // 空状态
                    Text("暂无训练短语，右键纠正时自动收集")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(DS.Colors.textSecondary.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, DS.Spacing.xxl)
                } else {
                    // Pipeline 风格卡片列表
                    ScrollView {
                        VStack(spacing: DS.Spacing.md) {
                            ForEach(entry.trainingPhrases.indices, id: \.self) { index in
                                TrainingPhraseCard(
                                    phrase: entry.trainingPhrases[index],
                                    targetWord: entry.word,
                                    onEdit: { newPhrase in
                                        updateTrainingPhrase(at: index, with: newPhrase)
                                    },
                                    onDelete: {
                                        removeTrainingPhrase(at: index)
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }
                
                Text("用于预编译语言模型，提高「\(entry.word)」识别率")
                    .font(DS.Typography.timestamp)
                    .foregroundStyle(DS.Colors.textSecondary.opacity(0.6))
            }
            
            // 操作按钮
            HStack {
                Button("取消") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .tint(DS.Colors.textSecondary)
                
                Spacer()
                
                Button(role: .destructive) {
                    dictionaryService.deleteEntry(entry)
                    isPresented = false
                } label: {
                    Text("删除")
                }
                .buttonStyle(.bordered)
                .tint(DS.Colors.error)
                
                Button("保存") {
                    saveChanges()
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Colors.warning)
                .disabled(word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(DS.Spacing.xxl)
        .frame(width: 400)
        .background(DS.Colors.settingsPanelBackground)
        .onAppear {
            // 打开时自动去重
            dictionaryService.deduplicateTrainingPhrases(for: entryId)
        }
    }
    
    private func saveChanges() {
        guard var updated = entry else { return }
        updated.word = word.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.corrections = correctionsText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        dictionaryService.updateEntry(updated)
        isPresented = false
    }
    
    private func clearTrainingPhrases() {
        dictionaryService.clearTrainingPhrases(for: entryId)
    }
    
    private func removeTrainingPhrase(at index: Int) {
        dictionaryService.removeTrainingPhrase(at: index, from: entryId)
    }
    
    private func updateTrainingPhrase(at index: Int, with newPhrase: String) {
        dictionaryService.updateTrainingPhrase(at: index, with: newPhrase, for: entryId)
    }
}

// MARK: - Training Phrase Card

/// 训练短语卡片（Pipeline 风格）
/// 支持高亮目标词、编辑、删除
struct TrainingPhraseCard: View {
    let phrase: String
    let targetWord: String
    let onEdit: (String) -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editingText = ""
    
    /// 金黄色高亮颜色（复用 Pipeline 选中样式）
    private let highlightColor = DS.Colors.highlightGold
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEditing {
                // 编辑模式
                editingView
            } else {
                // 显示模式
                displayView
            }
        }
        .padding(DS.Spacing.lg)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.CornerRadius.lg, style: .continuous))
        .onHover { hovering in
            withAnimation(DS.Animation.fast) {
                isHovered = hovering
            }
        }
    }
    
    // MARK: - Display View
    
    private var displayView: some View {
        ZStack(alignment: .topTrailing) {
            // 高亮目标词的富文本（占满宽度）
            highlightedText
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 操作按钮（hover 时悬浮在右上角）
            if isHovered {
                HStack(spacing: DS.Spacing.sm) {
                    // 编辑按钮
                    cardActionButton(icon: "pencil") {
                        editingText = phrase
                        isEditing = true
                    }
                    
                    // 删除按钮
                    cardActionButton(icon: "xmark", color: DS.Colors.error.opacity(0.7)) {
                        onDelete()
                    }
                }
                .padding(DS.Spacing.xs)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DS.CornerRadius.sm))
                .offset(x: DS.Spacing.xs, y: -DS.Spacing.xs)  // 微调位置
                .transition(.opacity)
            }
        }
    }
    
    // MARK: - Editing View
    
    private var editingView: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            TextEditor(text: $editingText)
                .font(DS.Typography.caption)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 50, maxHeight: 80)
            
            HStack {
                Button("取消") {
                    isEditing = false
                    editingText = ""
                }
                .font(DS.Typography.captionSmall)
                .foregroundStyle(DS.Colors.textSecondary)
                .buttonStyle(.plain)
                
                Spacer()
                
                Button("保存") {
                    let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        onEdit(trimmed)
                    }
                    isEditing = false
                    editingText = ""
                }
                .font(DS.Typography.captionSmall.weight(.medium))
                .foregroundStyle(DS.Colors.warning)
                .buttonStyle(.plain)
                .disabled(editingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    
    // MARK: - Highlighted Text
    
    /// 高亮目标词的富文本视图
    private var highlightedText: some View {
        // 使用 Text 拼接实现高亮
        buildHighlightedText()
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Colors.textPrimary.opacity(0.9))
    }
    
    /// 构建高亮文本（使用 Text + AttributedString 支持自动换行）
    private func buildHighlightedText() -> Text {
        var result = Text("")
        let components = splitByTargetWord()
        
        for component in components {
            if component.isTarget {
                // 目标词：金黄色背景
                var attributed = AttributedString(component.text)
                attributed.backgroundColor = highlightColor
                attributed.foregroundColor = DS.Colors.textPrimary
                result = result + Text(attributed)  // swiftlint:disable:this shorthand_operator
            } else {
                result = result + Text(component.text)  // swiftlint:disable:this shorthand_operator
            }
        }
        
        return result
    }
    
    /// 按目标词分割文本
    private func splitByTargetWord() -> [TextComponent] {
        var components: [TextComponent] = []
        
        // 安全检查：空字符串直接返回
        guard !phrase.isEmpty, !targetWord.isEmpty else {
            if !phrase.isEmpty {
                components.append(TextComponent(text: phrase, isTarget: false))
            }
            return components
        }
        
        // 使用字符偏移量而不是 String.Index，避免索引不兼容问题
        let lowercasedPhrase = phrase.lowercased()
        let lowercasedTarget = targetWord.lowercased()
        
        var currentOffset = 0
        let phraseChars = Array(phrase)
        let lowercasedChars = Array(lowercasedPhrase)
        
        while currentOffset < lowercasedChars.count {
            // 在 lowercased 版本中查找目标词
            let searchString = String(lowercasedChars[currentOffset...])
            if let range = searchString.range(of: lowercasedTarget) {
                let matchOffset = searchString.distance(from: searchString.startIndex, to: range.lowerBound)
                let matchLength = lowercasedTarget.count
                
                // 添加目标词之前的普通文本
                if matchOffset > 0 {
                    let beforeText = String(phraseChars[currentOffset..<(currentOffset + matchOffset)])
                    components.append(TextComponent(text: beforeText, isTarget: false))
                }
                
                // 添加目标词（使用原文大小写）
                let targetStart = currentOffset + matchOffset
                let targetEnd = min(targetStart + matchLength, phraseChars.count)
                let targetText = String(phraseChars[targetStart..<targetEnd])
                components.append(TextComponent(text: targetText, isTarget: true))
                
                currentOffset = targetEnd
            } else {
                // 没有更多匹配，添加剩余文本
                break
            }
        }
        
        // 添加剩余文本
        if currentOffset < phraseChars.count {
            let text = String(phraseChars[currentOffset...])
            components.append(TextComponent(text: text, isTarget: false))
        }
        
        // 如果没有匹配到目标词，返回整个文本
        if components.isEmpty {
            components.append(TextComponent(text: phrase, isTarget: false))
        }
        
        return components
    }
    
    // MARK: - Helpers
    
    private struct TextComponent {
        let text: String
        let isTarget: Bool
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: DS.CornerRadius.lg, style: .continuous)
            .fill(isHovered ? DS.Colors.trainingCardBackgroundHover : DS.Colors.trainingCardBackground)
    }
    
    private func cardActionButton(icon: String, color: Color = DS.Colors.textSecondary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: DS.Typography.fontSizeTimestamp, weight: .medium))
                .foregroundStyle(color)
                .frame(width: DS.Layout.iconSizeStandard, height: DS.Layout.iconSizeStandard)
                .background(DS.Colors.chipBackground)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

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
                
                Text("\(VocabularyService.shared.items.count) 个")
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

private struct VocabularyItemRow: View {
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
