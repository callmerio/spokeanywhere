import AppKit
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.spokeanywhere", category: "DictionaryPanelView")

// MARK: - Dictionary Panel View

@MainActor
struct DictionaryPanelViewDependencies {
    let parseDefinition: (String, String) -> ParsedDefinition
}

struct DictionaryPanelView: View {
    @Bindable var state: DictionaryPanelState
    let onDismiss: () -> Void
    private let dependencies: DictionaryPanelViewDependencies

    init(
        state: DictionaryPanelState,
        onDismiss: @escaping () -> Void,
        dependencies: DictionaryPanelViewDependencies
    ) {
        self.state = state
        self.onDismiss = onDismiss
        self.dependencies = dependencies
    }

    @MainActor
    init(
        state: DictionaryPanelState,
        onDismiss: @escaping () -> Void
    ) {
        self.init(state: state, onDismiss: onDismiss, dependencies: .live)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            switch state.viewMode {
            case .list:
                listView
            case .detail(let result):
                detailView(result)
            }
        }
        .frame(width: 600, height: 420)
        .background(
            ZStack {
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                DesignTokens.Colors.overlayDark
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xl))
        .onAppear {
            runDictionaryPanelAsync {
                await state.performSearch("")
            }
        }
    }
    
    // MARK: - List View
    
    private var listView: some View {
        VStack(spacing: 0) {
            searchBar
            Divider().background(DesignTokens.Colors.borderPrimary)
            resultsList
            Divider().background(DesignTokens.Colors.borderPrimary)
            actionBar
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            Button(action: onDismiss) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            
            DictionarySearchField(
                text: Binding(
                    get: { state.searchText },
                    set: { state.search($0) }
                ),
                placeholder: "Search word...",
                onSubmit: { state.confirmSelection() },
                onCancel: onDismiss
            )
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }
    
    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if state.results.isEmpty && !state.searchText.isEmpty {
                        emptyState
                    } else if state.results.isEmpty {
                        recentWordsHeader
                    } else {
                        // 🔥 使用 \.offset 作为 ID，强制按数组顺序渲染
                        // 避免 SwiftUI 根据 element.id 复用旧 cell 位置
                        ForEach(Array(state.results.enumerated()), id: \.offset) { index, result in
                            Button {
                                state.selectedIndex = index
                                state.confirmSelection()
                            } label: {
                                WordResultRow(
                                    result: result,
                                    isSelected: index == state.selectedIndex,
                                    isVocabulary: state.isVocabulary(result.word),
                                    parseDefinition: dependencies.parseDefinition
                                )
                            }
                            .buttonStyle(.plain)
                            .id("\(index)-\(state.refreshTrigger)") // 加入 refreshTrigger 强制刷新
                        }
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.xs)
            }
            .onChange(of: state.selectedIndex) { _, newIndex in
                withAnimation(DesignTokens.Animation.fast) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(DesignTokens.Colors.textPlaceholder)
            Text("未找到 \"\(state.searchText)\"")
                .font(DesignTokens.Typography.content)
                .foregroundStyle(DesignTokens.Colors.textPlaceholder)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    private var recentWordsHeader: some View {
        HStack {
            Text("Recent Words")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textPlaceholder)
            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.md)
    }
    
    private var actionBar: some View {
        HStack(spacing: DesignTokens.Spacing.xl) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "book")
                    .font(.system(size: 12))
                Text("Define Word")
                    .font(DesignTokens.Typography.caption)
            }
            .foregroundStyle(DesignTokens.Colors.textPlaceholder)
            
            Spacer()
            
            HStack(spacing: DesignTokens.Spacing.xl) {
                actionItem("Show Details", key: "↵")
                actionItem("Toggle Vocabulary", key: "Tab")
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.lg)
        .background(DesignTokens.Colors.overlayDark.opacity(0.7))
    }
    
    private func actionItem(_ title: String, key: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Text(title)
                .font(DesignTokens.Typography.captionSmall)
                .foregroundStyle(DesignTokens.Colors.textPlaceholder)
            Text(key)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(DesignTokens.Colors.textPlaceholder)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(DesignTokens.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xs))
        }
    }
    
    // MARK: - Detail View
    
    private func detailView(_ result: LocalDictionaryResult) -> some View {
        VStack(spacing: 0) {
            detailHeader(result)
            Divider().background(DesignTokens.Colors.borderPrimary)
            detailContent(result)
            Divider().background(DesignTokens.Colors.borderPrimary)
            detailActionBar(result)
        }
    }
    
    private func detailHeader(_ result: LocalDictionaryResult) -> some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            Button(action: { state.backToList() }, label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            })
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }
    
    private func detailContent(_ result: LocalDictionaryResult) -> some View {
        ScrollView {
            FormattedDefinitionView(
                result: result,
                isVocabulary: state.isVocabulary(result.word),
                onWordTap: { word in
                    // 跳转查询新单词
                    state.searchText = word
                    state.viewMode = .list
                    runDictionaryPanelAsync {
                        await state.performSearch(word)
                        // 如果有结果，直接进入详情
                        if let firstResult = state.results.first {
                            state.viewMode = .detail(firstResult)
                        }
                    }
                }
            )
            .id("detail-\(result.word)-\(state.refreshTrigger)") // 强制刷新详情页
            .padding(20)
        }
        .frame(maxHeight: .infinity)
    }
    
    private func detailActionBar(_ result: LocalDictionaryResult) -> some View {
        HStack(spacing: DesignTokens.Spacing.xl) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if state.isVocabulary(result.word) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(DesignTokens.Colors.warning)
                }
                Text(result.word)
                    .font(DesignTokens.Typography.caption)
            }
            .foregroundStyle(DesignTokens.Colors.textSecondary)
            
            Spacer()
            
            HStack(spacing: DesignTokens.Spacing.xl) {
                actionItem("Back to List", key: "ESC")
                actionItem(state.isVocabulary(result.word) ? "Remove" : "Add Vocabulary", key: "Tab")
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.lg)
        .background(DesignTokens.Colors.overlayDark.opacity(0.7))
    }
}

