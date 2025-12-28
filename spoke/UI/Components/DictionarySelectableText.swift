import SwiftUI

private typealias DS = DesignTokens
import AppKit

// MARK: - Simple Markdown Parser

/// 轻量级 Markdown 解析器，支持 **粗体**、*斜体*、`代码`
enum SimpleMarkdownParser {
    
    // MARK: - 字体缓存（避免重复调用 NSFontManager.convert）
    
    private static var fontCache: [String: NSFont] = [:]
    
    private static func cachedBoldFont(for font: NSFont) -> NSFont {
        let key = "bold-\(font.fontName)-\(font.pointSize)"
        if let cached = fontCache[key] { return cached }
        let bold = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        fontCache[key] = bold
        return bold
    }
    
    private static func cachedItalicFont(for font: NSFont) -> NSFont {
        let key = "italic-\(font.fontName)-\(font.pointSize)"
        if let cached = fontCache[key] { return cached }
        let italic = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        fontCache[key] = italic
        return italic
    }
    
    private static func cachedCodeFont(size: CGFloat) -> NSFont {
        let key = "code-\(size)"
        if let cached = fontCache[key] { return cached }
        let code = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        fontCache[key] = code
        return code
    }
    
    /// 将 Markdown 文本转换为 NSAttributedString
    static func parse(
        _ text: String,
        font: NSFont,
        foregroundColor: NSColor
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        // 基础属性
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: foregroundColor
        ]
        
        // 使用缓存的字体
        let boldFont = cachedBoldFont(for: font)
        let italicFont = cachedItalicFont(for: font)
        let codeFont = cachedCodeFont(size: font.pointSize)
        
        // 正则模式：匹配 **bold**、*italic*、`code`
        // 顺序很重要：先匹配 ** 再匹配 *
        let pattern = #"(\*\*|__)(.*?)\1|(\*|_)(.*?)\3|`([^`]+)`"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return NSAttributedString(string: text, attributes: baseAttributes)
        }
        
        var lastEnd = text.startIndex
        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        
        for match in matches {
            // 添加匹配前的普通文本
            let matchStart = text.index(text.startIndex, offsetBy: match.range.location)
            if lastEnd < matchStart {
                let plainText = String(text[lastEnd..<matchStart])
                result.append(NSAttributedString(string: plainText, attributes: baseAttributes))
            }
            
            // 判断匹配类型并添加格式化文本
            if match.range(at: 2).location != NSNotFound {
                // **粗体** 或 __粗体__
                let content = nsText.substring(with: match.range(at: 2))
                var attrs = baseAttributes
                attrs[.font] = boldFont
                result.append(NSAttributedString(string: content, attributes: attrs))
            } else if match.range(at: 4).location != NSNotFound {
                // *斜体* 或 _斜体_
                let content = nsText.substring(with: match.range(at: 4))
                var attrs = baseAttributes
                attrs[.font] = italicFont
                result.append(NSAttributedString(string: content, attributes: attrs))
            } else if match.range(at: 5).location != NSNotFound {
                // `代码`
                let content = nsText.substring(with: match.range(at: 5))
                var attrs = baseAttributes
                attrs[.font] = codeFont
                attrs[.backgroundColor] = DS.Colors.NS.codeBackground
                result.append(NSAttributedString(string: content, attributes: attrs))
            }
            
            // 更新 lastEnd
            lastEnd = text.index(text.startIndex, offsetBy: match.range.location + match.range.length)
        }
        
        // 添加剩余的普通文本
        if lastEnd < text.endIndex {
            let plainText = String(text[lastEnd...])
            result.append(NSAttributedString(string: plainText, attributes: baseAttributes))
        }
        
        return result
    }
}

// MARK: - Dictionary Selectable Text

