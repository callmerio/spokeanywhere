import AppKit

@MainActor
func makeSimpleMarkdownBoldFont(from font: NSFont) -> NSFont {
    NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
}

@MainActor
func makeSimpleMarkdownItalicFont(from font: NSFont) -> NSFont {
    NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
}
