# Screenshot Text Annotation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use super-subagent (recommended) or super-executing to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the screenshot annotation editor so text annotations behave like first-class objects with explicit draft/selection/editing state, inline text controls, trackpad-based font/opacity adjustment, and reliable object-level erasing.

**Architecture:** Keep the existing object-based screenshot annotation stack (`RegionSelectionWindow -> RegionSelectionView -> AnnotationCanvasView -> Annotation.swift`) and extend it in place. Introduce explicit text-style/state helpers inside the existing files instead of creating a new overlay subsystem, and drive the new single-row inline text controls from `ScreenshotToolbarView` through lightweight callbacks.

**Tech Stack:** Swift 5.9, AppKit, Swift Testing (`import Testing`), Swift Package Manager, existing screenshot annotation views in `spoke/UI/Screenshot`

---

## File Map

### Existing files to modify

- `spoke/UI/Screenshot/Annotation.swift`
  - Owns annotation models, text style data, draw logic, and hit testing.
- `spoke/UI/Screenshot/AnnotationCanvasView.swift`
  - Owns annotation interaction state, mouse events, text editing, selection, dragging, and scroll/gesture dispatch.
- `spoke/UI/Screenshot/RegionSelectionView.swift`
  - Owns annotation canvas embedding and forwards toolbar-driven text style actions into the canvas.
- `spoke/UI/Screenshot/RegionSelectionWindow.swift`
  - Owns toolbar visibility, tool selection, and wiring toolbar callbacks into the selection view.
- `spoke/UI/Screenshot/ScreenshotToolbarView.swift`
  - Owns the single-row toolbar layout and will host the inline text controls immediately after the `Aa` tool.

### New test files to create

- `spoke/Tests/AnnotationModelTests.swift`
  - Covers `TextAnnotationStyle`, text annotation style round-tripping, and stroke hit testing for pen/marker.
- `spoke/Tests/AnnotationCanvasTextStateTests.swift`
  - Covers draft commit-on-switch, draft replacement on second double click, text selection vs editing, and text-style mutation helpers.
- `spoke/Tests/ScreenshotToolbarInlineExpansionTests.swift`
  - Covers the single-row inline text controls becoming visible when the text tool is active and mirroring the current text style.

### Verification commands

- `cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && swift test --filter AnnotationModelTests`
- `cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && swift test --filter AnnotationCanvasTextStateTests`
- `cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && swift test --filter ScreenshotToolbarInlineExpansionTests`
- `cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && swift build`
- `cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && swift test`
- `cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && bash Tests/run-concurrency-check.sh`

---

### Task 1: Add Annotation Style Primitives And Stable Object Hit Testing

**Files:**
- Modify: `spoke/UI/Screenshot/Annotation.swift`
- Create: `spoke/Tests/AnnotationModelTests.swift`

- [ ] **Step 1: Write the failing model tests**

```swift
import AppKit
import Testing
@testable import SpokenAnyWhere

@Suite("Screenshot 标注模型测试")
@MainActor
struct AnnotationModelTests {
    @Test("TextAnnotation style round-trips font size, color, and opacity")
    func textAnnotationStyleRoundTrips() {
        let annotation = TextAnnotation(position: CGPoint(x: 24, y: 32), text: "Hello")
        annotation.style = TextAnnotationStyle(
            fontSize: 28,
            color: .systemYellow,
            opacity: 0.55
        )

        #expect(annotation.style.fontSize == 28)
        #expect(annotation.style.color == .systemYellow)
        #expect(annotation.style.opacity == 0.55)
        #expect(annotation.boundingRect().width > 0)
    }

    @Test("PenAnnotation hitTest includes the middle of a stroke segment")
    func penHitTestUsesSegments() {
        let annotation = PenAnnotation(
            points: [CGPoint(x: 10, y: 10), CGPoint(x: 110, y: 10)],
            color: .systemRed,
            lineWidth: 8
        )

        #expect(annotation.hitTest(point: CGPoint(x: 60, y: 12)))
        #expect(!annotation.hitTest(point: CGPoint(x: 60, y: 40)))
    }

    @Test("MarkerAnnotation hitTest includes the middle of a stroke segment")
    func markerHitTestUsesSegments() {
        let annotation = MarkerAnnotation(
            points: [CGPoint(x: 20, y: 20), CGPoint(x: 20, y: 120)],
            color: .systemYellow,
            lineWidth: 24
        )

        #expect(annotation.hitTest(point: CGPoint(x: 18, y: 70)))
        #expect(!annotation.hitTest(point: CGPoint(x: 60, y: 70)))
    }
}
```