/// 支持文本选择和「添加到词典」右键菜单的文本视图
/// 用于 Pipeline 卡片内的文本展示
struct DictionarySelectableText: NSViewRepresentable {
    let text: String
    var font: NSFont = .systemFont(ofSize: 13)
    var foregroundColor: NSColor = DS.Colors.NS.textPrimary
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeNSView(context: Context) -> DictionaryTextView {
        // 使用 TextKit 1 模式（macOS 12+ 默认是 TextKit 2，selectedTextAttributes 行为不同）
        let textView = DictionaryTextView(usingTextLayoutManager: false)
        
        // 配置文本视图
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textColor = foregroundColor
        textView.font = font
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        
        // 自适应高度配置
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        
        // 设置 delegate
        textView.delegate = context.coordinator
        
        // 设置初始内容（解析 Markdown）
        let attributedString = SimpleMarkdownParser.parse(text, font: font, foregroundColor: foregroundColor)
        textView.textStorage?.setAttributedString(attributedString)
        
        return textView
    }
    
    func updateNSView(_ textView: DictionaryTextView, context: Context) {
        // ❗️ 先比较文本是否变化，变化了才解析（避免重复解析导致卡死）
        guard textView.string != text else { return }
        
        // 解析 Markdown 并设置富文本
        let attributedString = SimpleMarkdownParser.parse(text, font: font, foregroundColor: foregroundColor)
        textView.textStorage?.setAttributedString(attributedString)
        // 内容变化后重新计算高度
        textView.invalidateIntrinsicContentSize()
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, NSTextViewDelegate {
        
        func textView(_ textView: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
            // 获取选中的文本
            let selectedRange = textView.selectedRange()
            
            guard selectedRange.length > 0,
                  let selectedText = (textView.string as NSString?)?.substring(with: selectedRange),
                  !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return menu
            }
            
            // 创建新菜单（保留原有菜单项）
            let newMenu = menu.copy() as! NSMenu
            
            // 在菜单顶部插入自定义项（位置 0 开始）
            var insertIndex = 0
            
            // 获取整句话作为训练短语
            let fullText = textView.string
            let menuContext: [String: Any] = [
                "selectedText": selectedText,
                "fullText": fullText
            ]
            
            // 添加「添加到词典」菜单项
            let addToDictionaryItem = NSMenuItem(
                title: "添加到词典",
                action: #selector(addToDictionary(_:)),
                keyEquivalent: ""
            )
            addToDictionaryItem.target = self
            addToDictionaryItem.representedObject = menuContext
            addToDictionaryItem.image = NSImage(systemSymbolName: "book.closed", accessibilityDescription: nil)
            newMenu.insertItem(addToDictionaryItem, at: insertIndex)
            insertIndex += 1
            
            // 添加「纠正为...」菜单项（将选中的错误文本映射到正确词形）
            let correctToItem = NSMenuItem(
                title: "纠正为...",
                action: #selector(correctTo(_:)),
                keyEquivalent: ""
            )
            correctToItem.target = self
            correctToItem.representedObject = menuContext
            correctToItem.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: nil)
            newMenu.insertItem(correctToItem, at: insertIndex)
            insertIndex += 1
            
            // 添加分隔符
            newMenu.insertItem(NSMenuItem.separator(), at: insertIndex)
            
            return newMenu
        }
        
        @objc func addToDictionary(_ sender: NSMenuItem) {
            guard let context = sender.representedObject as? [String: Any],
                  let selectedText = context["selectedText"] as? String else { return }
            let fullText = context["fullText"] as? String ?? ""
            
            // 发送通知，由 DictionaryService 处理
            NotificationCenter.default.post(
                name: .requestAddToDictionary,
                object: nil,
                userInfo: [
                    "word": selectedText,
                    "mode": "new",
                    "fullText": fullText  // 用于训练短语
                ]
            )
        }
        
        @objc func correctTo(_ sender: NSMenuItem) {
            guard let context = sender.representedObject as? [String: Any],
                  let selectedText = context["selectedText"] as? String else { return }
            let fullText = context["fullText"] as? String ?? ""
            
            // 发送通知，显示纠错弹窗
            NotificationCenter.default.post(
                name: .requestAddToDictionary,
                object: nil,
                userInfo: [
                    "word": selectedText,
                    "mode": "correction",
                    "fullText": fullText  // 用于训练短语
                ]
            )
        }
    }
}

