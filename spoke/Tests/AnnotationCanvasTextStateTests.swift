import AppKit
import Testing
@testable import SpokenAnyWhere

@Suite("Screenshot 文字状态测试", .serialized)
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

    private func makeSolidImage(size: NSSize, color: NSColor = .white) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        return image
    }

    private func makeSelectionViewInWindow() -> (view: RegionSelectionView, window: NSWindow) {
        let frame = CGRect(x: 0, y: 0, width: 240, height: 180)
        let view = RegionSelectionView(frame: frame)
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = view
        return (view, window)
    }

    private func makeSelectionRegion(
        view: RegionSelectionView,
        window: NSWindow,
        from start: CGPoint = CGPoint(x: 20, y: 20),
        to end: CGPoint = CGPoint(x: 180, y: 120)
    ) throws {
        view.mouseDown(with: try makeMouseEvent(
            window: window,
            type: .leftMouseDown,
            location: start,
            clickCount: 1
        ))
        view.mouseDragged(with: try makeMouseEvent(
            window: window,
            type: .leftMouseDragged,
            location: end,
            clickCount: 1
        ))
        view.mouseUp(with: try makeMouseEvent(
            window: window,
            type: .leftMouseUp,
            location: end,
            clickCount: 1
        ))
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

    @Test("export path commits active text drafts before generating the annotated image")
    func exportCommitsActiveDraftBeforeRendering() throws {
        let (view, window) = makeSelectionViewInWindow()
        view.backgroundImage = makeSolidImage(size: NSSize(width: 240, height: 180))

        try makeSelectionRegion(view: view, window: window)
        view.setAnnotationTool(.text)

        let canvas = try #require(view.annotationCanvas)
        let editor = canvas.beginTextDraft(at: CGPoint(x: 24, y: 18))
        editor.string = "draft"

        #expect(canvas.annotations.isEmpty)
        #expect(canvas.activeEditingTextAnnotation != nil)

        let exportedImage = view.getAnnotatedImage()

        #expect(exportedImage != nil)
        #expect(canvas.activeEditingTextAnnotation == nil)
        #expect(canvas.annotations.count == 1)
        #expect((canvas.annotations.first as? TextAnnotation)?.text == "draft")
    }

    @Test("editing an existing text annotation can undo back to the original content")
    func editingExistingTextSupportsUndoRedo() throws {
        let canvas = AnnotationCanvasView(frame: CGRect(x: 0, y: 0, width: 240, height: 160))
        let original = TextAnnotation(position: CGPoint(x: 32, y: 32), text: "before", color: .systemBlue)
        canvas.addAnnotation(original, recordCommand: false)
        canvas.currentTool = .text

        #expect(canvas.beginEditingTextAnnotation(at: CGPoint(x: 40, y: 40)))
        let editor = try #require(canvas.subviews.compactMap { $0 as? NSTextView }.first)
        editor.string = "after"

        canvas.currentTool = .pen

        #expect((canvas.annotations.first as? TextAnnotation)?.text == "after")

        canvas.undo()

        #expect(canvas.annotations.count == 1)
        #expect((canvas.annotations.first as? TextAnnotation)?.text == "before")

        canvas.redo()

        #expect(canvas.annotations.count == 1)
        #expect((canvas.annotations.first as? TextAnnotation)?.text == "after")
    }

    @Test("canceling an existing text edit restores the original annotation without changing history")
    func cancelExistingTextEditRestoresOriginalAnnotationWithoutHistoryChange() throws {
        let canvas = AnnotationCanvasView(frame: CGRect(x: 0, y: 0, width: 240, height: 160))
        canvas.currentTool = .text

        let seedEditor = canvas.beginTextDraft(at: CGPoint(x: 12, y: 12))
        seedEditor.string = "seed"
        canvas.currentTool = .pen

        #expect(canvas.canUndo)
        #expect(!canvas.canRedo)

        let original = TextAnnotation(position: CGPoint(x: 32, y: 32), text: "before", color: .systemBlue)
        canvas.addAnnotation(original, recordCommand: false)
        canvas.currentTool = .text

        #expect(canvas.beginEditingTextAnnotation(at: CGPoint(x: 40, y: 40)))
        let editor = try #require(canvas.subviews.compactMap { $0 as? NSTextView }.first)
        editor.string = "after"

        #expect(canvas.textView(editor, doCommandBy: #selector(NSResponder.cancelOperation(_:))))

        let restored = try #require(
            canvas.annotations.first(where: { ($0 as? TextAnnotation)?.id == original.id }) as? TextAnnotation
        )

        #expect(restored.text == "before")
        #expect(restored.style.color == .systemBlue)
        #expect(canvas.activeEditingTextAnnotation == nil)
        #expect(canvas.canUndo)
        #expect(!canvas.canRedo)
    }

    @Test("new drafts inherit currentColor when no selected text annotation overrides the style")
    func newDraftUsesCurrentColorWithoutTextSelection() {
        let canvas = AnnotationCanvasView(frame: CGRect(x: 0, y: 0, width: 240, height: 160))
        canvas.currentColor = .systemPink
        canvas.currentTool = .text

        _ = canvas.beginTextDraft(at: CGPoint(x: 24, y: 24))

        #expect(canvas.selectedTextAnnotation == nil)
        #expect(canvas.activeEditingTextAnnotation?.style.color == .systemPink)
    }

    @Test("export-path draft commit notifies RegionSelectionView history handler once without recursion")
    func exportDraftCommitNotifiesHistoryHandlerOnce() throws {
        let (view, window) = makeSelectionViewInWindow()
        view.backgroundImage = makeSolidImage(size: NSSize(width: 240, height: 180))

        var historyEvents: [(Bool, Bool)] = []
        view.onAnnotationHistoryChanged = { canUndo, canRedo in
            historyEvents.append((canUndo, canRedo))
        }

        try makeSelectionRegion(view: view, window: window)
        view.setAnnotationTool(.text)

        let canvas = try #require(view.annotationCanvas)
        let editor = canvas.beginTextDraft(at: CGPoint(x: 28, y: 20))
        editor.string = "draft"

        let exportedImage = view.getAnnotatedImage()

        #expect(exportedImage != nil)
        #expect(historyEvents.count == 1)
        #expect(historyEvents.first?.0 == true)
        #expect(historyEvents.first?.1 == false)
    }
}
