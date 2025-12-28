import AppKit
import SwiftUI

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
        guard !highlights.isEmpty else {
            return Text(text).foregroundStyle(Color(foregroundColor))
        }
        
        let filteredRanges = resolveHighlightRanges(in: text)
        var segments: [Text] = []
        var currentIndex = text.startIndex
        
        for (range, highlight) in filteredRanges {
            if currentIndex < range.lowerBound {
                segments.append(normalText(from: currentIndex..<range.lowerBound))
            }
            
            segments.append(contentsOf: highlightedSegments(for: highlight, range: range))
            
            currentIndex = range.upperBound
        }
        
        if currentIndex < text.endIndex {
            segments.append(normalText(from: currentIndex..<text.endIndex))
        }
        
        return segments.reduce(Text(""), +)
    }
    
    private func resolveHighlightRanges(
        in text: String
    ) -> [(range: Range<String.Index>, highlight: TextHighlight)] {
        var processedRanges: [(range: Range<String.Index>, highlight: TextHighlight)] = []
        let lowercasedText = text.lowercased()
        
        for highlight in highlights {
            switch highlight.type {
            case .correction:
                let searchWord = highlight.originalWord ?? highlight.targetWord
                if let range = lowercasedText.range(of: searchWord.lowercased()) {
                    processedRanges.append((range, highlight))
                }
                
            case .dictionary:
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
        
        processedRanges.sort { $0.range.lowerBound < $1.range.lowerBound }
        return filterOverlappingRanges(from: processedRanges)
    }
    
    private func filterOverlappingRanges(
        from ranges: [(range: Range<String.Index>, highlight: TextHighlight)]
    ) -> [(range: Range<String.Index>, highlight: TextHighlight)] {
        var filteredRanges: [(range: Range<String.Index>, highlight: TextHighlight)] = []
        for item in ranges {
            if let last = filteredRanges.last, item.range.lowerBound < last.range.upperBound {
                continue
            }
            filteredRanges.append(item)
        }
        return filteredRanges
    }
    
    private func normalText(from range: Range<String.Index>) -> Text {
        let content = String(text[range])
        return Text(content).foregroundStyle(Color(foregroundColor))
    }
    
    private func highlightedSegments(
        for highlight: TextHighlight,
        range: Range<String.Index>
    ) -> [Text] {
        switch highlight.type {
        case .correction:
            let originalWord = String(text[range])
            let originalText = Text(originalWord)
                .strikethrough(true, color: strikethroughColor)
                .foregroundStyle(strikethroughColor)
            let correctedText = Text(highlight.targetWord).foregroundStyle(highlightColor)
            return [originalText, Text(" "), correctedText]
            
        case .dictionary:
            let targetWord = String(text[range])
            return [Text(targetWord).foregroundStyle(highlightColor)]
        }
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