- [ ] **Step 2: Run the model tests to verify they fail**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && swift test --filter AnnotationModelTests
```

Expected:

- `TextAnnotation` has no member `style`
- Pen / marker middle-segment hit tests fail because hit testing only checks sampled points

- [ ] **Step 3: Add the text style value type and segment-based hit testing**

Update `spoke/UI/Screenshot/Annotation.swift` with the minimal production changes:

```swift
import AppKit

struct TextAnnotationStyle {
    var fontSize: CGFloat
    var color: NSColor
    var opacity: CGFloat

    static let `default` = TextAnnotationStyle(
        fontSize: 16,
        color: DesignTokens.Colors.NS.annotationText,
        opacity: 1
    )
}

private enum StrokeHitTest {
    static func contains(point: CGPoint, points: [CGPoint], lineWidth: CGFloat) -> Bool {
        guard points.count >= 2 else { return false }

        let tolerance = lineWidth / 2 + 5
        for index in 0..<(points.count - 1) {
            if distance(from: point, toSegmentStart: points[index], end: points[index + 1]) <= tolerance {
                return true
            }
        }
        return false
    }

    private static func distance(from point: CGPoint, toSegmentStart start: CGPoint, end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(point.x - start.x, point.y - start.y) }

        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        let projection = CGPoint(x: start.x + t * dx, y: start.y + t * dy)
        return hypot(point.x - projection.x, point.y - projection.y)
    }
}

final class PenAnnotation: Annotation {
    func hitTest(point: CGPoint) -> Bool {
        StrokeHitTest.contains(point: point, points: points, lineWidth: lineWidth)
    }
}

final class MarkerAnnotation: Annotation {
    func hitTest(point: CGPoint) -> Bool {
        StrokeHitTest.contains(point: point, points: points, lineWidth: lineWidth)
    }
}

final class TextAnnotation: Annotation {
    var opacity: CGFloat = TextAnnotationStyle.default.opacity

    var style: TextAnnotationStyle {
        get {
            TextAnnotationStyle(
                fontSize: font.pointSize,
                color: color,
                opacity: opacity
            )
        }
        set {
            color = newValue.color
            opacity = min(max(newValue.opacity, 0.3), 1)
            font = .systemFont(ofSize: newValue.fontSize, weight: .medium)
            updateCachedSize()
        }
    }

    func draw(in context: CGContext) {
        guard !text.isEmpty else { return }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = maxWidth != nil ? .byWordWrapping : .byClipping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color.withAlphaComponent(opacity),
            .paragraphStyle: paragraphStyle
        ]

        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext

        if let maxWidth {
            let attrString = NSAttributedString(string: text, attributes: attributes)
            let constraintSize = CGSize(width: maxWidth, height: .greatestFiniteMagnitude)
            let boundingRect = attrString.boundingRect(
                with: constraintSize,
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            attrString.draw(in: CGRect(x: position.x, y: position.y, width: maxWidth, height: boundingRect.height))
        } else {
            text.draw(at: position, withAttributes: attributes)
        }

        NSGraphicsContext.restoreGraphicsState()
        updateCachedSize()
    }

    func copy() -> Annotation {
        let textAnnotation = TextAnnotation(position: position, text: text, color: color, font: font)
        textAnnotation.maxWidth = maxWidth
        textAnnotation.opacity = opacity
        return textAnnotation
    }
}
```

- [ ] **Step 4: Run the model tests again**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && swift test --filter AnnotationModelTests
```

