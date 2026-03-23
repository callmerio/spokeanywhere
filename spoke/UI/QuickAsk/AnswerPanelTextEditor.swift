import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// AnswerPanel 文本输入区域（基于 NSTextView）
struct AnswerPanelTextEditor: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var onSend: (() -> Void)?
    var onPasteImage: ((NSImage) -> Void)?
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?
    var onDrop: (([NSItemProvider]) -> Void)?
    var onTextChange: ((String, Bool) -> Void)?
    var onWorkflowKeyEvent: ((NSEvent) -> Bool)?
    var isWorkflowPickerVisible: (() -> Bool)?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        configureScrollView(scrollView)
        
        let textView = AnswerPanelNSTextView()
        configureTextView(textView, context: context)
        
        scrollView.documentView = textView
        
        runAnswerPanelTextEditorOnMain {
            tryMakeFirstResponder(textView, attempt: 1)
        }
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? AnswerPanelNSTextView else { return }
        
        if textView.hasMarkedText() {
            return
        }
        
        if textView.string != text {
            textView.string = text
        }
        
        textView.onSend = onSend
        textView.onPasteImage = onPasteImage
        textView.onDragEntered = onDragEntered
        textView.onDragExited = onDragExited
        textView.onDrop = onDrop
        textView.onWorkflowKeyEvent = onWorkflowKeyEvent
        textView.isWorkflowPickerVisible = isWorkflowPickerVisible
        
        if textView.placeholderString != placeholder {
            textView.placeholderString = placeholder
            textView.needsDisplay = true
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func configureScrollView(_ scrollView: NSScrollView) {
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
    }
    
    private func configureTextView(_ textView: AnswerPanelNSTextView, context: Context) {
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = DesignTokens.Colors.NS.textPrimary
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = CGSize(width: 0, height: 4)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]
        
        textView.isSelectable = true
        textView.isEditable = true
        textView.allowsCharacterPickerTouchBarItem = true
        textView.insertionPointColor = DesignTokens.Colors.NS.textPrimary
        
        textView.onSend = onSend
        textView.onPasteImage = onPasteImage
        textView.onDragEntered = onDragEntered
        textView.onDragExited = onDragExited
        textView.onDrop = onDrop
        textView.onWorkflowKeyEvent = onWorkflowKeyEvent
        textView.isWorkflowPickerVisible = isWorkflowPickerVisible
        textView.placeholderString = placeholder
    }
    
    private func tryMakeFirstResponder(_ textView: AnswerPanelNSTextView, attempt: Int) {
        guard attempt <= 5, let window = textView.window else {
            if attempt <= 5 {
                let delay = 0.05 * Double(attempt)
                scheduleAnswerPanelTextEditorMain(after: delay) {
                    tryMakeFirstResponder(textView, attempt: attempt + 1)
                }
            }
            return
        }
        
        if !window.isKeyWindow {
            scheduleAnswerPanelTextEditorMain(after: 0.1) {
                tryMakeFirstResponder(textView, attempt: attempt + 1)
            }
            return
        }
        
        if window.makeFirstResponder(textView) {
            textView.inputContext?.activate()
        } else {
            scheduleAnswerPanelTextEditorMain(after: 0.1) {
                tryMakeFirstResponder(textView, attempt: attempt + 1)
            }
        }
    }
    
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AnswerPanelTextEditor
        
        init(_ parent: AnswerPanelTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.onTextChange?(textView.string, textView.hasMarkedText())
        }
    }
}

/// 处理键盘发送与粘贴图片
final class AnswerPanelNSTextView: NSTextView {
    var onSend: (() -> Void)?
    var onPasteImage: ((NSImage) -> Void)?
    var placeholderString: String = ""
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?
    var onDrop: (([NSItemProvider]) -> Void)?
    var onWorkflowKeyEvent: ((NSEvent) -> Bool)?
    var isWorkflowPickerVisible: (() -> Bool)?
    
    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setupTextView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextView()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTextView()
    }
    
    override var canBecomeKeyView: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    
    private func setupTextView() {
        isSelectable = true
        isEditable = true
        allowsCharacterPickerTouchBarItem = true
        isAutomaticTextCompletionEnabled = false
        importsGraphics = false
        
        registerForDraggedTypes([.fileURL, .png, .tiff])
    }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            inputContext?.activate()
        }
        return result
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDragEntered?()
        return .copy
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDragExited?()
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onDragExited?()
        
        guard let items = sender.draggingPasteboard.pasteboardItems else { return false }
        
        var providers: [NSItemProvider] = []
        for item in items {
            if let urlString = item.string(forType: .fileURL),
               let url = URL(string: urlString),
               let provider = NSItemProvider(contentsOf: url) {
                providers.append(provider)
            }
        }
        
        guard !providers.isEmpty else { return false }
        onDrop?(providers)
        return true
    }
    
    override func scrollWheel(with event: NSEvent) {
        if let scrollView = enclosingScrollView {
            scrollView.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }
    
    override func keyDown(with event: NSEvent) {
        if onWorkflowKeyEvent?(event) == true {
            return
        }
        super.keyDown(with: event)
    }
    
    override func doCommand(by selector: Selector) {
        if selector == #selector(insertTab(_:)) {
            super.doCommand(by: selector)
            return
        }
        
        if selector == #selector(insertNewline(_:)) {
            if markedRange().length > 0 {
                // 有 marked text，让输入法确认
                super.doCommand(by: selector)
            } else if isWorkflowPickerVisible?() == true {
                return
            } else if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                // Shift+Enter: 换行
                insertNewlineIgnoringFieldEditor(nil)
            } else {
                // 普通 Enter: 发送
                onSend?()
            }
            return
        }
        
        if selector == #selector(insertNewlineIgnoringFieldEditor(_:)) {
            // Shift+Enter 换行（备用）
            super.doCommand(by: selector)
            return
        }
        
        super.doCommand(by: selector)
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "v":
                paste(nil)
                return true
            case "c":
                copy(nil)
                return true
            case "x":
                cut(nil)
                return true
            case "a":
                selectAll(nil)
                return true
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
    
    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        
        if let tiffData = pasteboard.data(forType: .tiff),
           let image = NSImage(data: tiffData) {
            onPasteImage?(image)
            return
        }
        
        if let pngData = pasteboard.data(forType: .png),
           let image = NSImage(data: pngData) {
            onPasteImage?(image)
            return
        }
        
        if let image = pasteboard.readObjects(
            forClasses: [NSImage.self],
            options: nil
        )?.first as? NSImage {
            onPasteImage?(image)
            return
        }
        
        if let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] {
            for url in urls {
                if let uti = UTType(filenameExtension: url.pathExtension),
                   uti.conforms(to: .image),
                   let image = NSImage(contentsOf: url) {
                    onPasteImage?(image)
                    return
                }
            }
        }
        
        super.paste(sender)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if string.isEmpty && !placeholderString.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: DesignTokens.Colors.NS.textPlaceholder
            ]
            let placeholderRect = CGRect(
                x: textContainerInset.width,
                y: textContainerInset.height,
                width: bounds.width,
                height: bounds.height
            )
            placeholderString.draw(in: placeholderRect, withAttributes: attributes)
        }
    }
}
