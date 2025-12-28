import SwiftUI
import AppKit
import OSLog

private typealias DS = DesignTokens

private let vocabTextLogger = Logger(subsystem: "com.spokeanywhere", category: "VocabularyText")

// MARK: - Vocabulary Highlight Text

/// 支持生词高亮和右键菜单的字幕文本视图
/// - 自动高亮 VocabularyService 中的生词（橙色文字）
/// - 右键菜单支持「添加生词」
/// - 选中文本后显示选择工具栏
struct VocabularyHighlightText: NSViewRepresentable {
    
    let text: String
    var fontSize: CGFloat = 18
    var textColor: NSColor = DS.Colors.NS.textPrimary
    var opacity: CGFloat = 1.0
    
    /// 当用户开始选择文本时的回调（用于暂停滚动）
    var onSelectionStarted: (() -> Void)?
    /// 当用户结束选择文本时的回调
    var onSelectionEnded: (() -> Void)?
    /// 当用户完成选择文本时的回调（用于显示工具栏）
    var onTextSelected: ((String, CGPoint) -> Void)?
    /// 当用户点击单词时的回调（用于查词）
    var onWordClicked: ((String, CGPoint) -> Void)?
    
    /// 用于触发刷新的版本号（生词列表变化时更新）
    var refreshTrigger: Int = 0
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            onSelectionStarted: onSelectionStarted,
            onSelectionEnded: onSelectionEnded,
            onTextSelected: onTextSelected,
            onWordClicked: onWordClicked
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
        context.coordinator.onWordClicked = onWordClicked
        
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
                .foregroundColor: DS.Colors.NS.warning,
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
        var onWordClicked: ((String, CGPoint) -> Void)?
        private var isSelecting = false
        
        /// 🔥 选中防抖：选中变化停止 300ms 后触发工具栏
        private var selectionDebounceTimer: Timer?
        private weak var lastTextView: NSTextView?
        
        /// 翻译缓存（word -> translation）
        private static var translationCache: [String: String] = [:]
        /// 正在加载的单词
        private static var loadingWords: Set<String> = []
        
        init(
            onSelectionStarted: (() -> Void)?,
            onSelectionEnded: (() -> Void)?,
            onTextSelected: ((String, CGPoint) -> Void)?,
            onWordClicked: ((String, CGPoint) -> Void)?
        ) {
            self.onSelectionStarted = onSelectionStarted
            self.onSelectionEnded = onSelectionEnded
            self.onTextSelected = onTextSelected
            self.onWordClicked = onWordClicked
            super.init()
        }
        
        // MARK: - Selection Tracking
        
        /// 上次选中变化时间，用于检测双击
        private var lastSelectionTime: Date = .distantPast
        private var lastSelectedWord: String?
        
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            let selectedRange = textView.selectedRange()
            let hasSelection = selectedRange.length > 0
            
            if hasSelection && !isSelecting {
                isSelecting = true
                onSelectionStarted?()
            } else if !hasSelection && isSelecting {
                isSelecting = false
                onSelectionEnded?()
            }
            