Expected:

- `AnnotationModelTests` passes with `0 failures`

- [ ] **Step 5: Commit the model-layer changes**

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && \
git add \
  spoke/UI/Screenshot/Annotation.swift \
  spoke/Tests/AnnotationModelTests.swift && \
git commit -m "feat: add text annotation style primitives"
```

---

### Task 2: Make Text Draft / Selection / Editing State Explicit In AnnotationCanvasView

**Files:**
- Modify: `spoke/UI/Screenshot/AnnotationCanvasView.swift`
- Create: `spoke/Tests/AnnotationCanvasTextStateTests.swift`

- [ ] **Step 1: Write the failing canvas-state tests**

```swift
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
```

- [ ] **Step 2: Run the canvas-state tests to verify they fail**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && swift test --filter AnnotationCanvasTextStateTests
```

Expected:

- `AnnotationCanvasView` has no members `beginTextDraft`, `activeEditingTextAnnotation`, `selectedTextAnnotation`, `selectTextAnnotation`, or `beginEditingTextAnnotation`

- [ ] **Step 3: Add explicit text-state helpers and use them from the mouse / tool flow**

Update `spoke/UI/Screenshot/AnnotationCanvasView.swift`:

```swift
final class AnnotationCanvasView: NSView, AnnotationCanvas {
    private var defaultTextStyle = TextAnnotationStyle.default
    private var selectedTextAnnotationID: UUID?
    var onTextStyleChanged: ((TextAnnotationStyle, Bool) -> Void)?

    var activeEditingTextAnnotation: TextAnnotation? { editingTextAnnotation }
    var selectedTextAnnotation: TextAnnotation? {
        guard let selectedTextAnnotationID else { return nil }
        return annotations.first { $0.id == selectedTextAnnotationID } as? TextAnnotation
    }

    var currentTool: Tool = .none {
        didSet {
            if currentTool != .text {
                commitActiveTextIfNeeded(selectCommittedText: false)
                clearTextSelection()
            } else {
                publishTextStyleState()
            }
            updateCursor()
            hoveredAnnotation = nil
            window?.invalidateCursorRects(for: self)
        }
    }

    @discardableResult
    func beginTextDraft(at position: CGPoint) -> NSTextView {
        commitActiveTextIfNeeded(selectCommittedText: false)

        let textAnnotation = TextAnnotation(position: position, text: "")
        textAnnotation.style = defaultTextStyle
        editingTextAnnotation = textAnnotation
        clearTextSelection()

        let textView = createTextView(at: position, style: textAnnotation.style, existingText: "")
        addSubview(textView)
        editingTextView = textView
        window?.makeFirstResponder(textView)
        publishTextStyleState()
        return textView
    }

    private func createTextView(at position: CGPoint, style: TextAnnotationStyle, existingText: String) -> NSTextView {
        let textView = NSTextView(frame: CGRect(x: position.x, y: position.y - 2, width: 300, height: 100))
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textColor = style.color
        textView.font = .systemFont(ofSize: style.fontSize, weight: .medium)
        textView.insertionPointColor = style.color
        textView.isRichText = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = CGSize(width: 300, height: .greatestFiniteMagnitude)
        textView.string = existingText
        textView.delegate = self
        return textView
    }

    func commitActiveTextIfNeeded(selectCommittedText: Bool) {
        guard let textView = editingTextView, let textAnnotation = editingTextAnnotation else { return }
        let text = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)

        if !text.isEmpty {
            textAnnotation.text = text
            if let containerWidth = textView.textContainer?.containerSize.width {
                textAnnotation.maxWidth = containerWidth
            }
            addAnnotation(textAnnotation)
            selectedTextAnnotationID = selectCommittedText ? textAnnotation.id : nil
        }

        textView.removeFromSuperview()
        editingTextView = nil
        editingTextAnnotation = nil
        publishTextStyleState()
        needsDisplay = true
    }

    func clearTextSelection() {
        selectedTextAnnotationID = nil
        publishTextStyleState()
        needsDisplay = true
    }

    @discardableResult
    func selectTextAnnotation(at point: CGPoint) -> Bool {
        guard let annotation = findAnnotation(at: point) as? TextAnnotation else {
            clearTextSelection()
            return false
        }
        commitActiveTextIfNeeded(selectCommittedText: false)
        selectedTextAnnotationID = annotation.id
        publishTextStyleState()
        needsDisplay = true
        return true
    }

    @discardableResult
    func beginEditingTextAnnotation(at point: CGPoint) -> Bool {
        guard let annotation = findAnnotation(at: point) as? TextAnnotation else { return false }
        commitActiveTextIfNeeded(selectCommittedText: false)
        annotations.removeAll { $0.id == annotation.id }
        selectedTextAnnotationID = nil

        editingTextAnnotation = annotation
        let textView = createTextView(at: annotation.position, style: annotation.style, existingText: annotation.text)
        addSubview(textView)
        editingTextView = textView
        window?.makeFirstResponder(textView)
        publishTextStyleState()
        needsDisplay = true
        return true
    }
}
```

