import AppKit
import Testing
@testable import SpokenAnyWhere

@Suite("Screenshot 文字状态测试")
@MainActor
struct AnnotationCanvasTextStateTests {
    private func makeCanvasInWindow() -> (canvas: AnnotationCanvasView, window: NSWindow) {
        let frame = CGRect(x: 0, y: 0, width: 240, height: 160)
        let canvas = AnnotationCanvasView(frame: frame)
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = canvas
        return (canvas, window)
    }

    private func makeMouseEvent(
        window: NSWindow,
        type: NSEvent.EventType,
        location: CGPoint,
        clickCount: Int
    ) throws -> NSEvent {
        try #require(
            NSEvent.mouseEvent(
                with: type,
                location: location,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: clickCount,
                pressure: 1
            )
        )
    }

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
    func switchingToolCommitsDraftAndClearsSelection() throws {
        let (canvas, window) = makeCanvasInWindow()
        let existing = TextAnnotation(position: CGPoint(x: 32, y: 32), text: "existing")
        canvas.addAnnotation(existing, recordCommand: false)
        canvas.currentTool = .text

        canvas.mouseDown(with: try makeMouseEvent(
            window: window,
            type: .leftMouseDown,
            location: CGPoint(x: 40, y: 40),
            clickCount: 1
        ))
        canvas.mouseUp(with: try makeMouseEvent(
            window: window,
            type: .leftMouseUp,
            location: CGPoint(x: 40, y: 40),
            clickCount: 1
        ))

        #expect(canvas.selectedTextAnnotation?.id == existing.id)

        canvas.currentTool = .pen
        #expect(canvas.selectedTextAnnotation == nil)

        canvas.currentTool = .text
        let editor = canvas.beginTextDraft(at: CGPoint(x: 120, y: 96))
        editor.string = "draft"

        canvas.currentTool = .pen

        #expect(canvas.annotations.count == 2)
        #expect(canvas.annotations.contains { ($0 as? TextAnnotation)?.text == "draft" })
        #expect(canvas.activeEditingTextAnnotation == nil)
        #expect(canvas.selectedTextAnnotation == nil)
    }

    @Test("mouseDown single click selects text and double click enters editing")
    func mouseDownSelectsThenEditsExistingText() throws {
        let (canvas, window) = makeCanvasInWindow()
        let text = TextAnnotation(position: CGPoint(x: 32, y: 32), text: "hello")
        canvas.addAnnotation(text, recordCommand: false)
        canvas.currentTool = .text

        canvas.mouseDown(with: try makeMouseEvent(
            window: window,
            type: .leftMouseDown,
            location: CGPoint(x: 40, y: 40),
            clickCount: 1
        ))
        canvas.mouseUp(with: try makeMouseEvent(
            window: window,
            type: .leftMouseUp,
            location: CGPoint(x: 40, y: 40),
            clickCount: 1
        ))

        #expect(canvas.selectedTextAnnotation?.id == text.id)
        #expect(canvas.activeEditingTextAnnotation == nil)

        canvas.mouseDown(with: try makeMouseEvent(
            window: window,
            type: .leftMouseDown,
            location: CGPoint(x: 40, y: 40),
            clickCount: 2
        ))

        #expect(canvas.selectedTextAnnotation == nil)
        #expect(canvas.activeEditingTextAnnotation?.text == "hello")
        #expect(canvas.annotations.isEmpty)
    }
}
