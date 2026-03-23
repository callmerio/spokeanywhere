import AppKit
import Combine
import os
import SwiftUI
@preconcurrency import Translation

private typealias DS = DesignTokens
private let scrollLogger = Logger(subsystem: "app.spokenly", category: "LiveCaptionScroll")
// MARK: - AppKitScrollView
// 已移至: spoke/UI/LiveCaption/AppKitScrollView.swift

// MARK: - CaptionDesign
// 已移至: spoke/UI/LiveCaption/CaptionDesign.swift

// MARK: - Live Caption View

/// 实时字幕视图 - 简洁卡片式设计
/// 集成 Apple Translation API 实现实时翻译（macOS 15+）
@MainActor
struct LiveCaptionViewDependencies {
    let lookupWord: (String) async -> UnifiedDictionaryResult?
    let markVocabulary: (String) -> String
    let showSelectionToolbar: (SelectionContext, CGPoint) -> Void
    let showDictionaryResult: (DictionaryData, String, SelectionContext, CGPoint) async -> Void
    let showDictionaryError: (String, SelectionContext, CGPoint) async -> Void
    let notificationCenter: NotificationCenter
}

@MainActor
extension LiveCaptionViewDependencies {
    static func live(
        lookupWord: @escaping (String) async -> UnifiedDictionaryResult?,
        markVocabulary: @escaping (String) -> String,
        selectionToolbarState: SelectionToolbarState,
        selectionToolbarManager: SelectionToolbarManager
    ) -> Self {
        LiveCaptionViewDependencies(
            lookupWord: lookupWord,
            markVocabulary: markVocabulary,
            showSelectionToolbar: { context, point in
                selectionToolbarState.show(with: context)
                selectionToolbarManager.show(at: point)
            },
            showDictionaryResult: { data, word, context, point in
                selectionToolbarState.currentContext = context
                selectionToolbarState.showDictionaryResult(data, forText: word)
                try? await Task.sleep(for: .milliseconds(16))
                selectionToolbarManager.show(at: point)
            },
            showDictionaryError: { word, context, point in
                selectionToolbarState.currentContext = context
                selectionToolbarState.showDictionaryError(.notFound, word: word)
                try? await Task.sleep(for: .milliseconds(16))
                selectionToolbarManager.show(at: point)
            },
            notificationCenter: .default
        )
    }

    static let preview = LiveCaptionViewDependencies(
        lookupWord: { _ in nil },
        markVocabulary: { $0 },
        showSelectionToolbar: { _, _ in },
        showDictionaryResult: { _, _, _, _ in },
        showDictionaryError: { _, _, _ in },
        notificationCenter: NotificationCenter()
    )
}

struct LiveCaptionView: View {
    
    @ObservedObject var manager: LiveCaptionManager
    @ObservedObject var translator: TranslationService
    private let dependencies: LiveCaptionViewDependencies
    
    @State private var isExpanded: Bool = false
    @State private var isHovering: Bool = false
    @State private var isAtBottom: Bool = true
    @State private var scrollTrigger: Int = 0  // 触发滚动的计数器
    @State private var isUserSelecting: Bool = false  // 用户正在选择文本时暂停滚动
    @State private var vocabularyRefreshTrigger: Int = 0  // 生词列表变化时触发全量刷新
    @State private var appearedItemIDs: Set<UUID> = []  // 已出现过的 item ID（用于灰→白动画）
    
    // Hover 工具栏状态
    @State private var isCopyHovered: Bool = false
    @State private var isExpandHovered: Bool = false
    @State private var isCloseHovered: Bool = false
    @State private var isCopied: Bool = false  // 复制成功状态（显示 checkmark）
    @State private var highlightedWord: String?  // 🔥 当前点击高亮的单词（跨所有 VocabularyHighlightText 共享）

    var onClose: () -> Void

    init(
        manager: LiveCaptionManager,
        onClose: @escaping () -> Void,
        translator: TranslationService,
        dependencies: LiveCaptionViewDependencies
    ) {
        self.manager = manager
        self.onClose = onClose
        self.translator = translator
        self.dependencies = dependencies
    }
    