Update the event handlers to use the new helpers instead of open-coded text logic:

```swift
override func mouseDown(with event: NSEvent) {
    let location = convert(event.locationInWindow, from: nil)
    dragStartPoint = location

    if event.clickCount == 2 {
        if currentTool == .text, beginEditingTextAnnotation(at: location) { return }
        if currentTool == .text {
            beginTextDraft(at: location)
            return
        }
    }

    if currentTool == .text, selectTextAnnotation(at: location) {
        draggingAnnotation = selectedTextAnnotation
        draggingStartPosition = selectedTextAnnotation?.position ?? .zero
        return
    }

    switch currentTool {
    case .text:
        beginTextDraft(at: location)
    case .eraser:
        commitActiveTextIfNeeded(selectCommittedText: false)
        clearTextSelection()
        if let annotation = findAnnotation(at: location) { removeAnnotation(annotation) }
    case .arrow:
        currentAnnotation = ArrowAnnotation(
            start: location,
            end: location,
            color: currentColor,
            lineWidth: currentLineWidth
        )
    case .pen:
        currentAnnotation = PenAnnotation(
            points: [location],
            color: currentColor,
            lineWidth: currentBrushSize
        )
    case .marker:
        currentAnnotation = MarkerAnnotation(
            points: [location],
            color: currentColor,
            lineWidth: currentBrushSize
        )
    default:
        break
    }
}
```

- [ ] **Step 4: Run the canvas-state tests again**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && swift test --filter AnnotationCanvasTextStateTests
```

Expected:

- `AnnotationCanvasTextStateTests` passes with `0 failures`

- [ ] **Step 5: Commit the explicit text-state refactor**

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && \
git add \
  spoke/UI/Screenshot/AnnotationCanvasView.swift \
  spoke/Tests/AnnotationCanvasTextStateTests.swift && \
git commit -m "feat: add explicit screenshot text interaction state"
```

---

### Task 3: Expand ScreenshotToolbarView Inline When The Text Tool Is Active

**Files:**
- Modify: `spoke/UI/Screenshot/ScreenshotToolbarView.swift`
- Modify: `spoke/UI/Screenshot/RegionSelectionWindow.swift`
- Modify: `spoke/UI/Screenshot/RegionSelectionView.swift`
- Create: `spoke/Tests/ScreenshotToolbarInlineExpansionTests.swift`

- [ ] **Step 1: Write the failing toolbar-expansion tests**

```swift
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
```

- [ ] **Step 2: Run the toolbar tests to verify they fail**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && swift test --filter ScreenshotToolbarInlineExpansionTests
```

Expected:

- `ScreenshotToolbarView` has no members `isTextControlsVisible`, `setTextControlsVisible`, `displayedTextFontSize`, or `applyTextStyle`

- [ ] **Step 3: Add single-row inline text controls and wire them through the window / selection view**

Update `spoke/UI/Screenshot/ScreenshotToolbarView.swift`:

```swift
final class ScreenshotToolbarView: NSView {
    var onTextFontStep: ((CGFloat) -> Void)?
    var onTextColorSelected: ((NSColor) -> Void)?

