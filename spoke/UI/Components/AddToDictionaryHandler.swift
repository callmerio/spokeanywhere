import SwiftUI

private typealias DS = DesignTokens

// MARK: - Add to Dictionary Handler

@MainActor
struct AddToDictionaryHandlerDependencies {
    let notificationCenter: NotificationCenter
    let dictionaryService: DictionaryService
    let messagePanelState: MessagePanelState
}

@MainActor
extension AddToDictionaryHandlerDependencies {
    static let live = AddToDictionaryHandlerDependencies(
        notificationCenter: .default,
        dictionaryService: .shared,
        messagePanelState: .shared
    )

    static let preview = AddToDictionaryHandlerDependencies(
        notificationCenter: NotificationCenter(),
        dictionaryService: .shared,
        messagePanelState: .shared
    )
}

@MainActor
struct AddToDictionarySheetDependencies {
    let dictionaryService: DictionaryService
    let addHighlight: (TextHighlight) -> Void
}

@MainActor
extension AddToDictionarySheetDependencies {
    static let live = AddToDictionarySheetDependencies(
        dictionaryService: .shared,
        addHighlight: { MessagePanelState.shared.addHighlightToLatestCard($0) }
    )
}

/// 处理「添加到词典」请求的管理器
@MainActor
final class AddToDictionaryHandler: ObservableObject {
    
    static let shared = AddToDictionaryHandler(dependencies: .live)
    
    @Published var isShowingAddSheet = false
    @Published var isShowingCorrectionSheet = false
    @Published var pendingWord = ""
    @Published var pendingFullText = ""  // 完整句子，用于训练短语
    
    private let dependencies: AddToDictionaryHandlerDependencies
    nonisolated(unsafe) private var observer: NSObjectProtocol?
    
    private init(
        dependencies: AddToDictionaryHandlerDependencies
    ) {
        self.dependencies = dependencies
        setupObserver()
    }

    static func makePreview() -> AddToDictionaryHandler {
        AddToDictionaryHandler(dependencies: .preview)
    }
    
    private func setupObserver() {
        observer = dependencies.notificationCenter.addObserver(
            forName: .requestAddToDictionary,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Extract data outside assumeIsolated to avoid sending non-Sendable Notification
            let userInfo = notification.userInfo
            let word = userInfo?["word"] as? String
            let mode = userInfo?["mode"] as? String
            let fullText = userInfo?["fullText"] as? String
            
            MainActor.assumeIsolated {
                self?.handleRequest(word: word, mode: mode, fullText: fullText)
            }
        }
    }
    
    private func handleRequest(word: String?, mode: String?, fullText: String?) {
        guard let word = word, let mode = mode else { return }
        
        pendingWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingFullText = (fullText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch mode {
        case "new":
            isShowingAddSheet = true
        case "correction":
            isShowingCorrectionSheet = true
        default:
            break
        }
    }
    
    /// 快速添加（不显示弹窗，直接添加）+ 记录训练短语
    func quickAdd(_ word: String, trainingPhrase: String? = nil) {
        Task { @MainActor in
            if let entry = dependencies.dictionaryService.addEntry(word: word) {
                // 如果有训练短语，记录下来
                if let phrase = trainingPhrase, !phrase.isEmpty {
                    dependencies.dictionaryService.addTrainingPhrase(phrase, to: entry.id)
                }
            }
        }
    }
    
    deinit {
        if let observer = observer {
            dependencies.notificationCenter.removeObserver(observer)
        }
    }
}

// MARK: - Quick Add to Dictionary Sheet

/// 从 Pipeline 添加词条的快速弹窗
struct QuickAddToDictionarySheet: View {
    @Binding var isPresented: Bool
    let initialWord: String
    let fullText: String  // 完整句子，用于训练短语
    
    @ObservedObject private var dictionaryService: DictionaryService
    private let dependencies: AddToDictionarySheetDependencies
    @State private var word: String
    @State private var correctionsText = ""
    
    init(
        isPresented: Binding<Bool>,
        initialWord: String,
        fullText: String = "",
        dependencies: AddToDictionarySheetDependencies
    ) {
        self._isPresented = isPresented
        self.initialWord = initialWord
        self.fullText = fullText
        self.dependencies = dependencies
        self.dictionaryService = dependencies.dictionaryService
        self._word = State(initialValue: initialWord)
    }

    @MainActor
    init(isPresented: Binding<Bool>, initialWord: String, fullText: String = "") {
        self.init(isPresented: isPresented, initialWord: initialWord, fullText: fullText, dependencies: .live)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "book.closed")
                    .foregroundStyle(DS.Colors.warning)
                Text("添加到词典")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            
            // 词条输入
            VStack(alignment: .leading, spacing: 6) {
                Text("期望词形")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DS.Colors.textSecondary)
                
                TextField("如: Anthropic", text: $word)
                    .textFieldStyle(.plain)
                    .padding(DS.Spacing.lg)
                    .background(DS.Colors.rowHover)
                    .cornerRadius(DS.CornerRadius.sm)
            }
            
            // 纠错输入（可选）
            VStack(alignment: .leading, spacing: 6) {
                Text("纠错映射（可选，每行一个）")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DS.Colors.textSecondary)
                
