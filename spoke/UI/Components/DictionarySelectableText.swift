import SwiftUI

private typealias DS = DesignTokens
import AppKit

// MARK: - SimpleMarkdownParser
// 已移至: spoke/UI/Components/SimpleMarkdownParser.swift

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
    
    @MainActor
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
            guard let newMenu = menu.copy() as? NSMenu else { return menu }
            
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

// 文件级常量：选中样式配置（避免 MainActor 隔离问题）
private let kSelectionColor = DS.Colors.NS.highlightGold
private let kSelectedTextColor = DS.Colors.NS.textPrimary
private let kSelectedTextShadow: NSShadow = {
    let shadow = NSShadow()
    shadow.shadowColor = DS.Colors.NS.selectionShadow
    shadow.shadowOffset = NSSize(width: 0, height: 0)
    shadow.shadowBlurRadius = 1.5
    return shadow
}()

/// 自定义 NSLayoutManager，覆盖选中区域的背景颜色绘制
/// @unchecked Sendable: NSLayoutManager 方法由 AppKit 在主线程调用，标记为 Sendable 消除 capture 警告
@MainActor
final class SelectionColorLayoutManager: NSLayoutManager, @unchecked Sendable {

    /// 覆盖背景绘制方法，自定义选中区域的背景颜色
    /// NSLayoutManager 的绘制方法由 AppKit 在主线程调用
    /// 使用 nonisolated override 匹配父类签名，点状 hop 仅用于 selectedRanges 提取
    nonisolated override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        // 先调用父类绘制其他背景
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)

        // 手动绘制选中区域的背景
        guard let textView = self.firstTextView,
              let textContainer = self.textContainers.first else { return }

        // 点状 MainActor hop：提取 NSRange（Sendable）而非 NSValue（非 Sendable）
        let selectedCharRanges = MainActor.assumeIsolated {
            textView.selectedRanges.map { $0.rangeValue }.filter { $0.length > 0 }
        }

        for selectedRange in selectedCharRanges {
            let glyphRange = self.glyphRange(forCharacterRange: selectedRange, actualCharacterRange: nil)
            let intersection = NSIntersectionRange(glyphRange, glyphsToShow)
            guard intersection.length > 0 else { continue }

            self.enumerateLineFragments(forGlyphRange: intersection) { _, _, _, lineGlyphRange, _ in
                let lineIntersection = NSIntersectionRange(lineGlyphRange, intersection)
                guard lineIntersection.length > 0 else { return }

                var selectionRect = self.boundingRect(forGlyphRange: lineIntersection, in: textContainer)
                selectionRect.origin.x += origin.x
                selectionRect.origin.y += origin.y

                // 使用文件级常量（非 MainActor-isolated）
                kSelectionColor.setFill()
                let path = NSBezierPath(roundedRect: selectionRect, xRadius: 3, yRadius: 3)
                path.fill()
            }
        }
    }

    /// 覆盖文字绘制方法，为选中文字添加描边效果
    /// NSLayoutManager 的绘制方法由 AppKit 在主线程调用
    /// 使用 nonisolated override 匹配父类签名，点状 hop 仅用于 selectedRanges 提取
    nonisolated override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        guard let textView = self.firstTextView else {
            super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
            return
        }

        // 点状 MainActor hop：提取 NSRange（Sendable）而非 NSValue（非 Sendable）
        let selectedCharRanges = MainActor.assumeIsolated {
            textView.selectedRanges.map { $0.rangeValue }.filter { $0.length > 0 }
        }

        // 如果没有选中，直接调用父类
        guard !selectedCharRanges.isEmpty else {
            super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
            return
        }

        // 为选中区域添加临时属性（使用文件级常量）
        for selectedRange in selectedCharRanges {
            let glyphRange = self.glyphRange(forCharacterRange: selectedRange, actualCharacterRange: nil)
            let intersection = NSIntersectionRange(glyphRange, glyphsToShow)
            if intersection.length > 0 {
                let charRange = self.characterRange(forGlyphRange: intersection, actualGlyphRange: nil)
                self.addTemporaryAttribute(.foregroundColor, value: kSelectedTextColor, forCharacterRange: charRange)
                self.addTemporaryAttribute(.shadow, value: kSelectedTextShadow, forCharacterRange: charRange)
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
@MainActor
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