// MARK: - Custom Layout Manager（自定义选中颜色）

/// 自定义 NSLayoutManager，覆盖选中区域的背景颜色绘制
final class SelectionColorLayoutManager: NSLayoutManager {
    
    /// 金黄色选中背景 #D79C00
    var selectionColor = DS.Colors.NS.highlightGold
    /// 选中文字颜色
    var selectedTextColor = DS.Colors.NS.textPrimary
    /// 选中文字外描边阴影
    var selectedTextShadow: NSShadow = {
        let shadow = NSShadow()
        shadow.shadowColor = DS.Colors.NS.selectionShadow
        shadow.shadowOffset = NSSize(width: 0, height: 0)  // 居中阴影
        shadow.shadowBlurRadius = 1.5  // 模糊半径模拟描边
        return shadow
    }()
    
    /// 覆盖背景绘制方法，自定义选中区域的背景颜色
    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        // 先调用父类绘制其他背景（不包括选中，因为我们禁用了系统选中样式）
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        
        // 手动绘制选中区域的背景
        guard let textView = self.firstTextView,
              let textContainer = self.textContainers.first else { return }
        
        for rangeValue in textView.selectedRanges {
            let selectedRange = rangeValue.rangeValue
            guard selectedRange.length > 0 else { continue }
            
            // 转换为 glyph range
            let glyphRange = self.glyphRange(forCharacterRange: selectedRange, actualCharacterRange: nil)
            
            // 只绘制与当前请求的 glyphsToShow 有交集的部分
            let intersection = NSIntersectionRange(glyphRange, glyphsToShow)
            guard intersection.length > 0 else { continue }
            
            // 枚举每一行片段并绘制
            self.enumerateLineFragments(forGlyphRange: intersection) { _, _, _, lineGlyphRange, _ in
                // 计算这一行中选中部分的边界
                let lineIntersection = NSIntersectionRange(lineGlyphRange, intersection)
                guard lineIntersection.length > 0 else { return }
                
                var selectionRect = self.boundingRect(forGlyphRange: lineIntersection, in: textContainer)
                selectionRect.origin.x += origin.x
                selectionRect.origin.y += origin.y
                
                // 绘制金黄色背景（带小圆角）
                self.selectionColor.setFill()
                let path = NSBezierPath(roundedRect: selectionRect, xRadius: 3, yRadius: 3)
                path.fill()
            }
        }
    }
    
    /// 覆盖文字绘制方法，为选中文字添加描边效果
    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        guard let textView = self.firstTextView else {
            super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
            return
        }
        
        // 收集选中的字符范围
        var selectedCharRanges: [NSRange] = []
        for rangeValue in textView.selectedRanges {
            let selectedRange = rangeValue.rangeValue
            if selectedRange.length > 0 {
                selectedCharRanges.append(selectedRange)
            }
        }
        
        // 如果没有选中，直接调用父类
        guard !selectedCharRanges.isEmpty else {
            super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
            return
        }
        
        // 为选中区域添加临时属性（白色文字 + 阴影外描边）
        for selectedRange in selectedCharRanges {
            let glyphRange = self.glyphRange(forCharacterRange: selectedRange, actualCharacterRange: nil)
            let intersection = NSIntersectionRange(glyphRange, glyphsToShow)
            if intersection.length > 0 {
                let charRange = self.characterRange(forGlyphRange: intersection, actualGlyphRange: nil)
                // 添加白色前景色
                self.addTemporaryAttribute(.foregroundColor, value: selectedTextColor, forCharacterRange: charRange)
                // 添加阴影（模拟外描边效果）
                self.addTemporaryAttribute(.shadow, value: selectedTextShadow, forCharacterRange: charRange)
            }
        }
        
        // 调用父类绘制
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        
        // 移除临时属性
        for selectedRange in selectedCharRanges {
            let glyphRange = self.glyphRange(forCharacterRange: selectedRange, actualCharacterRange: nil)
            let intersection = NSIntersectionRange(glyphRange, glyphsToShow)
            if intersection.length > 0 {
                let charRange = self.characterRange(forGlyphRange: intersection, actualGlyphRange: nil)
                self.removeTemporaryAttribute(.foregroundColor, forCharacterRange: charRange)
                self.removeTemporaryAttribute(.shadow, forCharacterRange: charRange)
            }
        }
    }
}