            // 🔥 检测双击选词：如果选中的是一个完整单词，且距离上次选中时间 < 500ms
            // 这意味着用户双击了一个单词，同时触发查词
            if hasSelection && onWordClicked != nil {
                let nsString = textView.string as NSString
                let selectedText = nsString.substring(with: selectedRange).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // 检查是否是单个单词（无空格）
                let isSingleWord = !selectedText.contains(" ") && selectedText.count >= 2
                let isEnglishWord = selectedText.unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) }
                
                if isSingleWord && isEnglishWord {
                    let now = Date()
                    let timeSinceLastSelection = now.timeIntervalSince(lastSelectionTime)
                    
                    // 双击检测：500ms 内连续两次选中同一个单词
                    if timeSinceLastSelection < 0.5 && lastSelectedWord == selectedText {
                        vocabTextLogger.info("🖱️ Double-click word detected: '\(selectedText)'")
                        
                        // 计算屏幕坐标
                        if let window = textView.window,
                           let layoutManager = textView.layoutManager,
                           let textContainer = textView.textContainer {
                            let glyphRange = layoutManager.glyphRange(forCharacterRange: selectedRange, actualCharacterRange: nil)
                            let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                            let rectInView = NSRect(
                                x: rect.origin.x + textView.textContainerOrigin.x,
                                y: rect.origin.y + textView.textContainerOrigin.y,
                                width: rect.width,
                                height: rect.height
                            )
                            let rectInWindow = textView.convert(rectInView, to: nil)
                            let rectOnScreen = window.convertToScreen(rectInWindow)
                            let screenPoint = CGPoint(x: rectOnScreen.midX, y: rectOnScreen.minY - 8)
                            
                            vocabTextLogger.info("✅ Calling onWordClicked for '\(selectedText)' at \(screenPoint.x), \(screenPoint.y)")
                            onWordClicked?(selectedText, screenPoint)
                        }
                    }
                    
                    lastSelectedWord = selectedText
                    lastSelectionTime = now
                }
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
        
        // 🔥 添加双击手势识别器（单击被 NSTextView 选择行为消费，双击更可靠）
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClickGesture(_:)))
        clickGesture.numberOfClicksRequired = 2  // 双击触发查词
        clickGesture.delaysPrimaryMouseButtonEvents = false
        self.addGestureRecognizer(clickGesture)
        
        vocabTextLogger.info("✅ VocabularyTextView initialized, double-click gesture added")
    }
    
    /// 处理单击手势
    @objc private func handleClickGesture(_ gesture: NSClickGestureRecognizer) {
        let point = gesture.location(in: self)
        vocabTextLogger.info("🖱️ handleClickGesture at: \(point.x), \(point.y)")
        
        // 如果有选中文本（用户拖拽选择），不触发查词
        if selectedRange().length > 1 {
            vocabTextLogger.info("🖱️ Has selection (\(self.selectedRange().length)), skipping click handler")
            return
        }
        
        // 触发单词点击处理
        handleWordClickFromGesture(at: point)
    }
    
    /// 从手势识别器触发的单词点击处理
    private func handleWordClickFromGesture(at point: NSPoint) {
        guard let coordinator = coordinator else {
            vocabTextLogger.error("❌ coordinator is nil")
            return
        }
        
        guard coordinator.onWordClicked != nil else {
            vocabTextLogger.error("❌ onWordClicked callback is nil")
            return
        }
        
        guard let layoutManager = layoutManager,
              let textContainer = textContainer else {
            vocabTextLogger.error("❌ layoutManager or textContainer is nil")
            return
        }
        
        // 转换为文本容器坐标
        let textContainerOrigin = textContainerOrigin
        let locationInTextContainer = NSPoint(
            x: point.x - textContainerOrigin.x,
            y: point.y - textContainerOrigin.y
        )
        
        // 获取字符索引
        let characterIndex = layoutManager.characterIndex(
            for: locationInTextContainer,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        
        guard characterIndex < string.count else {
            vocabTextLogger.error("❌ characterIndex \(characterIndex) out of bounds (\(self.string.count))")
            return
        }
        
        // 找到单词边界
        let nsString = string as NSString
        let wordRange = nsString.rangeOfWord(at: characterIndex)
        
        guard wordRange.location != NSNotFound else {
            vocabTextLogger.error("❌ wordRange not found")
            return
        }
        
        let word = nsString.substring(with: wordRange)
        let trimmedWord = word.trimmingCharacters(in: .punctuationCharacters)
        
        vocabTextLogger.info("word: '\(word)', trimmed: '\(trimmedWord)'")
        
        guard trimmedWord.count >= 2 else {
            vocabTextLogger.warning("❌ word too short")
            return
        }
        
        // 检查是否是纯英文单词
        let isEnglishWord = trimmedWord.unicodeScalars.allSatisfy { 
            CharacterSet.letters.contains($0)
        }
        guard isEnglishWord else {
            vocabTextLogger.warning("❌ not an English word")
            return
        }
        
        // 计算屏幕坐标
        if let window = window {
            let rectInWindow = convert(NSRect(x: point.x, y: point.y, width: 1, height: 1), to: nil)
            let rectOnScreen = window.convertToScreen(rectInWindow)
            let screenPoint = CGPoint(x: rectOnScreen.midX, y: rectOnScreen.minY - 8)
            
            vocabTextLogger.info("✅ Calling onWordClicked for '\(trimmedWord)' at \(screenPoint.x), \(screenPoint.y)")
            coordinator.onWordClicked?(trimmedWord, screenPoint)
        } else {
            vocabTextLogger.error("❌ window is nil")
        }
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
    
    // MARK: - 单击查词（在 mouseDown 时立即触发）
    
    /// 记录 mouseDown 位置，用于判断是否为拖拽
    private var mouseDownLocation: NSPoint = .zero
    private var mouseDownTime: Date = Date()
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        mouseDownLocation = point
        mouseDownTime = Date()
        
        vocabTextLogger.info("🖱️ mouseDown at: \(point.x), \(point.y)")
        
        // 🔥 关键：在 super.mouseDown 之前触发查词
        // 因为 super.mouseDown 会启动选择模式并可能不返回（直到 mouseUp）
        if event.clickCount == 1 {
            // 单击 → 触发查词
            triggerWordLookup(at: point)
        }
        
        // 调用 super 让 NSTextView 处理选择
        super.mouseDown(with: event)
    }
    
    /// 触发单词查词
    private func triggerWordLookup(at point: NSPoint) {
        guard let coordinator = coordinator,
              coordinator.onWordClicked != nil,
              let layoutManager = layoutManager,
              let textContainer = textContainer else {
            vocabTextLogger.warning("❌ triggerWordLookup: missing coordinator or callback")
            return
        }
        
        // 转换为文本容器坐标
        let textContainerOrigin = textContainerOrigin
        let locationInTextContainer = NSPoint(
            x: point.x - textContainerOrigin.x,
            y: point.y - textContainerOrigin.y
        )
        
        // 获取字符索引
        let characterIndex = layoutManager.characterIndex(
            for: locationInTextContainer,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        
        guard characterIndex < string.count else {
            vocabTextLogger.warning("❌ characterIndex out of bounds")
            return
        }
        
        // 🔥 关键修复：验证点击是否在字符边界框内（与 hover 一致）
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: characterIndex)
        let glyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)
        
        // 如果点击位置在字形右侧太远（超出字形宽度），说明在空白区域
        let pointInGlyph = locationInTextContainer.x - glyphRect.origin.x
        if pointInGlyph > glyphRect.width + 5 || pointInGlyph < -5 {
            vocabTextLogger.info("❌ Click in blank area, not on glyph")
            return
        }
        
        // 找到单词边界
        let nsString = string as NSString
        let wordRange = nsString.rangeOfWord(at: characterIndex)
        
        guard wordRange.location != NSNotFound else {
            vocabTextLogger.warning("❌ wordRange not found")
            return
        }
        
        // 🔥 进一步验证：检查鼠标是否在整个单词的边界框内
        let wordGlyphRange = layoutManager.glyphRange(forCharacterRange: wordRange, actualCharacterRange: nil)
        let wordRect = layoutManager.boundingRect(forGlyphRange: wordGlyphRange, in: textContainer)
        
        // 添加少量容差 (2px)
        let expandedWordRect = wordRect.insetBy(dx: -2, dy: -2)
        if !expandedWordRect.contains(locationInTextContainer) {
            vocabTextLogger.info("❌ Click outside word bounds")
            return
        }
        
        let word = nsString.substring(with: wordRange)
        let trimmedWord = word.trimmingCharacters(in: .punctuationCharacters)
        
        // 过滤太短或非英文单词
        guard trimmedWord.count >= 2,
              trimmedWord.unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) }) else {
            return
        }
        
        // 计算屏幕坐标
        if let window = window {
            let rectInWindow = convert(NSRect(x: point.x, y: point.y, width: 1, height: 1), to: nil)
            let rectOnScreen = window.convertToScreen(rectInWindow)
            let screenPoint = CGPoint(x: rectOnScreen.midX, y: rectOnScreen.minY - 8)
            
            vocabTextLogger.info("✅ Calling onWordClicked for '\(trimmedWord)' at \(screenPoint.x), \(screenPoint.y)")
            coordinator.onWordClicked?(trimmedWord, screenPoint)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        print("🔍 [VocabularyText] 🖱️ mouseUp CALLED")
        super.mouseUp(with: event)
        
        let mouseUpLocation = convert(event.locationInWindow, from: nil)
        let distance = hypot(mouseUpLocation.x - mouseDownLocation.x, mouseUpLocation.y - mouseDownLocation.y)
        let duration = Date().timeIntervalSince(mouseDownTime)
        let hasSelection = selectedRange().length > 0
        
        // 判断是否为点击（距离 < 5px 且时间 < 300ms）
        let isClick = distance < 5 && duration < 0.3
        
        print("🔍 [VocabularyText] mouseUp: distance=\(distance), duration=\(duration), hasSelection=\(hasSelection), isClick=\(isClick)")
        
        // 🔥 修改逻辑：优先判断是否为短点击
        // 即使有选中文本，如果是短点击且选中长度 <= 1（可能是光标），也视为单词点击
        if isClick && selectedRange().length <= 1 {
            // 单击单词 → 触发查词
            print("🔍 [VocabularyText] Detected click, calling handleWordClick")
            handleWordClick(at: mouseUpLocation, event: event)
        } else if hasSelection {
            // 有选中文本 → 触发选择工具栏
            print("🔍 [VocabularyText] Has selection, calling handleSelectionCompleted")
            coordinator?.handleSelectionCompleted(in: self)
        }
    }
    
    /// 处理单词点击
    private func handleWordClick(at point: NSPoint, event: NSEvent) {
        print("🔍 [VocabularyText] handleWordClick called at: \(point)")
        
        guard let coordinator = coordinator else {
            print("🔍 [VocabularyText] ❌ coordinator is nil")
            return
        }
        
        guard coordinator.onWordClicked != nil else {
            print("🔍 [VocabularyText] ❌ onWordClicked callback is nil")
            return
        }
        
        guard let layoutManager = layoutManager,
              let textContainer = textContainer else {
            print("🔍 [VocabularyText] ❌ layoutManager or textContainer is nil")
            return
        }
        
        // 转换为文本容器坐标
        let textContainerOrigin = textContainerOrigin
        let locationInTextContainer = NSPoint(
            x: point.x - textContainerOrigin.x,
            y: point.y - textContainerOrigin.y
        )
        
        // 获取字符索引
        let characterIndex = layoutManager.characterIndex(
            for: locationInTextContainer,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        
        print("🔍 [VocabularyText] characterIndex: \(characterIndex), string.count: \(string.count)")
        
        guard characterIndex < string.count else {
            print("🔍 [VocabularyText] ❌ characterIndex out of bounds")
            return
        }
        
        // 找到单词边界
        let nsString = string as NSString
        let wordRange = nsString.rangeOfWord(at: characterIndex)
        
        guard wordRange.location != NSNotFound else {
            print("🔍 [VocabularyText] ❌ wordRange not found")
            return
        }
        
        let word = nsString.substring(with: wordRange)
        let trimmedWord = word.trimmingCharacters(in: .punctuationCharacters)
        
        print("🔍 [VocabularyText] word: '\(word)', trimmed: '\(trimmedWord)'")
        
        // 过滤太短的单词
        guard trimmedWord.count >= 2 else {
            print("🔍 [VocabularyText] ❌ word too short")
            return
        }
        
        // 检查是否是纯英文单词
        let isEnglishWord = trimmedWord.unicodeScalars.allSatisfy { 
            CharacterSet.letters.contains($0)
        }
        guard isEnglishWord else {
            print("🔍 [VocabularyText] ❌ not an English word")
            return
        }
        
        // 计算屏幕坐标
        if let window = window {
            let rectInWindow = convert(NSRect(x: point.x, y: point.y, width: 1, height: 1), to: nil)
            let rectOnScreen = window.convertToScreen(rectInWindow)
            let screenPoint = CGPoint(x: rectOnScreen.midX, y: rectOnScreen.minY - 8)
            
            print("🔍 [VocabularyText] ✅ Calling onWordClicked for '\(trimmedWord)' at \(screenPoint)")
            coordinator.onWordClicked?(trimmedWord, screenPoint)
        } else {
            print("🔍 [VocabularyText] ❌ window is nil")
        }
    }
    
    // MARK: - Hover 效果 (可选扩展)
    
    private var trackingArea: NSTrackingArea?
    private var hoveredWordRange: NSRange?
    private var originalAttributes: [NSAttributedString.Key: Any]?
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        
        let point = convert(event.locationInWindow, from: nil)
        updateHoverEffect(at: point)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        clearHoverEffect()
    }
    
    private func updateHoverEffect(at point: NSPoint) {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer,
              let textStorage = textStorage else { return }
        
        let textContainerOrigin = textContainerOrigin
        let locationInTextContainer = NSPoint(
            x: point.x - textContainerOrigin.x,
            y: point.y - textContainerOrigin.y
        )
        
        var fraction: CGFloat = 0
        let characterIndex = layoutManager.characterIndex(
            for: locationInTextContainer,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: &fraction
        )
        
        guard characterIndex < string.count else {
            clearHoverEffect()
            return
        }
        
        // 🔥 关键修复：验证鼠标是否真的在字符边界框内
        // fraction > 0.5 说明鼠标更靠近下一个字符，可能在空白区域
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: characterIndex)
        let glyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)
        
        // 如果点击位置在字形右侧太远（超出字形宽度），说明在空白区域
        let pointInGlyph = locationInTextContainer.x - glyphRect.origin.x
        if pointInGlyph > glyphRect.width + 5 || pointInGlyph < -5 {
            clearHoverEffect()
            return
        }
        
        let nsString = string as NSString
        let wordRange = nsString.rangeOfWord(at: characterIndex)
        
        guard wordRange.location != NSNotFound else {
            clearHoverEffect()
            return
        }
        
        // 🔥 进一步验证：检查鼠标是否在整个单词的边界框内
        let wordGlyphRange = layoutManager.glyphRange(forCharacterRange: wordRange, actualCharacterRange: nil)
        let wordRect = layoutManager.boundingRect(forGlyphRange: wordGlyphRange, in: textContainer)
        
        // 添加少量容差 (2px)
        let expandedWordRect = wordRect.insetBy(dx: -2, dy: -2)
        if !expandedWordRect.contains(locationInTextContainer) {
            clearHoverEffect()
            return
        }
        
        // 如果是同一个单词，不需要更新
        if let current = hoveredWordRange, NSEqualRanges(current, wordRange) {
            return
        }
        
        // 清除之前的高亮
        clearHoverEffect()
        
        // 检查是否是有效的英文单词
        let word = nsString.substring(with: wordRange).trimmingCharacters(in: .punctuationCharacters)
        let isEnglishWord = word.count >= 2 && word.unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) }
        
        guard isEnglishWord else { return }
        
        // 保存原始属性
        hoveredWordRange = wordRange
        originalAttributes = textStorage.attributes(at: wordRange.location, effectiveRange: nil)
        
        // 添加下划线效果（橙色，与生词高亮一致）
        textStorage.addAttributes([
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: DS.Colors.NS.warning.withAlphaComponent(0.7),
            .cursor: NSCursor.pointingHand
        ], range: wordRange)
        
        // 设置手型光标
        NSCursor.pointingHand.set()
    }
    
    private func clearHoverEffect() {
        guard let range = hoveredWordRange,
              let textStorage = textStorage else { return }
        
        // 移除下划线
        textStorage.removeAttribute(.underlineStyle, range: range)
        textStorage.removeAttribute(.underlineColor, range: range)
        textStorage.removeAttribute(.cursor, range: range)
        
        hoveredWordRange = nil
        originalAttributes = nil
        
        // 恢复默认光标
        NSCursor.iBeam.set()
    }
}

// MARK: - NSString Extension for Word Range

private extension NSString {
    func rangeOfWord(at index: Int) -> NSRange {
        guard index >= 0 && index < length else { return NSRange(location: NSNotFound, length: 0) }
        
        var start = index
        var end = index
        
        // 向前找单词起点
        while start > 0 {
            let char = character(at: start - 1)
            if !CharacterSet.letters.contains(UnicodeScalar(char)!) {
                break
            }
            start -= 1
        }
        
        // 向后找单词终点
        while end < length {
            let char = character(at: end)
            if !CharacterSet.letters.contains(UnicodeScalar(char)!) {
                break
            }
            end += 1
        }
        
        guard end > start else { return NSRange(location: NSNotFound, length: 0) }
        return NSRange(location: start, length: end - start)
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
    .background(DS.Colors.settingsBackground)
}
