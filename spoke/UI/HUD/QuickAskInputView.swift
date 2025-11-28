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
    
    /// 拖拽状态（已移至 CapsuleView）
    // @State private var isDragOver = false
    
    var body: some View {
        // 主内容
        VStack(alignment: .leading, spacing: 8) {
            // 附件区域（最上层）
            if !state.attachments.isEmpty {
                attachmentsArea
            }
            
            // 输入框
            inputField
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    // MARK: - Attachments Area
    
    private var attachmentsArea: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(state.attachments) { attachment in
                    AttachmentThumbnail(
                        attachment: attachment,
                        onRemove: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                state.removeAttachment(attachment.id)
                            }
                        }
                    )
                }
            }
            .padding(.vertical, 4) // 给删除按钮留出空间
        }
        .frame(height: 68) // 52 + 8 (删除按钮偏移) + 8 (padding)
        .clipped() // 确保不超出边界
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
            }
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
        
        // 🚫 禁止 NSTextView 接收拖拽，将事件让给外层 SwiftUI 处理
        textView.unregisterDraggedTypes()
        
        // 设置回调
        textView.onSend = onSend
        textView.onPasteImage = onPasteImage
        
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
class QuickAskNSTextView: NSTextView {
    var onSend: (() -> Void)?
    var onPasteImage: ((NSImage) -> Void)?
    var placeholderString: String = ""
    
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

// MARK: - Attachment Thumbnail

struct AttachmentThumbnail: View {
    let attachment: QuickAskAttachment
    var onRemove: (() -> Void)?
    
    @State private var isHovering = false
    @State private var videoThumbnail: NSImage? // 视频缩略图（异步加载）
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 内容
            contentView
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(HUDTheme.borderSecondary, lineWidth: 0.5)
                )
            
            // 删除按钮（Hover 时显示）
            if isHovering {
                Button(action: { onRemove?() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .background(Circle().fill(Color.black.opacity(0.6)))
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch attachment {
        case .image(_, let thumbnail, _), .screenshot(_, let thumbnail, _):
            // 优先使用缩略图，没有则显示加载占位
            if let thumb = thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // 缩略图生成中，显示加载状态
                ZStack {
                    HUDTheme.cardBackground
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            
        case .file(let url, _):
            // 视频文件：显示视频缩略图
            if attachment.isVideo {
                ZStack {
                    if let thumb = videoThumbnail {
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        // 加载中
                        HUDTheme.cardBackground
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                    
                    // 播放图标
                    Image(systemName: "play.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.8))
                        .shadow(radius: 2)
                }
                .onAppear {
                    loadVideoThumbnail(url: url)
                }
            } else {
                // 普通文件：图标 + 扩展名
                ZStack {
                    HUDTheme.cardBackground
                    
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                    
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(url.pathExtension.uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(HUDTheme.textPrimary)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(Color.black.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    .padding(4)
                }
            }
        }
    }
    
    /// 异步加载视频缩略图
    private func loadVideoThumbnail(url: URL) {
        Task.detached(priority: .userInitiated) {
            let thumbnail = QuickAskAttachment.makeVideoThumbnail(from: url)
            await MainActor.run {
                self.videoThumbnail = thumbnail
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let state = QuickAskState()
    state.phase = .recording
    
    return QuickAskInputView(state: state)
        .frame(width: 340, height: 150)
        .background(Color.black.opacity(0.8))
}
