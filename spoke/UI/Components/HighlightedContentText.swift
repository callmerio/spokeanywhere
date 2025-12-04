import SwiftUI
import AppKit

/// 带高亮标记的内容文本视图（纯 SwiftUI 实现）
/// 支持纠错样式（删除线 + 橙色正确词）和词典学习样式（橙色目标词）
struct HighlightedContentText: View {
    let text: String
    let highlights: [TextHighlight]
    let font: NSFont
    let foregroundColor: NSColor
    
    /// 橙色高亮颜色
    private let highlightColor = Color(red: 1.0, green: 0.6, blue: 0.2)
    /// 删除线颜色
    private let strikethroughColor = Color.gray
    
    var body: some View {
        buildHighlightedText()
            .font(.system(size: font.pointSize))
    }
    
    /// 构建带样式的 Text（使用 Text + 拼接支持自动换行）
    private func buildHighlightedText() -> Text {
        // 如果没有高亮，直接返回普通文本
        guard !highlights.isEmpty else {
            return Text(text)
                .foregroundStyle(Color(foregroundColor))
        }
        
        // 收集所有需要处理的位置
        var processedRanges: [(range: Range<String.Index>, highlight: TextHighlight)] = []
        let lowercasedText = text.lowercased()
        
        for highlight in highlights {
            switch highlight.type {
            case .correction:
                // 纠错模式：查找原词的位置（卡片内容是原始的，需要查找 originalWord）
                let searchWord = highlight.originalWord ?? highlight.targetWord
                if let range = lowercasedText.range(of: searchWord.lowercased()) {
                    processedRanges.append((range, highlight))
                }
                
            case .dictionary:
                // 词典模式：查找目标词的所有位置
                var searchStart = lowercasedText.startIndex
                while let range = lowercasedText.range(
                    of: highlight.targetWord.lowercased(),
                    range: searchStart..<lowercasedText.endIndex
                ) {
                    processedRanges.append((range, highlight))
                    searchStart = range.upperBound
                }
            }
        }
        
        // 按位置排序
        processedRanges.sort { $0.range.lowerBound < $1.range.lowerBound }
        
        // 移除重叠的范围
        var filteredRanges: [(range: Range<String.Index>, highlight: TextHighlight)] = []
        for item in processedRanges {
            if let last = filteredRanges.last, item.range.lowerBound < last.range.upperBound {
                continue // 跳过重叠
            }
            filteredRanges.append(item)
        }
        
        // 构建 Text 结果
        var result = Text("")
        var currentIndex = text.startIndex
        
        for (range, highlight) in filteredRanges {
            // 添加高亮之前的普通文本
            if currentIndex < range.lowerBound {
                let normalText = String(text[currentIndex..<range.lowerBound])
                result = result + Text(normalText).foregroundStyle(Color(foregroundColor))
            }
            
            // 添加高亮内容
            switch highlight.type {
            case .correction:
                // 纠错：~~原词~~ + 正确词（橙色）
                // 原词用删除线
                let originalWord = String(text[range])  // 从文本中取出原词
                result = result + Text(originalWord)
                    .strikethrough(true, color: strikethroughColor)
                    .foregroundStyle(strikethroughColor)
                // 空格
                result = result + Text(" ")
                // 正确词用橙色
                result = result + Text(highlight.targetWord).foregroundStyle(highlightColor)
                
            case .dictionary:
                // 词典：橙色目标词
                let targetWord = String(text[range])
                result = result + Text(targetWord).foregroundStyle(highlightColor)
            }
            
            currentIndex = range.upperBound
        }
        
        // 添加剩余文本
        if currentIndex < text.endIndex {
            let remainingText = String(text[currentIndex...])
            result = result + Text(remainingText).foregroundStyle(Color(foregroundColor))
        }
        
        return result
    }
}

// MARK: - Preview

#if DEBUG
struct HighlightedContentText_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 纠错样式
            HighlightedContentText(
                text: "我们 have 到训练短语的时候，Claude 是一个很好的 AI。",
                highlights: [
                    .correction(from: "have", to: "have"),
                    .dictionary(word: "Claude")
                ],
                font: .systemFont(ofSize: 14),
                foregroundColor: .white
            )
            .frame(height: 60)
            
            // 词典样式
            HighlightedContentText(
                text: "Gemini 是 Google 的 AI，Gemini 2.5 很强。",
                highlights: [
                    .dictionary(word: "Gemini")
                ],
                font: .systemFont(ofSize: 14),
                foregroundColor: .white
            )
            .frame(height: 40)
        }
        .padding()
        .background(Color.black)
    }
}
#endif
