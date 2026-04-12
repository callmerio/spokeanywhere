import AppKit
import Testing
@testable import SpokenAnyWhere

@Suite("Screenshot 文字工具栏扩展测试")
@MainActor
struct ScreenshotToolbarInlineExpansionTests {
    @Test("text controls stay hidden until the text tool is active")
    func textControlsHiddenByDefault() {
        let toolbar = ScreenshotToolbarView()

        #expect(toolbar.isTextControlsVisible == false)
    }

    @Test("activating the text tool shows inline controls in the same row")
    func textToolExpandsInlineControls() {
        let toolbar = ScreenshotToolbarView()
        toolbar.setTextControlsVisible(true)

        #expect(toolbar.isTextControlsVisible)
        #expect(toolbar.displayedTextFontSize == "16")
    }

    @Test("applying a style snapshot updates the font label")
    func applyingTextStyleUpdatesLabel() {
        let toolbar = ScreenshotToolbarView()
        toolbar.setTextControlsVisible(true)
        toolbar.applyTextStyle(
            TextAnnotationStyle(fontSize: 24, color: .systemRed, opacity: 1),
            hasSelectedText: true
        )

        #expect(toolbar.displayedTextFontSize == "24")
    }
}