// MARK: - Dictionary Text View

/// 自定义 NSTextView，支持 intrinsicContentSize 自适应高度 + 自定义选中颜色
final class DictionaryTextView: NSTextView {
    
    /// 使用自定义 LayoutManager 创建
    convenience init(usingTextLayoutManager: Bool) {
        // 创建自定义的文本系统组件
        let textStorage = NSTextStorage()
        let layoutManager = SelectionColorLayoutManager()
        let textContainer = NSTextContainer()
        
        textContainer.widthTracksTextView = true
        textContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        self.init(frame: .zero, textContainer: textContainer)
        
        // 禁用系统选中样式，让自定义 LayoutManager 绘制
        self.selectedTextAttributes = [:]
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override var intrinsicContentSize: NSSize {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer else {
            return super.intrinsicContentSize
        }
        
        // 确保布局完成
        layoutManager.ensureLayout(for: textContainer)
        
        // 获取文本实际需要的高度
        let usedRect = layoutManager.usedRect(for: textContainer)
        
        return NSSize(
            width: NSView.noIntrinsicMetric,  // 宽度由父视图决定
            height: ceil(usedRect.height)      // 高度自适应内容
        )
    }
    
    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
    }
}

// MARK: - Add to Dictionary Handler

/// 处理「添加到词典」请求的管理器
@MainActor
final class AddToDictionaryHandler: ObservableObject {
    
    static let shared = AddToDictionaryHandler()
    
    @Published var isShowingAddSheet = false
    @Published var isShowingCorrectionSheet = false
    @Published var pendingWord = ""
    @Published var pendingFullText = ""  // 完整句子，用于训练短语
    
    private var observer: NSObjectProtocol?
    
    private init() {
        setupObserver()
    }
    
    private func setupObserver() {
        observer = NotificationCenter.default.addObserver(
            forName: .requestAddToDictionary,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleNotification(notification)
            }
        }
    }
    
    private func handleNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let word = userInfo["word"] as? String,
              let mode = userInfo["mode"] as? String else { return }
        
        pendingWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingFullText = (userInfo["fullText"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
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
            if let entry = DictionaryService.shared.addEntry(word: word) {
                // 如果有训练短语，记录下来
                if let phrase = trainingPhrase, !phrase.isEmpty {
                    DictionaryService.shared.addTrainingPhrase(phrase, to: entry.id)
                }
            }
        }
    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - Quick Add to Dictionary Sheet

/// 从 Pipeline 添加词条的快速弹窗
struct QuickAddToDictionarySheet: View {
    @Binding var isPresented: Bool
    let initialWord: String
    let fullText: String  // 完整句子，用于训练短语
    
    @State private var word: String
    @State private var correctionsText = ""
    @ObservedObject private var dictionaryService = DictionaryService.shared
    
    init(isPresented: Binding<Bool>, initialWord: String, fullText: String = "") {
        self._isPresented = isPresented
        self.initialWord = initialWord
        self.fullText = fullText
        self._word = State(initialValue: initialWord)
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
            Task { @MainActor in
                MessagePanelState.shared.addHighlightToLatestCard(
                    .dictionary(word: trimmedWord)
                )
            }
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
    
    @ObservedObject private var dictionaryService = DictionaryService.shared
    @State private var correctWord = ""  // 用户输入的正确词形
    @State private var selectedEntryId: UUID?
    @FocusState private var isInputFocused: Bool
    
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
        Task { @MainActor in
            MessagePanelState.shared.addHighlightToLatestCard(
                .correction(from: errorText, to: trimmedWord)
            )
        }
        
        isPresented = false
    }
}