    var body: some View {
        ZStack {
            // 内容
            VStack(spacing: 0) {
                if isExpanded {
                    expandedContent
                } else {
                    collapsedContent
                }
                
                // 底部拖动指示器
                dragIndicator
            }
            
            // Hover 时显示悬浮控制层（左岛+右岛）
            if isHovering {
                VStack {
                    HStack(alignment: .top) {
                        // 👈 左岛：语言切换器（仅展开时显示，或根据需求常驻）
                        if isExpanded {
                            Menu {
                                ForEach(LiveCaptionManager.supportedLanguages, id: \.id) { lang in
                                    Button {
                                        Task {
                                            await manager.setLocale(lang.id)
                                        }
                                    } label: {
                                        if manager.sourceLanguage == lang.id {
                                            Label(lang.name, systemImage: "checkmark")
                                        } else {
                                            Text(lang.name)
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "globe")
                                        .font(.system(size: 12))
                                    Text(
                                        LiveCaptionManager.supportedLanguages
                                            .first(where: { $0.id == manager.sourceLanguage })?.name ?? "Language"
                                    )
                                        .font(.system(size: 12, weight: .medium))
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10))
                                        .opacity(0.6)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                        
                        Spacer()
                        
                        // 👉 右岛：功能按钮
                        hoverToolbar
                            .padding(4)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                    .padding(12)
                    
                    Spacer() // 推到顶部
                }
                .transition(.opacity.animation(.easeInOut(duration: 0.15)))
            }
        }
        .frame(width: CaptionDesign.maxWidth)
        .fixedSize(horizontal: false, vertical: true)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CaptionDesign.cornerRadius))
        .overlay(cardBorder)
        .background(shadowAndGlowLayer)
        .padding(CaptionDesign.shadowPadding)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onAppear {
            setupTranslation()
        }
        .onChange(of: manager.translationEnabled) { _, enabled in
            if enabled {
                setupTranslation()
            }
        }
        .onReceive(dependencies.notificationCenter.publisher(for: .vocabularyChanged)) { _ in
            // 生词列表变化时触发全量刷新（包括之前的内容）
            vocabularyRefreshTrigger += 1
        }
        .onReceive(dependencies.notificationCenter.publisher(for: .translationUpdated)) { _ in
            // 翻译完成后强制触发滚动（解决放久了错位问题）
            // 🔥 关键修复：延迟触发滚动，等待 UI 布局完成
            // 当"一口气输出太多"时，布局更新是异步的，立即滚动会基于旧高度计算
            scrollLogger.debug("📜 翻译完成通知: isAtBottom=\(isAtBottom) isUserSelecting=\(isUserSelecting)")
            if isAtBottom && !isUserSelecting {
                // 立即触发一次
                scrollTrigger += 1
                // 延迟 100ms 再触发一次，确保布局完成后追赶
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if isAtBottom && !isUserSelecting {
                        scrollTrigger += 1
                    }
                }
            }
        }
        .accessibilityIdentifier(UITestIdentifiers.Element.liveCaptionRoot)
    }
    
    // MARK: - Translation
    
