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

    private func makeScrollEvent(
        deltaX: Int32 = 0,
        deltaY: Int32 = 0,
        precise: Bool = true
    ) throws -> NSEvent {
        let units: CGScrollEventUnit = precise ? .pixel : .line
        let cgEvent = try #require(
            CGEvent(
                scrollWheelEvent2Source: nil,
                units: units,
                wheelCount: 2,
                wheel1: deltaY,
                wheel2: deltaX,
                wheel3: 0
            )
        )
        return try #require(NSEvent(cgEvent: cgEvent))
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

    @Test("selected text style edits keep selection and republish style across undo redo")
    func selectedTextStyleEditsResyncAcrossUndoRedo() throws {
        let (canvas, window) = makeCanvasInWindow()
        let original = TextAnnotation(position: CGPoint(x: 32, y: 32), text: "styled", color: .systemBlue)
        canvas.addAnnotation(original, recordCommand: false)
        canvas.currentTool = .text

        var styleUpdates: [(TextAnnotationStyle, Bool)] = []
        canvas.onTextStyleChanged = { style, hasSelectedText in
            styleUpdates.append((style, hasSelectedText))
        }

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

        #expect(canvas.selectedTextAnnotation?.id == original.id)

        canvas.applyTextFontSizeStep(4)
        canvas.applyTextColor(.systemRed)

        let styled = try #require(canvas.selectedTextAnnotation)
        #expect(styled.id == original.id)
        #expect(styled.style.fontSize == 20)
        #expect(styled.style.color == .systemRed)

        canvas.undo()
        let afterUndo = try #require(canvas.selectedTextAnnotation)
        #expect(afterUndo.id == original.id)
        #expect(afterUndo.style.fontSize == 20)
        #expect(afterUndo.style.color == .systemBlue)
        let undoState = try #require(styleUpdates.last)
        #expect(undoState.0.fontSize == 20)
        #expect(undoState.0.color == .systemBlue)
        #expect(undoState.1 == false)

        canvas.undo()
        let afterSecondUndo = try #require(canvas.selectedTextAnnotation)
        #expect(afterSecondUndo.id == original.id)
        #expect(afterSecondUndo.style.fontSize == 16)
        #expect(afterSecondUndo.style.color == .systemBlue)
        let secondUndoState = try #require(styleUpdates.last)
        #expect(secondUndoState.0.fontSize == 16)
        #expect(secondUndoState.0.color == .systemBlue)
        #expect(secondUndoState.1 == false)

        canvas.redo()
        let afterRedo = try #require(canvas.selectedTextAnnotation)
        #expect(afterRedo.id == original.id)
        #expect(afterRedo.style.fontSize == 20)
        #expect(afterRedo.style.color == .systemBlue)
        let redoState = try #require(styleUpdates.last)
        #expect(redoState.0.fontSize == 20)
        #expect(redoState.0.color == .systemBlue)
        #expect(redoState.1 == false)

        canvas.redo()
        let afterSecondRedo = try #require(canvas.selectedTextAnnotation)
        #expect(afterSecondRedo.id == original.id)
        #expect(afterSecondRedo.style.fontSize == 20)
        #expect(afterSecondRedo.style.color == .systemRed)
        let secondRedoState = try #require(styleUpdates.last)
        #expect(secondRedoState.0.fontSize == 20)
        #expect(secondRedoState.0.color == .systemRed)
        #expect(secondRedoState.1 == false)
    }

    @Test("selected text decoration state follows text selection lifecycle")
    func selectedTextDecorationStateFollowsSelectionLifecycle() throws {
        let (canvas, window) = makeCanvasInWindow()
        let original = TextAnnotation(position: CGPoint(x: 32, y: 32), text: "selected")
        canvas.addAnnotation(original, recordCommand: false)
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

        let decorationRect = try #require(canvas.selectedTextDecorationRect(for: original))
        let textRect = original.boundingRect()
        #expect(decorationRect.minX < textRect.minX)
        #expect(decorationRect.minY < textRect.minY)
        #expect(decorationRect.maxX > textRect.maxX)
        #expect(decorationRect.maxY > textRect.maxY)

        canvas.clearTextSelection()
        #expect(canvas.selectedTextDecorationRect(for: original) == nil)

        #expect(canvas.selectTextAnnotation(at: CGPoint(x: 40, y: 40)))
        #expect(canvas.selectedTextDecorationRect(for: original) != nil)

        canvas.currentTool = .pen
        #expect(canvas.selectedTextAnnotation == nil)
        #expect(canvas.selectedTextDecorationRect(for: original) == nil)
    }

    @Test("selected text style helpers only mutate the selected annotation while text mode selection is active")
    func selectedTextStyleHelpersOnlyMutateActiveTextSelection() throws {
        let (canvas, window) = makeCanvasInWindow()
        let original = TextAnnotation(
            position: CGPoint(x: 32, y: 32),
            text: "styled",
            color: .systemBlue,
            opacity: 0.8
        )
        canvas.addAnnotation(original, recordCommand: false)
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

        canvas.applyTextFontSizeStep(6)
        canvas.adjustSelectedTextOpacity(by: -0.9)
        canvas.adjustSelectedTextOpacity(by: 1.0)

        let selected = try #require(canvas.selectedTextAnnotation)
        #expect(selected.style.fontSize == 22)
        #expect(selected.style.opacity == 1.0)

        canvas.currentTool = .pen
        canvas.applyTextFontSizeStep(10)
        canvas.adjustSelectedTextOpacity(by: -0.5)

        let persisted = try #require(canvas.annotations.first as? TextAnnotation)
        #expect(persisted.style.fontSize == 22)
        #expect(persisted.style.opacity == 1.0)
    }

    @Test("scrollWheel adjusts selected text opacity horizontally and font size vertically in text mode")
    func scrollWheelAdjustsSelectedTextInTextMode() throws {
        let (canvas, window) = makeCanvasInWindow()
        let original = TextAnnotation(
            position: CGPoint(x: 32, y: 32),
            text: "scroll",
            color: .systemBlue,
            opacity: 0.9
        )
        canvas.addAnnotation(original, recordCommand: false)
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

        let brushSizeBeforeScroll = canvas.currentBrushSize
        canvas.scrollWheel(with: try makeScrollEvent(deltaX: -50, precise: true))

        let afterOpacityScroll = try #require(canvas.selectedTextAnnotation)
        #expect(abs(afterOpacityScroll.style.opacity - 0.75) < 0.0001)
        #expect(afterOpacityScroll.style.fontSize == 16)
        #expect(canvas.currentBrushSize == brushSizeBeforeScroll)

        canvas.scrollWheel(with: try makeScrollEvent(deltaY: 12, precise: true))

        let afterFontScroll = try #require(canvas.selectedTextAnnotation)
        #expect(afterFontScroll.style.fontSize == 18)
        #expect(abs(afterFontScroll.style.opacity - 0.75) < 0.0001)
    }

    @Test("scrollWheel keeps brush-size behavior when selected text path is inactive")
    func scrollWheelKeepsBrushSizeBehaviorWhenSelectedTextPathIsInactive() throws {
        let canvas = AnnotationCanvasView(frame: CGRect(x: 0, y: 0, width: 240, height: 160))
        let original = TextAnnotation(
            position: CGPoint(x: 32, y: 32),
            text: "brush",
            color: .systemBlue,
            opacity: 0.7
        )
        canvas.addAnnotation(original, recordCommand: false)
        canvas.currentTool = .pen

        canvas.scrollWheel(with: try makeScrollEvent(deltaY: 12, precise: false))

        #expect(canvas.currentBrushSize == 4)
        let unchanged = try #require(canvas.annotations.first as? TextAnnotation)
        #expect(unchanged.style.fontSize == 16)
        #expect(abs(unchanged.style.opacity - 0.7) < 0.0001)
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
