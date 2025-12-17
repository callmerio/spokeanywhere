import SwiftUI
import AppKit

// MARK: - Vocabulary Highlight Text

/// 支持生词高亮和右键菜单的字幕文本视图
/// - 自动高亮 VocabularyService 中的生词（橙色文字）
/// - 右键菜单支持「添加生词」
/// - 选中文本后显示选择工具栏
struct VocabularyHighlightText: NSViewRepresentable {
    
    let text: String
    var fontSize: CGFloat = 18
    var textColor: NSColor = NSColor(red: 249/255, green: 250/255, blue: 251/255, alpha: 1)
    var opacity: CGFloat = 1.0
    
    /// 当用户开始选择文本时的回调（用于暂停滚动）
    var onSelectionStarted: (() -> Void)?
    /// 当用户结束选择文本时的回调
    var onSelectionEnded: (() -> Void)?
    /// 当用户完成选择文本时的回调（用于显示工具栏）
    var onTextSelected: ((String, CGPoint) -> Void)?
    
    /// 用于触发刷新的版本号（生词列表变化时更新）
    var refreshTrigger: Int = 0
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            onSelectionStarted: onSelectionStarted,
            onSelectionEnded: onSelectionEnded,
            onTextSelected: onTextSelected
        )
    }
    
    func makeNSView(context: Context) -> VocabularyTextView {
        let textView = VocabularyTextView(usingTextLayoutManager: false)
        
        // 基础配置
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        
        // 自适应高度
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        
        // 设置 delegate 和 coordinator 引用
        textView.delegate = context.coordinator
        textView.coordinator = context.coordinator
        
        // 初始渲染
        updateTextContent(textView)
        
        return textView
    }
    
    func updateNSView(_ textView: VocabularyTextView, context: Context) {
        // 🔥 关键：每次更新时同步回调到 Coordinator（SwiftUI 视图重建时回调可能变化）
        context.coordinator.onSelectionStarted = onSelectionStarted
        context.coordinator.onSelectionEnded = onSelectionEnded
        context.coordinator.onTextSelected = onTextSelected
        
        // 内容变化或生词列表变化时更新
        let needsUpdate = textView.string != text || textView.lastRefreshTrigger != refreshTrigger
        
        if needsUpdate {
            textView.lastRefreshTrigger = refreshTrigger
            updateTextContent(textView)
            textView.invalidateIntrinsicContentSize()
        }
    }
    
    static func dismantleNSView(_ nsView: VocabularyTextView, coordinator: Coordinator) {
        // 清理资源（当前无需额外清理，保留以备扩展）
        nsView.delegate = nil
    }
    
    /// 更新文本内容（带高亮）
    private func updateTextContent(_ textView: NSTextView) {
        let font = NSFont.systemFont(ofSize: fontSize)
        let color = textColor.withAlphaComponent(opacity)
        
        // 基础属性
        let attributedString = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color
            ]
        )
        
        // 应用生词高亮（橙色文字 + 略微加粗）
        let highlightRanges = VocabularyService.shared.highlightRanges(in: text)
        
        for range in highlightRanges {
            guard range.location + range.length <= text.utf16.count else { continue }
            
            attributedString.addAttributes([
                .foregroundColor: NSColor.orange,
                .font: NSFont.systemFont(ofSize: fontSize, weight: .medium)
            ], range: range)
        }
        
        textView.textStorage?.setAttributedString(attributedString)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, NSTextViewDelegate {
        
        var onSelectionStarted: (() -> Void)?
        var onSelectionEnded: (() -> Void)?
        var onTextSelected: ((String, CGPoint) -> Void)?
        private var isSelecting = false
        
        /// 🔥 选中防抖：选中变化停止 300ms 后触发工具栏
        private var selectionDebounceTimer: Timer?
        private weak var lastTextView: NSTextView?
        
        /// 翻译缓存（word -> translation）
        private static var translationCache: [String: String] = [:]
        /// 正在加载的单词
        private static var loadingWords: Set<String> = []
        
        init(onSelectionStarted: (() -> Void)?, onSelectionEnded: (() -> Void)?, onTextSelected: ((String, CGPoint) -> Void)?) {
            self.onSelectionStarted = onSelectionStarted
            self.onSelectionEnded = onSelectionEnded
            self.onTextSelected = onTextSelected
            super.init()
        }
        
        // MARK: - Selection Tracking
        
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            let hasSelection = textView.selectedRange().length > 0
            if hasSelection && !isSelecting {
                isSelecting = true
                onSelectionStarted?()
            } else if !hasSelection && isSelecting {
                isSelecting = false
                onSelectionEnded?()
            }
            
            // 🔥 选中防抖：有选中时启动定时器，300ms 后触发工具栏
            selectionDebounceTimer?.invalidate()
            if hasSelection {
                lastTextView = textView
                selectionDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                    guard let self = self, let textView = self.lastTextView else { return }
                    self.handleSelectionCompleted(in: textView)
                }
            }
        }
        
        /// 由 VocabularyTextView.mouseUp 调用，选择完成时触发工具栏
        func handleSelectionCompleted(in textView: NSTextView) {
            guard let onTextSelected = onTextSelected else { return }
            
            let selectedRange = textView.selectedRange()
            guard selectedRange.length > 0,
                  let selectedText = (textView.string as NSString?)?.substring(with: selectedRange),
                  !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            
            // 获取选中文本的屏幕位置
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }
            
            let glyphRange = layoutManager.glyphRange(forCharacterRange: selectedRange, actualCharacterRange: nil)
            let selectionRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            
            // 转换为屏幕坐标
            let rectInTextView = NSRect(
                x: selectionRect.origin.x + textView.textContainerOrigin.x,
                y: selectionRect.origin.y + textView.textContainerOrigin.y,
                width: selectionRect.width,
                height: selectionRect.height
            )
            
            if let window = textView.window {
                let rectInWindow = textView.convert(rectInTextView, to: nil)
                let rectOnScreen = window.convertToScreen(rectInWindow)
                
                // 工具栏显示在选中文本下方中央
                let screenPoint = CGPoint(
                    x: rectOnScreen.midX,
                    y: rectOnScreen.minY - 8
                )
                
                let trimmedText = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
                onTextSelected(trimmedText, screenPoint)
            }
        }
        
        // MARK: - Context Menu
        
        func textView(_ textView: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
            let selectedRange = textView.selectedRange()
            
            // 无选中文本时返回默认菜单
            guard selectedRange.length > 0,
                  let selectedText = (textView.string as NSString?)?.substring(with: selectedRange),
                  !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return menu
            }
            
            let trimmedText = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 创建新菜单
            let newMenu = NSMenu()
            
            // 判断是否已是生词，显示对应菜单项
            let isVocabulary = VocabularyService.shared.contains(trimmedText)
            
            if isVocabulary {
                // 移除生词
                let removeItem = NSMenuItem(
                    title: "移除生词",
                    action: #selector(removeFromVocabulary(_:)),
                    keyEquivalent: ""
                )
                removeItem.target = self
                removeItem.representedObject = trimmedText
                removeItem.image = NSImage(systemSymbolName: "star.slash", accessibilityDescription: nil)
                newMenu.addItem(removeItem)
            } else {
                // 添加生词
                let addItem = NSMenuItem(
                    title: "添加生词",
                    action: #selector(addToVocabulary(_:)),
                    keyEquivalent: ""
                )
                addItem.target = self
                addItem.representedObject = trimmedText
                addItem.image = NSImage(systemSymbolName: "star", accessibilityDescription: nil)
                newMenu.addItem(addItem)
            }
            
            // 翻译菜单项（动态显示翻译结果）
            let translationItem = createTranslationMenuItem(for: trimmedText)
            newMenu.addItem(translationItem)
            
            // 分隔符
            newMenu.addItem(NSMenuItem.separator())
            
            // 保留系统菜单项（复制等）
            for item in menu.items {
                if let copy = item.copy() as? NSMenuItem {
                    newMenu.addItem(copy)
                }
            }
            
            return newMenu
        }
        
        @objc func addToVocabulary(_ sender: NSMenuItem) {
            guard let word = sender.representedObject as? String else { return }
            
            Task { @MainActor in
                VocabularyService.shared.add(word)
                // 操作完成后恢复滚动状态
                self.resetSelectionState()
            }
        }
        
        @objc func removeFromVocabulary(_ sender: NSMenuItem) {
            guard let word = sender.representedObject as? String else { return }
            
            Task { @MainActor in
                // 通过词查找对应 ID 再删除
                if let item = VocabularyService.shared.items.first(where: { 
                    $0.word.lowercased() == word.lowercased() 
                }) {
                    VocabularyService.shared.remove(item.id)
                }
                // 操作完成后恢复滚动状态
                self.resetSelectionState()
            }
        }
        
        /// 重置选中状态，恢复自动滚动
        private func resetSelectionState() {
            if isSelecting {
                isSelecting = false
                onSelectionEnded?()
            }
        }
        
        // MARK: - Translation Menu Item
        
        /// 创建翻译菜单项（动态显示翻译结果，加载完成后自动更新）
        private func createTranslationMenuItem(for word: String) -> NSMenuItem {
            let lowercaseWord = word.lowercased()
            
            // 检查缓存
            if let cached = Self.translationCache[lowercaseWord] {
                let item = NSMenuItem(
                    title: "翻译: \(cached)",
                    action: nil,
                    keyEquivalent: ""
                )
                item.image = NSImage(systemSymbolName: "character.book.closed", accessibilityDescription: nil)
                return item
            }
            
            // 没有缓存，显示加载中并异步获取
            let item = NSMenuItem(
                title: "翻译: 加载中...",
                action: nil,
                keyEquivalent: ""
            )
            item.image = NSImage(systemSymbolName: "character.book.closed", accessibilityDescription: nil)
            
            // 异步获取翻译并更新菜单项
            if !Self.loadingWords.contains(lowercaseWord) {
                Self.loadingWords.insert(lowercaseWord)
                
                Task { @MainActor in
                    let result = await DictionaryAPIService.shared.lookup(lowercaseWord)
                    Self.loadingWords.remove(lowercaseWord)
                    
                    switch result {
                    case .success(let data):
                        // 构建翻译显示文本
                        let translation = Self.buildTranslationDisplay(from: data)
                        Self.translationCache[lowercaseWord] = translation
                        
                        // 动态更新菜单项（如果菜单仍然显示）
                        item.title = "翻译: \(translation)"
                    case .failure:
                        // 查询失败，显示错误
                        item.title = "翻译: 未找到"
                    }
                }
            }
            
            return item
        }
        
        /// 构建翻译显示文本（支持词形变化显示原型释义）
        /// 格式：有 lemmaInfo 时 → "第三人称单数 sustain v. 维持"
        ///      无 lemmaInfo 时 → "v. 维持"
        private static func buildTranslationDisplay(from data: DictionaryData) -> String {
            // 优先使用原型释义
            let senses = data.effectiveSenses
            guard let firstSense = senses.first, let chinese = firstSense.chinese else {
                return "无释义"
            }
            
            let posDisplay = firstSense.posDisplay
            let senseText = posDisplay.isEmpty ? chinese : "\(posDisplay) \(chinese)"
            
            // 如果有词形信息，添加前缀
            if let formType = data.formTypeDisplay, let lemma = data.lemmaWord {
                return "\(formType) \(lemma) \(senseText)"
            }
            
            return senseText
        }
    }
}