                TextEditor(text: $correctionsText)
                    .font(DS.Typography.caption)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(DS.Colors.rowHover)
                    .cornerRadius(DS.CornerRadius.sm)
                    .frame(height: 60)
            }
            
            // 操作按钮
            HStack {
                Button("取消") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .tint(DS.Colors.textSecondary)
                .controlSize(.small)
                
                Spacer()
                
                Button("添加") {
                    addEntry()
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Colors.warning)
                .controlSize(.small)
                .disabled(word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(DS.Spacing.xxl)
        .frame(width: 320)
        .background(DS.Colors.settingsPanelBackground)
    }
    
    private func addEntry() {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let corrections = correctionsText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if let entry = dictionaryService.addEntry(word: trimmedWord, corrections: corrections) {
            // 记录训练短语（完整句子用于预编译 LM）
            if !fullText.isEmpty {
                dictionaryService.addTrainingPhrase(fullText, to: entry.id)
            }
            
            // 添加高亮标记到 Pipeline 卡片（词典学习样式：橙色目标词）
            dependencies.addHighlight(.dictionary(word: trimmedWord))
        }
        isPresented = false
    }
}

// MARK: - Correct To Sheet

/// 将选中的错误文本映射到正确词形
/// 支持：1. 选择已有词条添加纠错  2. 输入新词自动创建词条+纠错
struct CorrectToSheet: View {
    @Binding var isPresented: Bool
    let errorText: String
    let fullText: String  // 完整句子，用于训练短语
    
    @ObservedObject private var dictionaryService: DictionaryService
    private let dependencies: AddToDictionarySheetDependencies
    @State private var correctWord = ""  // 用户输入的正确词形
    @State private var selectedEntryId: UUID?
    @FocusState private var isInputFocused: Bool

    init(
        isPresented: Binding<Bool>,
        errorText: String,
        fullText: String = "",
        dependencies: AddToDictionarySheetDependencies
    ) {
        self._isPresented = isPresented
        self.errorText = errorText
        self.fullText = fullText
        self.dependencies = dependencies
        self.dictionaryService = dependencies.dictionaryService
    }

    @MainActor
    init(isPresented: Binding<Bool>, errorText: String, fullText: String = "") {
        self.init(isPresented: isPresented, errorText: errorText, fullText: fullText, dependencies: .live)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(DS.Colors.accentPrimary)
                Text("纠正识别错误")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            
            // 显示错误识别的文本
            HStack {
                Text("错误识别:")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Colors.textSecondary)
                
                Text(errorText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DS.Colors.error.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DS.Colors.error.opacity(0.1))
                    .cornerRadius(DS.CornerRadius.xs)
            }
            
            // 正确词形输入
            VStack(alignment: .leading, spacing: 6) {
                Text("正确词形")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DS.Colors.textSecondary)
                
                TextField("输入正确的词，如: Gemini", text: $correctWord)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.button)
                    .padding(DS.Spacing.lg)
                    .background(DS.Colors.rowHover)
                    .cornerRadius(DS.CornerRadius.sm)
                    .focused($isInputFocused)
                    .onSubmit {
                        if !correctWord.trimmingCharacters(in: .whitespaces).isEmpty {
                            submitCorrection()
                        }
                    }
                    .onChange(of: correctWord) { _, newValue in
                        // 自动匹配已有词条
                        if let match = dictionaryService.entries.first(where: { 
                            $0.word.lowercased() == newValue.lowercased() 
                        }) {
                            selectedEntryId = match.id
                        } else {
                            selectedEntryId = nil
                        }
                    }
            }
            
            // 匹配提示
            if let matchedEntry = matchedEntry {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.Colors.success)
                        .font(.system(size: 12))
                    Text("将添加到已有词条「\(matchedEntry.word)」的纠错列表")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            } else if !correctWord.trimmingCharacters(in: .whitespaces).isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(DS.Colors.warning)
                        .font(.system(size: 12))
                    Text("将创建新词条「\(correctWord)」并添加纠错")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
            
            // 操作按钮
            HStack {
                Button("取消") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .tint(DS.Colors.textSecondary)
                .controlSize(.small)
                
                Spacer()
                
                Button("确认纠错") {
                    submitCorrection()
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Colors.accentPrimary)
                .controlSize(.small)
                .disabled(correctWord.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(DS.Spacing.xxl)
        .frame(width: 320)
        .background(DS.Colors.settingsPanelBackground)
        .onAppear {
            isInputFocused = true
        }
    }
    
    private var matchedEntry: DictionaryEntry? {
        guard let id = selectedEntryId else { return nil }
        return dictionaryService.entries.first { $0.id == id }
    }
    
    private func submitCorrection() {
        let trimmedWord = correctWord.trimmingCharacters(in: .whitespaces)
        guard !trimmedWord.isEmpty else { return }
        
        // 训练短语：将原句中的错误文本替换为正确词形
        // 例如: "cloud is great" + 纠正为 "Claude" → "Claude is great"
        let correctedPhrase = fullText.isEmpty
            ? ""
            : fullText.replacingOccurrences(
                of: errorText,
                with: trimmedWord,
                options: .caseInsensitive
            )
        
        if let entryId = selectedEntryId {
            // 添加到已有词条
            dictionaryService.addCorrection(errorText, to: entryId)
            // 记录纠正后的训练短语
            if !correctedPhrase.isEmpty {
                dictionaryService.addTrainingPhrase(correctedPhrase, to: entryId)
            }
        } else {
            // 创建新词条并添加纠错
            if let entry = dictionaryService.addEntry(word: trimmedWord, corrections: [errorText]) {
                // 记录纠正后的训练短语
                if !correctedPhrase.isEmpty {
                    dictionaryService.addTrainingPhrase(correctedPhrase, to: entry.id)
                }
            }
        }
        
        // 添加高亮标记到 Pipeline 卡片（纠错样式：~~错误词~~ + 正确词）
        dependencies.addHighlight(.correction(from: errorText, to: trimmedWord))
        
        isPresented = false
    }
}
