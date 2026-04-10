import AppKit
import Testing
@testable import SpokenAnyWhere

@Suite("Screenshot 文字状态测试")
@MainActor
struct AnnotationCanvasTextStateTests {
    @Test("starting a second draft commits the first draft and opens a new editor")
    func secondDraftCommitsFirstDraft() throws {
        let canvas = AnnotationCanvasView(frame: CGRect(x: 0, y: 0, width: 240, height: 160))
        canvas.currentTool = .text

        let firstEditor = canvas.beginTextDraft(at: CGPoint(x: 20, y: 20))
        firstEditor.string = "first"

        let secondEditor = canvas.beginTextDraft(at: CGPoint(x: 80, y: 80))

        #expect(canvas.annotations.count == 1)
        #expect((canvas.annotations.first as? TextAnnotation)?.text == "first")
        #expect(canvas.activeEditingTextAnnotation?.position == CGPoint(x: 80, y: 80))
        #expect(secondEditor !== firstEditor)
    }

    @Test("switching away from text commits the active draft and clears selection")
    func switchingToolCommitsDraftAndClearsSelection() {
        let canvas = AnnotationCanvasView(frame: CGRect(x: 0, y: 0, width: 240, height: 160))
        canvas.currentTool = .text

        let editor = canvas.beginTextDraft(at: CGPoint(x: 40, y: 40))
        editor.string = "draft"

        canvas.currentTool = .pen

        #expect(canvas.annotations.count == 1)
        #expect(canvas.activeEditingTextAnnotation == nil)
        #expect(canvas.selectedTextAnnotation == nil)
    }

    @Test("single click selects text and double click enters editing")
    func selectThenEditExistingText() {
        let canvas = AnnotationCanvasView(frame: CGRect(x: 0, y: 0, width: 240, height: 160))
        let text = TextAnnotation(position: CGPoint(x: 32, y: 32), text: "hello")
        canvas.addAnnotation(text, recordCommand: false)
        canvas.currentTool = .text

        #expect(canvas.selectTextAnnotation(at: CGPoint(x: 40, y: 40)))
        #expect(canvas.selectedTextAnnotation?.id == text.id)

        #expect(canvas.beginEditingTextAnnotation(at: CGPoint(x: 40, y: 40)))
        #expect(canvas.activeEditingTextAnnotation?.text == "hello")
    }
}