    private let textControlsStackView = NSStackView()
    private let textFontValueLabel = NSTextField(labelWithString: "16")
    private var textColorButtons: [NSButton] = []
    private var textColorMap: [ObjectIdentifier: NSColor] = [:]

    var isTextControlsVisible: Bool { !textControlsStackView.isHidden }
    var displayedTextFontSize: String { textFontValueLabel.stringValue }

    private func createButtonGroups() {
        for action in ToolbarAction.annotationTools {
            let button = createButton(for: action)
            stackView.addArrangedSubview(button)

            if action == .text {
                buildInlineTextControlsIfNeeded()
                stackView.addArrangedSubview(textControlsStackView)
            }
        }

        stackView.addArrangedSubview(createSeparator())

        for action in ToolbarAction.historyActions {
            stackView.addArrangedSubview(createButton(for: action))
        }

        stackView.addArrangedSubview(createSeparator())

        for action in ToolbarAction.confirmActions {
            stackView.addArrangedSubview(createButton(for: action))
        }
    }

    private func buildInlineTextControlsIfNeeded() {
        textControlsStackView.orientation = .horizontal
        textControlsStackView.spacing = 4
        textControlsStackView.isHidden = true

        let decrease = ScreenshotToolbarButton(icon: "textformat.size.smaller", isEnabled: true)
        decrease.action = { [weak self] in self?.onTextFontStep?(-2) }

        let increase = ScreenshotToolbarButton(icon: "textformat.size.larger", isEnabled: true)
        increase.action = { [weak self] in self?.onTextFontStep?(2) }

        let palette: [NSColor] = [
            DesignTokens.Colors.NS.annotationText,
            DesignTokens.Colors.NS.annotationHighlight,
            DesignTokens.Colors.NS.annotationPrimary,
            .systemRed,
            .systemBlue
        ]

        textControlsStackView.addArrangedSubview(decrease)
        textControlsStackView.addArrangedSubview(textFontValueLabel)
        textControlsStackView.addArrangedSubview(increase)

        for color in palette {
            let swatch = makeColorSwatch(color: color)
            textControlsStackView.addArrangedSubview(swatch)
            textColorButtons.append(swatch)
            textColorMap[ObjectIdentifier(swatch)] = color
        }
    }

    private func makeColorSwatch(color: NSColor) -> NSButton {
        let button = NSButton(title: "", target: self, action: #selector(handleTextColorTap(_:)))
        button.wantsLayer = true
        button.layer?.backgroundColor = color.cgColor
        button.layer?.cornerRadius = 8
        button.layer?.borderColor = DesignTokens.Colors.NS.separatorStrong.cgColor
        button.layer?.borderWidth = 1
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 18),
            button.heightAnchor.constraint(equalToConstant: 18)
        ])
        return button
    }

    @objc private func handleTextColorTap(_ sender: NSButton) {
        guard let color = textColorMap[ObjectIdentifier(sender)] else { return }
        onTextColorSelected?(color)
    }

    private func highlightSelectedColor(_ color: NSColor) {
        for button in textColorButtons {
            button.layer?.borderColor = DesignTokens.Colors.NS.separatorStrong.cgColor
            button.layer?.borderWidth = 1
        }

        if let selectedButton = textColorButtons.first(where: {
            textColorMap[ObjectIdentifier($0)] == color
        }) {
            selectedButton.layer?.borderColor = DesignTokens.Colors.NS.accentPrimary.cgColor
            selectedButton.layer?.borderWidth = 2
        }
    }

    func setTextControlsVisible(_ visible: Bool) {
        textControlsStackView.isHidden = !visible
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    func applyTextStyle(_ style: TextAnnotationStyle, hasSelectedText: Bool) {
        textFontValueLabel.stringValue = String(Int(style.fontSize.rounded()))
        highlightSelectedColor(style.color)
    }
}
```

Update `spoke/UI/Screenshot/RegionSelectionView.swift`:

```swift
final class RegionSelectionView: NSView {
    var onTextStyleChanged: ((TextAnnotationStyle, Bool) -> Void)?