// MARK: - Vocabulary Text View

/// 自定义 NSTextView，支持 intrinsicContentSize 自适应高度 + mouseUp 触发选择工具栏
final class VocabularyTextView: NSTextView {
    
    /// 用于检测生词列表是否变化
    var lastRefreshTrigger: Int = 0
    
    /// Coordinator 引用，用于在 mouseUp 时触发工具栏
    weak var coordinator: VocabularyHighlightText.Coordinator?
    
    convenience init(usingTextLayoutManager _: Bool) {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()  // 使用标准 LayoutManager
        let textContainer = NSTextContainer()
        
        textContainer.widthTracksTextView = true
        textContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        self.init(frame: .zero, textContainer: textContainer)
    }
    
    override var intrinsicContentSize: NSSize {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer else {
            return super.intrinsicContentSize
        }
        
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        
        return NSSize(
            width: NSView.noIntrinsicMetric,
            height: ceil(usedRect.height)
        )
    }
    
    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
    }
    
    // MARK: - 关键：重写 mouseUp 直接触发工具栏
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        
        // 选择完成后立即触发工具栏
        if selectedRange().length > 0 {
            coordinator?.handleSelectionCompleted(in: self)
        }
    }
}

// MARK: - Preview

#Preview("Vocabulary Highlight") {
    VStack(alignment: .leading, spacing: 16) {
        VocabularyHighlightText(
            text: "Hello, Claude is an AI assistant made by Anthropic.",
            fontSize: 18
        )
        .frame(width: 400)
        
        VocabularyHighlightText(
            text: "This is a test sentence with some vocabulary words.",
            fontSize: 16,
            opacity: 0.7
        )
        .frame(width: 400)
    }
    .padding()
    .background(Color.black)
}
