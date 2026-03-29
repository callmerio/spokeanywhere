import AppKit
import SwiftUI

private typealias DS = DesignTokens

// MARK: - Simple Markdown Parser

/// 轻量级 Markdown 解析器，支持 **粗体**、*斜体*、`代码`
@MainActor
enum SimpleMarkdownParser {
    
    // MARK: - 字体缓存（避免重复调用 NSFontManager.convert）
    
    private static var fontCache: [String: NSFont] = [:]
    
    private static func cachedBoldFont(for font: NSFont) -> NSFont {
        let key = "bold-\(font.fontName)-\(font.pointSize)"
        if let cached = fontCache[key] { return cached }
        let bold = makeSimpleMarkdownBoldFont(from: font)
        fontCache[key] = bold
        return bold
    }
    
    private static func cachedItalicFont(for font: NSFont) -> NSFont {
        let key = "italic-\(font.fontName)-\(font.pointSize)"
        if let cached = fontCache[key] { return cached }
        let italic = makeSimpleMarkdownItalicFont(from: font)
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