    private func setupAnnotationCanvas() {
        let canvas = AnnotationCanvasView(frame: selectionRect)
        canvas.onTextStyleChanged = { [weak self] style, hasSelectedText in
            self?.onTextStyleChanged?(style, hasSelectedText)
        }
        addSubview(canvas)
        annotationCanvas = canvas
    }

    func adjustTextFontSize(by delta: CGFloat) {
        annotationCanvas?.applyTextFontSizeStep(delta)
    }

    func applyTextColor(_ color: NSColor) {
        annotationCanvas?.applyTextColor(color)
    }
}
```

Update `spoke/UI/Screenshot/RegionSelectionWindow.swift`:

```swift
private func setupToolbar() {
    let toolbar = ScreenshotToolbarView()
    toolbar.onAction = { [weak self] action in
        self?.handleToolbarAction(action)
    }
    toolbar.onTextFontStep = { [weak self] delta in
        self?.selectionView.adjustTextFontSize(by: delta)
    }
    toolbar.onTextColorSelected = { [weak self] color in
        self?.selectionView.applyTextColor(color)
    }
    contentView?.addSubview(toolbar)
    toolbarView = toolbar
}

private func setupSelectionView() {
    selectionView.onTextStyleChanged = { [weak self] style, hasSelectedText in
        guard let self, let toolbar = self.toolbarView else { return }
        let isTextTool = self.selectionView.currentAnnotationTool == .text
        toolbar.setTextControlsVisible(isTextTool)
        toolbar.applyTextStyle(style, hasSelectedText: hasSelectedText)
        self.updateToolbarPosition()
    }
}

private func selectTool(_ tool: AnnotationCanvasView.Tool, action: ScreenshotToolbarView.ToolbarAction) {
    let currentTool = selectionView.currentAnnotationTool

    if currentTool == tool {
        selectionView.setAnnotationTool(.none)
        toolbarView?.deselectAllTools()
        toolbarView?.setTextControlsVisible(false)
    } else {
        selectionView.setAnnotationTool(tool)
        toolbarView?.setSelected(action, selected: true)
        toolbarView?.setTextControlsVisible(tool == .text)
    }
}
```

- [ ] **Step 4: Run the focused toolbar tests and one screenshot interaction suite**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && \
swift test --filter ScreenshotToolbarInlineExpansionTests && \
swift test --filter ScreenshotWindowInteractionTests
```

Expected:

- Inline toolbar tests pass
- Existing screenshot window interaction tests still pass unchanged

- [ ] **Step 5: Commit the inline-toolbar wiring**

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && \
git add \
  spoke/UI/Screenshot/ScreenshotToolbarView.swift \
  spoke/UI/Screenshot/RegionSelectionWindow.swift \
  spoke/UI/Screenshot/RegionSelectionView.swift \
  spoke/Tests/ScreenshotToolbarInlineExpansionTests.swift && \
git commit -m "feat: inline screenshot text controls"
```

---

### Task 4: Add Selected-Text Styling, Scroll-Based Adjustment, And Final Verification

**Files:**
- Modify: `spoke/UI/Screenshot/AnnotationCanvasView.swift`
- Modify: `spoke/UI/Screenshot/Annotation.swift`
- Modify: `spoke/Tests/AnnotationCanvasTextStateTests.swift`

- [ ] **Step 1: Extend the canvas tests to cover text-style mutation and tool gating**

Append to `spoke/Tests/AnnotationCanvasTextStateTests.swift`:

```swift
@Test("font step updates default text style when nothing is selected")
func fontStepUpdatesDefaultStyle() {
    let canvas = AnnotationCanvasView(frame: CGRect(x: 0, y: 0, width: 240, height: 160))
    canvas.currentTool = .text

    canvas.applyTextFontSizeStep(2)

    #expect(canvas.currentTextStyle.fontSize == 18)
}

