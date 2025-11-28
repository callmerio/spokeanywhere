import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Quick Ask 输入区域视图
/// 布局：附件缩略图（上）+ 输入框（下）
/// 键盘：Shift+Enter 换行，Enter/⌘+Enter 发送，ESC 取消
/// 支持：剪贴板粘贴图片、拖拽文件
struct QuickAskInputView: View {
    @Bindable var state: QuickAskState
    
    /// 发送回调
    var onSend: (() -> Void)?
    /// 取消回调
    var onCancel: (() -> Void)?
    /// 拖拽进入回调（显示蓝色蒙版）
    var onDragEntered: (() -> Void)?
    /// 拖拽退出回调
    var onDragExited: (() -> Void)?
    /// 拖拽放下回调
    var onDrop: (([NSItemProvider]) -> Void)?
    
    var body: some View {
        // 主内容
        VStack(alignment: .leading, spacing: 8) {
            // 附件区域（最上层）
            if !state.attachments.isEmpty {
                attachmentsArea
            }
            
            // 输入框（加号按钮已移至左下角 appIcon 位置）
            inputField
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
    
    // MARK: - Attachments Area
    
    private var attachmentsArea: some View {
        AttachmentsAreaView(
            attachments: state.attachments,
            onRemove: { id in
                withAnimation(.easeInOut(duration: 0.2)) {
                    state.removeAttachment(id)
                }
            }
        )
    }
    
    // MARK: - Input Field
    
    private var inputField: some View {
        // 使用自定义 NSTextView 包装器
        QuickAskTextEditor(
            text: $state.userInput,
            placeholder: "Ask anything...",
            onSend: {
                if state.canSend {
                    onSend?()
                }
            },
            onPasteImage: { image in
                state.addImage(image)
            },
            onDragEntered: onDragEntered,
            onDragExited: onDragExited,
            onDrop: onDrop
        )
        .frame(minHeight: 20, maxHeight: 200) // 动态增高，最大 200
    }
}

// MARK: - Quick Ask Text Editor (NSTextView Wrapper)

/// 自定义文本编辑器
/// - Shift+Enter: 换行
/// - Enter / ⌘+Enter: 发送
/// - ⌘+V: 支持粘贴图片
struct QuickAskTextEditor: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var onSend: (() -> Void)?
    var onPasteImage: ((NSImage) -> Void)?
    /// 拖拽进入回调
    var onDragEntered: (() -> Void)?
    /// 拖拽退出回调
    var onDragExited: (() -> Void)?
    /// 拖拽放下回调
    var onDrop: (([NSItemProvider]) -> Void)?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true  // 开启垂直滚动
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true   // 自动隐藏滚动条
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay    // 覆盖式滚动条，不占空间
        
        let textView = QuickAskNSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = HUDTheme.NS.textPrimary
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 0, height: 4)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]  // 宽度跟随
        
        // ✅ 启用选择和编辑功能
        textView.isSelectable = true
        textView.isEditable = true
        textView.allowsCharacterPickerTouchBarItem = true
        
        // ✅ 设置正确的光标颜色
        textView.insertionPointColor = .white
        
        // 设置回调
        textView.onSend = onSend
        textView.onPasteImage = onPasteImage
        textView.onDragEntered = onDragEntered
        textView.onDragExited = onDragExited
        textView.onDrop = onDrop
        
        scrollView.documentView = textView
        
        // 延迟聚焦
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            textView.window?.makeFirstResponder(textView)
        }
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? QuickAskNSTextView else { return }
        
        // 更新文本
        if textView.string != text {
            textView.string = text
        }
        
        // 更新回调
        textView.onSend = onSend
        textView.onPasteImage = onPasteImage
        textView.onDragEntered = onDragEntered
        textView.onDragExited = onDragExited
        textView.onDrop = onDrop
        
        // 更新 placeholder
        textView.placeholderString = placeholder
        textView.needsDisplay = true
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: QuickAskTextEditor
        
        init(_ parent: QuickAskTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

/// 自定义 NSTextView，处理键盘事件
/// 禁用拖拽功能，让父视图处理
class QuickAskNSTextView: NSTextView {
    var onSend: (() -> Void)?
    var onPasteImage: ((NSImage) -> Void)?
    var placeholderString: String = ""
    
    /// 拖拽进入回调
    var onDragEntered: (() -> Void)?
    /// 拖拽退出回调
    var onDragExited: (() -> Void)?
    /// 拖拽放下回调
    var onDrop: (([NSItemProvider]) -> Void)?
    
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
    
    private func setupTextView() {
        // 确保文本选择功能正常
        isSelectable = true
        isEditable = true
        
        // 注册拖拽类型（我们要自己处理）
        registerForDraggedTypes([.fileURL, .png, .tiff])
    }
    
    // MARK: - Drag & Drop（禁用默认行为，转发给父视图）
    
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
        
        // 获取拖拽的文件 URL
        guard let items = sender.draggingPasteboard.pasteboardItems else { return false }
        
        var providers: [NSItemProvider] = []
        for item in items {
            if let urlString = item.string(forType: .fileURL),
               let url = URL(string: urlString) {
                let provider = NSItemProvider(contentsOf: url)
                if let provider = provider {
                    providers.append(provider)
                }
            }
        }
        
        if !providers.isEmpty {
            onDrop?(providers)
            return true
        }
        
        return false
    }
    
    /// 确保滚轮事件传递给 ScrollView
    override func scrollWheel(with event: NSEvent) {
        // 让父级 ScrollView 处理滚动
        if let scrollView = enclosingScrollView {
            scrollView.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }
    
    override func keyDown(with event: NSEvent) {
        let isShiftPressed = event.modifierFlags.contains(.shift)
        
        // Enter 键
        if event.keyCode == 36 { // Return key
            if isShiftPressed {
                // Shift+Enter: 换行
                super.keyDown(with: event)
            } else {
                // Enter 或 ⌘+Enter: 发送
                onSend?()
            }
            return
        }
        
        super.keyDown(with: event)
    }
    
    /// 捕获 ⌘V 等快捷键
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "v":
                // ⌘V: 粘贴
                paste(nil)
                return true
            case "c":
                // ⌘C: 复制
                copy(nil)
                return true
            case "x":
                // ⌘X: 剪切
                cut(nil)
                return true
            case "a":
                // ⌘A: 全选
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
        
        // 1. 优先检查 TIFF 数据（macOS 截图格式）
        if let tiffData = pasteboard.data(forType: .tiff),
           let image = NSImage(data: tiffData) {
            onPasteImage?(image)
            return
        }
        
        // 2. 检查 PNG 数据
        if let pngData = pasteboard.data(forType: .png),
           let image = NSImage(data: pngData) {
            onPasteImage?(image)
            return
        }
        
        // 3. 通用图片对象检查
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            onPasteImage?(image)
            return
        }
        
        // 4. 检查图片文件 URL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            for url in urls {
                if let uti = UTType(filenameExtension: url.pathExtension),
                   uti.conforms(to: .image),
                   let image = NSImage(contentsOf: url) {
                    onPasteImage?(image)
                    return
                }
            }
        }
        
        // 5. 普通文本粘贴
        super.paste(sender)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // 绘制 placeholder
        if string.isEmpty && !placeholderString.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: HUDTheme.NS.textPlaceholder
            ]
            let placeholderRect = NSRect(x: textContainerInset.width, y: textContainerInset.height, width: bounds.width, height: bounds.height)
            placeholderString.draw(in: placeholderRect, withAttributes: attributes)
        }
    }
}

// MARK: - Legacy Attachment Thumbnail (deprecated, use AttachmentThumbnailView instead)
/// 向后兼容的类型别名
typealias AttachmentThumbnail = AttachmentThumbnailView

// MARK: - Preview

#Preview {
    let state = QuickAskState()
    state.phase = .recording
    
    return QuickAskInputView(state: state)
        .frame(width: 340, height: 150)
        .background(Color.black.opacity(0.8))
}