    /// 设置翻译（准备 configuration）
    private func setupTranslation() {
        guard manager.translationEnabled else { return }
        
        if #available(macOS 15.0, *) {
            translator.prepareSession(
                source: manager.captionLocale,
                target: translator.targetLanguage
            )
        }
    }
    
    /// 触发翻译
    private func triggerTranslation() {
        if #available(macOS 15.0, *) {
            translator.invalidateSession()
            setupTranslation()
        }
    }
    
    // MARK: - Content Views
    
    /// 折叠状态 - 列表模式
    /// 显示最近的句子流：[已确定句1] -> [已确定句2] -> [正在输入句]
    private var collapsedContent: some View {
        let isEmpty = manager.lineBuffer.items.isEmpty && manager.lineBuffer.pendingText.isEmpty
        
        return Group {
            if isEmpty {
                // 空状态
                Text("等待音频...")
                    .font(.system(size: CaptionDesign.fontSize))
                    .foregroundColor(CaptionDesign.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            } else {
                AppKitScrollView(isAtBottom: $isAtBottom, scrollTrigger: scrollTrigger) {
                    // 🔥 移除 Spacer，避免内容变化时 Spacer 高度重算导致滚动跳变
                    VStack(alignment: .leading, spacing: 16) {
                        // 1. 已确定的句子（原文+译文）- 使用 CaptionItemView 独立组件
                        // 🔥 方案 F: 三层防御 - CaptionItem 是 class + @ObservedObject 隔离
                        ForEach(manager.lineBuffer.items) { item in
                            let isNew = !appearedItemIDs.contains(item.id)
                            CaptionItemView(
                                item: item,
                                isNew: isNew,
                                translationFontSize: CaptionDesign.translatedFontSize,
                                translationColor: CaptionDesign.textSecondary
                            ) {
                                captionText(for: item.original, opacity: isNew ? 0.7 : 1.0)
                            }
                            .opacity(isNew ? 0.7 : 1.0)
                            .animation(.easeOut(duration: 0.3), value: isNew)
                            .onAppear { 
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    appearedItemIDs.insert(item.id)
                                }
                            }
                        }
                        
                        // 2. 正在输入的流式文本（原文 + 流式翻译）
                        // 🔥 用 pendingLineActive 而不是 isEmpty，防止转录回退时整行消失导致布局跳动
                        if manager.lineBuffer.pendingLineActive {
                            VStack(alignment: .leading, spacing: 4) {
                                // 流式原文 - 使用 displayPendingText 保证内容不会瞬间变空
                                // 🔥 修复：始终保留 VocabularyHighlightText，避免类型切换导致视图重建
                                let displayText = manager.lineBuffer.displayPendingText
                                VocabularyHighlightText(
                                    text: displayText.isEmpty ? " " : displayText,
                                    fontSize: CaptionDesign.fontSize,
                                    opacity: displayText.isEmpty ? 0 : 0.7,
                                    onSelectionStarted: {
                                        isUserSelecting = true
                                        manager.lineBuffer.setUserInteracting(true)
                                    },
                                    onSelectionEnded: {
                                        isUserSelecting = false
                                        manager.lineBuffer.setUserInteracting(false)
                                    },
                                    onTextSelected: { selectedText, screenPoint in
                                        handleTextSelected(selectedText, at: screenPoint)
                                    },
                                    onWordClicked: { word, screenPoint in
                                        handleWordClicked(word, at: screenPoint)
                                    },
                                    refreshTrigger: vocabularyRefreshTrigger,
                                    highlightedWord: highlightedWord
                                )
                                .fixedSize(horizontal: false, vertical: true)
                                
                                // 流式翻译（始终占位，防止闪烁）
                                let pendingTranslation = manager.lineBuffer.pendingTranslation
                                Text(pendingTranslation.isEmpty ? " " : pendingTranslation)
                                    .font(.system(size: CaptionDesign.translatedFontSize, weight: .regular))
                                    .foregroundColor(
                                        CaptionDesign.textSecondary.opacity(pendingTranslation.isEmpty ? 0 : 0.7)
                                    )
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .animation(.easeOut(duration: 0.2), value: pendingTranslation)
                            }
                            .transition(.opacity)  // 🔥 纯 fade in/out
                        }
                        
                        // 底部占位
                        Color.clear.frame(height: CaptionDesign.contentBottomPadding)
                    }
                    .padding(CaptionDesign.padding)
                    .textSelection(.enabled)  // 允许选中文字
                }
                .frame(height: CaptionDesign.collapsedContentHeight * 2.5)
                .mask(LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.3), location: 0.08),
                        .init(color: .black.opacity(0.7), location: 0.15),
                        .init(color: .black, location: 0.25),
                        .init(color: .black, location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .onChange(of: manager.lineBuffer.items.last?.id) { _, _ in
                    // 用户选中文本时暂停自动滚动
                    if isAtBottom && !isUserSelecting {
                        scrollTrigger += 1
                    }
                }
                .onChange(of: manager.lineBuffer.pendingText) { _, _ in
                    if isAtBottom && !isUserSelecting {
                        scrollTrigger += 1
                    }
                }
                .onChange(of: scrollTrigger) { _, _ in
                    // 通过改变 scrollTrigger 触发 NSScrollView 的更新
                }
            }
        }
    }
    
    /// 展开状态 - 复用折叠模式设计，高度更大
    private var expandedContent: some View {
        AppKitScrollView(isAtBottom: $isAtBottom, scrollTrigger: scrollTrigger) {
            // 🔥 移除 Spacer，避免内容变化时 Spacer 高度重算导致滚动跳变
            VStack(alignment: .leading, spacing: 16) {
                // 已确定的句子 - 使用 CaptionItemView 独立组件

                // 🔥 方案 F: 三层防御 - CaptionItem 是 class + @ObservedObject 隔离
                ForEach(manager.lineBuffer.items) { item in
                    let isNew = !appearedItemIDs.contains(item.id)
                    CaptionItemView(
                        item: item,
                        isNew: isNew,
                        translationFontSize: CaptionDesign.translatedFontSize,
                        translationColor: CaptionDesign.textSecondary
                    ) {
                        captionText(for: item.original, opacity: isNew ? 0.7 : 1.0)
                    }
                    .opacity(isNew ? 0.7 : 1.0)
                    .animation(.easeOut(duration: 0.3), value: isNew)
                    .onAppear { 
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            appearedItemIDs.insert(item.id)
                        }
                    }
                }
                
                // 正在输入的流式文本
                // 🔥 用 pendingLineActive 而不是 isEmpty,防止转录回退时整行消失导致布局跳动
                if manager.lineBuffer.pendingLineActive {
                    let displayText = manager.lineBuffer.displayPendingText
                    let pendingTranslation = manager.lineBuffer.pendingTranslation
                    VStack(alignment: .leading, spacing: 4) {
                        // 🔥 修复：始终保留 VocabularyHighlightText，避免类型切换导致视图重建
                        VocabularyHighlightText(
                            text: displayText.isEmpty ? " " : displayText,
                            fontSize: CaptionDesign.fontSize,
                            opacity: displayText.isEmpty ? 0 : 0.7,
                            onSelectionStarted: {
                                isUserSelecting = true
                                manager.lineBuffer.setUserInteracting(true)
                            },
                            onSelectionEnded: {
                                isUserSelecting = false
                                manager.lineBuffer.setUserInteracting(false)
                            },
                            onTextSelected: { selectedText, screenPoint in
                                handleTextSelected(selectedText, at: screenPoint)
                            },
                            onWordClicked: { word, screenPoint in
                                handleWordClicked(word, at: screenPoint)
                            },
                            refreshTrigger: vocabularyRefreshTrigger,
                            highlightedWord: highlightedWord
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        
                        Text(pendingTranslation.isEmpty ? " " : pendingTranslation)
                            .font(.system(size: CaptionDesign.translatedFontSize, weight: .regular))
                            .foregroundColor(
                                CaptionDesign.textSecondary.opacity(pendingTranslation.isEmpty ? 0 : 0.7)
                            )
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .animation(.easeOut(duration: 0.2), value: pendingTranslation)
                    }
                    .transition(.opacity)  // 🔥 纯 fade in/out
                }
                
                // 底部占位
                Color.clear.frame(height: CaptionDesign.expandedBottomPadding)
            }
            .padding(CaptionDesign.padding)
            .textSelection(.enabled)
        }
        .frame(height: 400)
        .onChange(of: manager.lineBuffer.items.last?.id) { _, _ in
            if isAtBottom && !isUserSelecting { scrollTrigger += 1 }
        }
        .onChange(of: manager.lineBuffer.pendingText) { _, _ in
            if isAtBottom && !isUserSelecting { scrollTrigger += 1 }
        }
    }
    
    // MARK: - Components

    /// 字幕文本（带生词高亮 + 右键菜单 + 颜色渐变 + 选中工具栏 + 单词点击查词）
    @ViewBuilder
    private func captionText(for original: String, opacity: CGFloat = 1.0) -> some View {
        VocabularyHighlightText(
            text: original,
            fontSize: CaptionDesign.fontSize,
            opacity: opacity,
            onSelectionStarted: {
                isUserSelecting = true
                manager.lineBuffer.setUserInteracting(true)
            },
            onSelectionEnded: {
                isUserSelecting = false
                manager.lineBuffer.setUserInteracting(false)
            },
            onTextSelected: { selectedText, screenPoint in
                handleTextSelected(selectedText, at: screenPoint)
            },
            onWordClicked: { word, screenPoint in
                handleWordClicked(word, at: screenPoint)
            },
            refreshTrigger: vocabularyRefreshTrigger,
            highlightedWord: highlightedWord  // 🔥 传入高亮单词
        )
        .fixedSize(horizontal: false, vertical: true)
    }
    
    /// 处理文本选中，显示 SelectionToolbar
    private func handleTextSelected(_ text: String, at screenPoint: CGPoint) {
        // 创建选择上下文
        let context = SelectionContext(
            selectedText: text,
            selectionBounds: CGRect(x: screenPoint.x - 50, y: screenPoint.y, width: 100, height: 20),
            sourceAppBundleId: Bundle.main.bundleIdentifier ?? "",
            sourceAppName: "SpokenAnyWhere"
        )
        
        // 显示工具栏
        dependencies.showSelectionToolbar(context, screenPoint)
    }
    
    /// 处理单词点击，调用统一查词服务并在选择工具栏中显示结果
    private func handleWordClicked(_ word: String, at screenPoint: CGPoint) {
        // 🔥 设置高亮单词
        highlightedWord = word

        // 🔥 设置用户交互状态，防止 clearPending 时整行消失
        isUserSelecting = true
        manager.lineBuffer.setUserInteracting(true)
        
        // 🔥 在后台异步查词，查词完成后才显示窗口
        Task { @MainActor in
            defer {
                // 🔥 交互结束，恢复状态
                isUserSelecting = false
                manager.lineBuffer.setUserInteracting(false)
            }

            // 创建选择上下文
            let context = SelectionContext(
                selectedText: word,
                selectionBounds: CGRect(x: screenPoint.x - 50, y: screenPoint.y, width: 100, height: 20),
                sourceAppBundleId: Bundle.main.bundleIdentifier ?? "",
                sourceAppName: "SpokenAnyWhere"
            )
            
            if let result = await dependencies.lookupWord(word) {
                // 转换为 DictionaryData
                let senses = result.senses.map { sense in
                    DictionarySense(
                        pos: sense.pos,
                        chinese: sense.chinese,
                        english: sense.english,
                        examples: sense.examples.isEmpty ? nil : sense.examples
                    )
                }
                
                let data = DictionaryData(
                    word: result.word,
                    phonetic: result.phonetic,
                    senses: senses,
                    lemma: result.lemma,
                    lemmaInfo: nil
                )
                
                await dependencies.showDictionaryResult(data, word, context, screenPoint)
            } else {
                await dependencies.showDictionaryError(word, context, screenPoint)
            }
        }
    }
    
    /// 底部拖动指示器
    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: CaptionDesign.dragIndicatorHeight / 2)
            .fill(CaptionDesign.dragIndicatorColor)
            .frame(width: CaptionDesign.dragIndicatorWidth, height: CaptionDesign.dragIndicatorHeight)
            .padding(.bottom, 8)
    }
    
    /// Hover 工具栏
    /// 样式参考 HoverCloseButton：hover 时圆形 → 圆角方形 + 背景变亮
    private var hoverToolbar: some View {
        let buttonSize: CGFloat = 24
        let cornerRadius: CGFloat = buttonSize * 0.27  // hover 时的圆角
        
        return HStack(spacing: 8) {
            // 复制全部内容（复制后变 checkmark）
            Button {
                copyAllContent()
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCopied = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCopied = false
                    }
                }
            } label: {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle((isCopyHovered || isCopied) ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                    .frame(width: buttonSize, height: buttonSize)
                    .background((isCopyHovered || isCopied) ? DS.Colors.buttonHover : Color.clear)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: isCopyHovered || isCopied ? cornerRadius : buttonSize / 2
                        )
                    )
                    .animation(.easeInOut(duration: 0.2), value: isCopyHovered)
                    .animation(.easeInOut(duration: 0.2), value: isCopied)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isCopyHovered = hovering
            }
            .help("复制全部内容")
            
            // 展开/收起
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isExpandHovered ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                    .frame(width: buttonSize, height: buttonSize)
                    .background(isExpandHovered ? DS.Colors.buttonHover : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: isExpandHovered ? cornerRadius : buttonSize / 2))
                    .animation(.easeInOut(duration: 0.2), value: isExpandHovered)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isExpandHovered = hovering
            }
            
            // 关闭
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isCloseHovered ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                    .frame(width: buttonSize, height: buttonSize)
                    .background(isCloseHovered ? DS.Colors.buttonHover : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: isCloseHovered ? cornerRadius : buttonSize / 2))
                    .animation(.easeInOut(duration: 0.2), value: isCloseHovered)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isCloseHovered = hovering
            }
        }
    }
    
    /// 复制全部内容到剪贴板
    /// 格式：一行英语（生词用 <word> 标记）+ 一行翻译
    private func copyAllContent() {
        // 🔥 快照当前数据状态，确保复制的一致性
        // 虽然在 MainActor 运行不会崩溃，但避免复制过程中数组发生变化
        let itemsSnapshot = manager.lineBuffer.items
        let pendingTextSnapshot = manager.lineBuffer.pendingText
        let pendingTranslationSnapshot = manager.lineBuffer.pendingTranslation
        
        var lines: [String] = []
        
        for item in itemsSnapshot {
            // 原文：标记生词（直接复用 Service 层的高性能正则）
            let markedOriginal = dependencies.markVocabulary(item.original)
            lines.append(markedOriginal)
            
            // 译文
            if let translation = item.translation, !translation.isEmpty {
                lines.append(translation)
            }
            
            // 空行分隔
            lines.append("")
        }
        
        // 当前正在输入的内容
        if !pendingTextSnapshot.isEmpty {
            let markedPending = dependencies.markVocabulary(pendingTextSnapshot)
            lines.append(markedPending)
            if !pendingTranslationSnapshot.isEmpty {
                lines.append(pendingTranslationSnapshot)
            }
        }
        
        let content = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }

    // MARK: - Background & Border

    /// 阴影与 hover 光晕，独立于卡片背景，避免被裁剪
    private var shadowAndGlowLayer: some View {
        ZStack {
            // 默认阴影（始终存在，提供层次感）
            RoundedRectangle(cornerRadius: CaptionDesign.cornerRadius)
                .fill(Color.black.opacity(0.001))
                .shadow(
                    color: DS.Shadow.caption.color,
                    radius: CaptionDesign.shadowRadius,
                    x: DS.Shadow.caption.x,
                    y: DS.Shadow.caption.y
                )

            // Hover 光晕效果（仅 hover 时显示）
            RoundedRectangle(cornerRadius: CaptionDesign.cornerRadius)
                .fill(Color.clear)
                .shadow(
                    color: isHovering ? CaptionDesign.glowColor : .clear,
                    radius: CaptionDesign.glowRadius,
                    x: 0,
                    y: 0
                )
        }
        .allowsHitTesting(false)
    }

    /// 卡片背景 - 毛玻璃 + 深色叠加
    /// 🔥 使用内部 clipShape 确保 VisualEffectBlur (NSViewRepresentable) 被正确裁剪
    private var cardBackground: some View {
        ZStack {
            // 毛玻璃效果
            VisualEffectBlur(material: .hudWindow, cornerRadius: CaptionDesign.cornerRadius)
            // 深色叠加
            CaptionDesign.cardBackground
        }
        .clipShape(RoundedRectangle(cornerRadius: CaptionDesign.cornerRadius))
    }
    
    /// 卡片边框 - hover 时变白色
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: CaptionDesign.cornerRadius)
            .stroke(
                isHovering ? CaptionDesign.glowBorderColor : CaptionDesign.borderColor,
                lineWidth: isHovering ? CaptionDesign.glowBorderWidth : 1
            )
    }
}

