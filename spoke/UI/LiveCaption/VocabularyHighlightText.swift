import SwiftUI
import AppKit

// MARK: - Vocabulary Highlight Text

/// 支持生词高亮和右键菜单的字幕文本视图
/// - 自动高亮 VocabularyService 中的生词（橙色文字）
/// - 右键菜单支持「添加生词」
struct VocabularyHighlightText: NSViewRepresentable {
    
    let text: String
    var fontSize: CGFloat = 18
    var textColor: NSColor = NSColor(red: 249/255, green: 250/255, blue: 251/255, alpha: 1)
    var opacity: CGFloat = 1.0
    
    /// 当用户开始选择文本时的回调（用于暂停滚动）
    var onSelectionStarted: (() -> Void)?
    /// 当用户结束选择文本时的回调
    var onSelectionEnded: (() -> Void)?
    
    /// 用于触发刷新的版本号（生词列表变化时更新）
    var refreshTrigger: Int = 0
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onSelectionStarted: onSelectionStarted, onSelectionEnded: onSelectionEnded)
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
        
        // 设置 delegate
        textView.delegate = context.coordinator
        
        // 初始渲染
        updateTextContent(textView)
        
        return textView
    }
    
    func updateNSView(_ textView: VocabularyTextView, context: Context) {
        // 内容变化或生词列表变化时更新
        let needsUpdate = textView.string != text || textView.lastRefreshTrigger != refreshTrigger
        
        if needsUpdate {
            textView.lastRefreshTrigger = refreshTrigger
            updateTextContent(textView)
            textView.invalidateIntrinsicContentSize()
        }
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
        private var isSelecting = false
        
        init(onSelectionStarted: (() -> Void)?, onSelectionEnded: (() -> Void)?) {
            self.onSelectionStarted = onSelectionStarted
            self.onSelectionEnded = onSelectionEnded
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
            
            // 创建新菜单
            let newMenu = NSMenu()
            
            // 添加生词菜单项
            let addVocabularyItem = NSMenuItem(
                title: "添加生词",
                action: #selector(addToVocabulary(_:)),
                keyEquivalent: ""
            )
            addVocabularyItem.target = self
            addVocabularyItem.representedObject = selectedText
            addVocabularyItem.image = NSImage(systemSymbolName: "star", accessibilityDescription: nil)
            newMenu.addItem(addVocabularyItem)
            
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
            }
        }
    }
}

// MARK: - Vocabulary Text View

/// 自定义 NSTextView，支持 intrinsicContentSize 自适应高度
final class VocabularyTextView: NSTextView {
    
    /// 用于检测生词列表是否变化
    var lastRefreshTrigger: Int = 0
    
    convenience init(usingTextLayoutManager _: Bool) {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()  // 使用标准 LayoutManager
        let textContainer = NSTextContainer()
        
        textContainer.widthTracksTextView = true
        textContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        self.init(frame: .zero, textContainer: textContainer)
        
        // 使用系统默认选中样式
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
