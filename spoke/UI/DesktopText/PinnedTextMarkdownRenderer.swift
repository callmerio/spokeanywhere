import AppKit

@MainActor
enum PinnedTextMarkdownRenderer {
    static let minZoomLevel: Double = 0.4
    static let maxZoomLevel: Double = 2.4
    static let baseContentWidth: CGFloat = 320
    static let minContentWidth: CGFloat = 260
    static let maxContentWidth: CGFloat = 760
    static let minWindowHeight: CGFloat = 120
    static let maxWindowHeight: CGFloat = 540
    static let windowGlowPadding: CGFloat = ScreenshotContentView.paddingPerSide
    static let contentInsets = NSEdgeInsets(top: 10, left: 8, bottom: 8, right: 8)
    static let bodyLineSpacing: CGFloat = 3
    static let bodyParagraphSpacing: CGFloat = 6
    static let headingLineSpacing: CGFloat = 4
    static let headingParagraphSpacing: CGFloat = 8

    static func clampedZoom(_ zoomLevel: Double) -> Double {
        min(max(zoomLevel, minZoomLevel), maxZoomLevel)
    }

    static func contentWidth(for zoomLevel: Double) -> CGFloat {
        let width = baseContentWidth * CGFloat(clampedZoom(zoomLevel))
        return min(max(width, minContentWidth), maxContentWidth)
    }

    static func bodyFont(for zoomLevel: Double) -> NSFont {
        NSFont.systemFont(ofSize: 16 * CGFloat(clampedZoom(zoomLevel)), weight: .regular)
    }

    static func editorFont(for zoomLevel: Double) -> NSFont {
        bodyFont(for: zoomLevel)
    }

    static func bodyParagraphStyle() -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = bodyParagraphSpacing
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = bodyLineSpacing
        return paragraph
    }

    static func editorParagraphStyle() -> NSParagraphStyle {
        bodyParagraphStyle()
    }

    static func previewTextColor() -> NSColor {
        DesignTokens.Colors.NS.pinnedTextForeground
    }

    static func makePreviewAttributedString(
        _ text: String,
        zoomLevel: Double
    ) -> NSAttributedString {
        let normalized = normalize(text)
        let bodyFont = bodyFont(for: zoomLevel)
        let bodyColor = previewTextColor()
        let result = NSMutableAttributedString()
        let lines = normalized.components(separatedBy: "\n")

        for (index, rawLine) in lines.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "\n", attributes: [
                    .font: bodyFont,
                    .foregroundColor: bodyColor
                ]))
            }

            let trimmedLine = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty {
                continue
            }

            let segment = attributedLine(for: rawLine, zoomLevel: zoomLevel)
            result.append(segment)
        }

        return result
    }

    static func preferredWindowSize(
        text: String,
        zoomLevel: Double
    ) -> CGSize {
        let contentWidth = contentWidth(for: zoomLevel)
        let attributed = makePreviewAttributedString(text, zoomLevel: zoomLevel)
        let measured = measureAttributedString(attributed, width: contentWidth)
        let width = contentWidth + contentInsets.left + contentInsets.right + (windowGlowPadding * 2)
        let height = min(
            max(
                measured.height + contentInsets.top + contentInsets.bottom + (windowGlowPadding * 2),
                minWindowHeight
            ),
            maxWindowHeight
        )
        return CGSize(width: width, height: height)
    }

    static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private static func attributedLine(
        for rawLine: String,
        zoomLevel: Double
    ) -> NSAttributedString {
        let bodyFont = bodyFont(for: zoomLevel)
        let bodyColor = previewTextColor()

        if rawLine.hasPrefix("## ") {
            return styledLine(
                String(rawLine.dropFirst(3)),
                font: NSFont.systemFont(ofSize: bodyFont.pointSize * 1.22, weight: .semibold),
                color: bodyColor,
                spacingAfter: bodyParagraphSpacing,
                lineSpacing: bodyLineSpacing
            )
        }

        if rawLine.hasPrefix("# ") {
            return styledLine(
                String(rawLine.dropFirst(2)),
                font: NSFont.systemFont(ofSize: bodyFont.pointSize * 1.42, weight: .bold),
                color: bodyColor,
                spacingAfter: headingParagraphSpacing,
                lineSpacing: headingLineSpacing
            )
        }

        if rawLine.hasPrefix("- ") {
            let listFont = bodyFont
            let bullet = NSMutableAttributedString(string: "• ", attributes: [
                .font: NSFont.systemFont(ofSize: listFont.pointSize, weight: .semibold),
                .foregroundColor: bodyColor
            ])
            let content = NSMutableAttributedString(
                attributedString: SimpleMarkdownParser.parse(
                    String(rawLine.dropFirst(2)),
                    font: listFont,
                    foregroundColor: bodyColor
                )
            )
            let paragraph = NSMutableParagraphStyle()
            paragraph.paragraphSpacing = bodyParagraphSpacing
            paragraph.lineSpacing = bodyLineSpacing
            paragraph.headIndent = 18
            paragraph.firstLineHeadIndent = 0
            content.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: content.length))
            bullet.append(content)
            return bullet
        }

        return styledLine(rawLine, font: bodyFont, color: bodyColor, spacingAfter: bodyParagraphSpacing, lineSpacing: bodyLineSpacing)
    }

    private static func styledLine(
        _ line: String,
        font: NSFont,
        color: NSColor,
        spacingAfter: CGFloat,
        lineSpacing: CGFloat
    ) -> NSAttributedString {
        let attributed = NSMutableAttributedString(
            attributedString: SimpleMarkdownParser.parse(line, font: font, foregroundColor: color)
        )
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = spacingAfter
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = lineSpacing
        attributed.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: attributed.length))
        return attributed
    }

    private static func measureAttributedString(
        _ text: NSAttributedString,
        width: CGFloat
    ) -> CGSize {
        let rect = text.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return CGSize(width: ceil(rect.width), height: ceil(rect.height))
    }
}
