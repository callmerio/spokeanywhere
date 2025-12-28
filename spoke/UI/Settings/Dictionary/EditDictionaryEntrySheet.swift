import SwiftUI

private typealias DS = DesignTokens

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