// MARK: - Word Result Row

struct WordResultRow: View {
    let result: LocalDictionaryResult
    let isSelected: Bool
    let isVocabulary: Bool
    let parseDefinition: (String, String) -> ParsedDefinition
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            Text(result.word)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isVocabulary ? DesignTokens.Colors.warning : DesignTokens.Colors.textPrimary)
            
            // 使用富文本显示: 灰色POS + 中文意思
            briefDefinitionText
                .lineLimit(1)
            
            Spacer()
            
            if isVocabulary {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(DesignTokens.Colors.warning)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.lg)
        .background(isSelected ? DesignTokens.Colors.buttonHover : Color.clear)
        .contentShape(Rectangle())
    }
    
    private var briefDefinitionText: Text {
        let parsed = parseDefinition(result.word, result.definition)
        let posAbbr: [String: String] = [
            "adjective": "adj.", "noun": "n.", "verb": "v.", 
            "adverb": "adv.", "preposition": "prep.", "pronoun": "pron.",
            "conjunction": "conj.", "interjection": "interj.", "determiner": "det.",
            "transitive verb": "vt.", "intransitive verb": "vi."
        ]
        
        var textParts: [Text] = []
        
        for section in parsed.sections.prefix(3) {
            let abbr = posAbbr[section.pos.lowercased()] ?? section.pos
            var meanings: [String] = []
            for sense in section.senses.prefix(2) {
                if let chinese = sense.chinese, !chinese.isEmpty {
                    meanings.append(chinese)
                }
            }
            if !meanings.isEmpty {
                // 灰色 POS
                let posText = Text(abbr)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textPlaceholder)
                // 中文意思
                let meaningText = Text(" " + meanings.joined(separator: "；"))
                    .font(DesignTokens.Typography.button)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                
                if !textParts.isEmpty {
                    textParts.append(Text("  "))
                }
                textParts.append(posText + meaningText)
            }
        }
        
        if textParts.isEmpty {
            // Fallback
            return Text(result.briefDefinition)
                .font(DesignTokens.Typography.button)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
        
        return textParts.reduce(Text("")) { $0 + $1 }
    }
}

// MARK: - Dictionary Search Field (NSTextField Wrapper)

struct DictionarySearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = NSFont.systemFont(ofSize: 18)
        textField.textColor = DesignTokens.Colors.NS.textPrimary
        textField.placeholderString = placeholder
        textField.cell?.sendsActionOnEndEditing = false
        
        runDictionaryPanelAsync {
            textField.window?.makeFirstResponder(textField)
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        // 避免不必要的更新，防止光标跳动和文本被选中
        // 只有当外部修改 text 时才更新（如 reset），用户输入由 delegate 处理
        guard nsView.stringValue != text else { return }
        
        // 保存当前光标位置
        let currentEditor = nsView.currentEditor() as? NSTextView
        let selectedRange = currentEditor?.selectedRange()
        
        nsView.stringValue = text
        
        // 恢复光标到末尾（避免全选）
        if let editor = currentEditor {
            let endPosition = NSRange(location: text.count, length: 0)
            editor.setSelectedRange(selectedRange ?? endPosition)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: DictionarySearchField
        
        init(_ parent: DictionarySearchField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit?()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onCancel?()
                return true
            }
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                DictionaryPanelState.current?.selectPrevious()
                return true
            }
            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                DictionaryPanelState.current?.selectNext()
                return true
            }
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                DictionaryPanelState.current?.toggleVocabulary()
                return true
            }
            return false
        }
    }
}
