import AppKit
import SwiftUI

/// 可选择文本视图
struct SelectableText: NSViewRepresentable {
    let text: String
    var font: NSFont = .systemFont(ofSize: 13)
    var foregroundColor: NSColor = DesignTokens.Colors.NS.textPrimary

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textColor = foregroundColor
        textView.font = font
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0

        // 禁用滚动，让外层 ScrollView 处理
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            textView.string = text
        }
        textView.textColor = foregroundColor
        textView.font = font
    }

    func font(_ font: Font) -> SelectableText {
        var copy = self
        // 简单转换，实际使用中可能需要更精确的转换
        copy.font = .systemFont(ofSize: 13)
        return copy
    }

    func foregroundColor(_ color: Color) -> SelectableText {
        var copy = self
        copy.foregroundColor = NSColor(color)
        return copy
    }
}