@Test("selected text responds to font size and opacity changes only in text mode")
func selectedTextRespondsOnlyInTextMode() {
    let canvas = AnnotationCanvasView(frame: CGRect(x: 0, y: 0, width: 240, height: 160))
    let text = TextAnnotation(position: CGPoint(x: 40, y: 40), text: "hello")
    canvas.addAnnotation(text, recordCommand: false)

    canvas.currentTool = .text
    #expect(canvas.selectTextAnnotation(at: CGPoint(x: 44, y: 44)))

    canvas.applyTextFontSizeStep(4)
    canvas.adjustSelectedTextOpacity(by: -0.2)
    #expect(canvas.selectedTextAnnotation?.style.fontSize == 20)
    #expect(canvas.selectedTextAnnotation?.style.opacity == 0.8)

    canvas.currentTool = .pen
    canvas.applyTextFontSizeStep(4)
    #expect(canvas.selectedTextAnnotation == nil)
}
```

- [ ] **Step 2: Run the extended canvas tests to verify they fail**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && swift test --filter AnnotationCanvasTextStateTests
```

Expected:

- `AnnotationCanvasView` has no members `applyTextFontSizeStep`, `adjustSelectedTextOpacity`, or `currentTextStyle`

- [ ] **Step 3: Implement selected-text decoration and route scroll gestures into text style helpers**

Update `spoke/UI/Screenshot/AnnotationCanvasView.swift`:

```swift
final class AnnotationCanvasView: NSView, AnnotationCanvas {
    var currentTextStyle: TextAnnotationStyle {
        selectedTextAnnotation?.style ?? defaultTextStyle
    }

    func applyTextFontSizeStep(_ delta: CGFloat) {
        guard currentTool == .text else { return }

        if let selectedTextAnnotation {
            var style = selectedTextAnnotation.style
            style.fontSize = min(max(style.fontSize + delta, 12), 96)
            selectedTextAnnotation.style = style
        } else {
            defaultTextStyle.fontSize = min(max(defaultTextStyle.fontSize + delta, 12), 96)
        }

        publishTextStyleState()
        needsDisplay = true
    }

    func applyTextColor(_ color: NSColor) {
        guard currentTool == .text else { return }

        if let selectedTextAnnotation {
            var style = selectedTextAnnotation.style
            style.color = color
            selectedTextAnnotation.style = style
        } else {
            defaultTextStyle.color = color
        }

        if let editingTextView {
            editingTextView.textColor = color
            editingTextView.insertionPointColor = color
        }

        publishTextStyleState()
        needsDisplay = true
    }

    func adjustSelectedTextOpacity(by delta: CGFloat) {
        guard currentTool == .text, let selectedTextAnnotation else { return }

        var style = selectedTextAnnotation.style
        style.opacity = min(max(style.opacity + delta, 0.3), 1)
        selectedTextAnnotation.style = style
        publishTextStyleState()
        needsDisplay = true
    }

    private func publishTextStyleState() {
        onTextStyleChanged?(selectedTextAnnotation?.style ?? defaultTextStyle, selectedTextAnnotation != nil)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        for annotation in annotations {
            if let text = annotation as? TextAnnotation, text.id == selectedTextAnnotationID {
                drawSelectionDecoration(for: text, in: context)
            }
            annotation.draw(in: context)
        }

        currentAnnotation?.draw(in: context)
    }

    private func drawSelectionDecoration(for text: TextAnnotation, in context: CGContext) {
        let rect = text.boundingRect().insetBy(dx: -6, dy: -4)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 0), blur: 8, color: DesignTokens.Colors.NS.inkDark.withAlphaComponent(0.28).cgColor)
        context.setStrokeColor(DesignTokens.Colors.NS.accentPrimary.cgColor)
        context.setLineWidth(2)
        context.stroke(rect, width: 2)
        context.restoreGState()
    }

    override func scrollWheel(with event: NSEvent) {
        if currentTool == .text, selectedTextAnnotation != nil {
            if event.hasPreciseScrollingDeltas, abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) {
                adjustSelectedTextOpacity(by: event.scrollingDeltaX * 0.003)
            } else {
                applyTextFontSizeStep(event.scrollingDeltaY > 0 ? 2 : -2)
            }
            return
        }

        guard currentTool == .pen || currentTool == .marker else {
            super.scrollWheel(with: event)
            return
        }

        let delta = event.scrollingDeltaY
        guard delta != 0 else { return }

        let change = delta > 0 ? 1.0 : -1.0
        currentBrushSize = min(max(currentBrushSize + change, 1.0), 100.0)
        updateCursor()
        window?.invalidateCursorRects(for: self)
    }
}
```