// MARK: - Translation Task Modifier

/// 翻译任务修饰符（macOS 15+）
/// 封装 .translationTask 以处理版本兼容性
struct TranslationTaskModifier: ViewModifier {
    @ObservedObject var manager: LiveCaptionManager
    @ObservedObject var translator: TranslationService
    var onTranslationTriggered: () -> Void
    
    func body(content: Content) -> some View {
        Group {
            if #available(macOS 15.0, *) {
                content
                    .modifier(TranslationTaskModifier15(
                        manager: manager,
                        translator: translator
                    ))
            } else {
                content
            }
        }
    }
}

/// macOS 15+ 专用的翻译修饰符
@available(macOS 15.0, *)
struct TranslationTaskModifier15: ViewModifier {
    @ObservedObject var manager: LiveCaptionManager
    @ObservedObject var translator: TranslationService
    
    func body(content: Content) -> some View {
        content
            .translationTask(translator.configuration) { session in
                await performTranslation(session: session)
            }
    }
    
    private func performTranslation(session: TranslationSession) async {
        // 找到最后一个未翻译的 item，只提取必要的 Sendable 数据
        guard let itemData = await MainActor.run(body: { () -> (UUID, String)? in
            if let item = manager.lineBuffer.items.last(where: { $0.translation == nil }) {
                return (item.id, item.original)
            }
            return nil
        }) else { return }
        
        let itemId = itemData.0
        let textToTranslate = itemData.1
        guard !textToTranslate.isEmpty else { return }
        
        do {
            let response = try await session.translate(textToTranslate)
            await MainActor.run {
                manager.lineBuffer.updateTranslation(id: itemId, translation: response.targetText)
            }
        } catch {
            // 翻译失败，静默处理
        }
    }
}

// MARK: - Preview

#Preview("Live Caption Card") {
    ZStack {
        // 背景模拟
        LinearGradient(
            colors: [
                DS.Colors.accentGradientStart.opacity(0.3),
                DS.Colors.accentGradientEnd.opacity(0.3)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack {
            Spacer()
            LiveCaptionView(
                manager: LiveCaptionManager.makePreview(),
                onClose: {},
                translator: .makePreview(),
                dependencies: .preview
            )
            .padding(.bottom, 60)
        }
    }
    .frame(width: 800, height: 600)
}