- [ ] **Step 4: Run the full screenshot-editor verification set**

Run:

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke && \
swift test --filter AnnotationCanvasTextStateTests && \
swift build && \
swift test && \
bash Tests/run-concurrency-check.sh
```

Expected:

- `AnnotationCanvasTextStateTests` passes
- `swift build` succeeds
- `swift test` succeeds
- concurrency check reports `0` warnings

- [ ] **Step 5: Commit the final interaction polish**

```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere && \
git add \
  spoke/UI/Screenshot/AnnotationCanvasView.swift \
  spoke/UI/Screenshot/Annotation.swift \
  spoke/Tests/AnnotationCanvasTextStateTests.swift && \
git commit -m "feat: add screenshot text gesture controls"
```

---

## Manual Verification Checklist

- [ ] Draw a screenshot selection, switch to `Aa`, and verify the toolbar stays single-row while expanding inline after `Aa`.
- [ ] Double-click empty space, type text, then double-click another empty spot. The first draft should commit and the caret should move to the new location.
- [ ] Type text, then click `arrow`, `pen`, `marker`, and `eraser` one by one. The text caret should never keep blinking after the tool switch.
- [ ] Single-click a committed text block and verify `outline + outer shadow` appears and drag works.
- [ ] Double-click the same text block and verify it re-enters editing with the same text and style.
- [ ] With no selected text block, change inline font size / color and then create a new text block. The new block should inherit those defaults.
- [ ] Select an existing text block, change inline font size / color, and verify the selected block updates immediately.
- [ ] While `Aa` is active and a text block is selected, swipe up/down to change font size and left/right to change opacity.
- [ ] Switch away from `Aa` and verify the text block loses the active outline/shadow state.
- [ ] Use the eraser on text, arrow, pen, and marker objects. Each hit should remove the entire object.

---

## Spec Coverage Check

- Explicit draft / selected / editing state is covered by **Task 2**.
- The single-row inline `Aa` expansion is covered by **Task 3**.
- Text default-style vs selected-style behavior is covered by **Task 3** and **Task 4**.
- Trackpad font-size / opacity adjustment is covered by **Task 4**.
- Object-level eraser stability is covered by **Task 1** and re-verified manually in **Manual Verification Checklist**.
- Full engineering verification (`swift build`, `swift test`, concurrency) is covered by **Task 4**.

---

## Placeholder Scan

- No `TBD`, `TODO`, or deferred “implement later” steps remain.
- Every task includes exact files, test code, commands, and commit commands.

---

## Type Consistency Check

These names are used consistently across the plan and should not be renamed mid-implementation:

- `TextAnnotationStyle`
- `beginTextDraft(at:)`
- `commitActiveTextIfNeeded(selectCommittedText:)`
- `selectTextAnnotation(at:)`
- `beginEditingTextAnnotation(at:)`
- `applyTextFontSizeStep(_:)`
- `applyTextColor(_:)`
- `adjustSelectedTextOpacity(by:)`
- `onTextStyleChanged`
- `setTextControlsVisible(_:)`
- `applyTextStyle(_:hasSelectedText:)`
