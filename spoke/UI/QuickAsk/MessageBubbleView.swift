import AppKit
import SwiftUI

private typealias DS = DesignTokens

// MARK: - Selectable Text View

/// 可选择复制的文本视图（解决 SwiftUI Text 在 NSPanel 中 Cmd+C 不工作的问题）
struct SelectableTextView: NSViewRepresentable {
    let text: String
    let color: NSColor
    
    init(_ text: String, color: NSColor = DesignTokens.Colors.NS.textPrimary) {
        self.text = text
        self.color = color
    }
    
    func makeNSView(context: Context) -> SelectableTextLabel {
        let label = SelectableTextLabel(labelWithString: text)
        label.isEditable = false
        label.isSelectable = true
        label.isBordered = false
        label.drawsBackground = false
        label.font = .systemFont(ofSize: 14)
        label.textColor = color
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }
    
    func updateNSView(_ nsView: SelectableTextLabel, context: Context) {
        nsView.stringValue = text
        nsView.textColor = color
    }
}

/// 自定义 NSTextField 支持 Cmd+C 复制
class SelectableTextLabel: NSTextField {
    override var acceptsFirstResponder: Bool { true }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "c":
                // 获取选中的文字范围
                if let editor = currentEditor() as? NSTextView {
                    let range = editor.selectedRange()
                    if range.length > 0 {
                        let selectedText = (stringValue as NSString).substring(with: range)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(selectedText, forType: .string)
                        return true
                    }
                }
                // 如果没有选中，复制全部
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(stringValue, forType: .string)
                return true
            case "a":
                selectText(nil)
                return true
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: ChatMessage
    private let dependencies: MessageBubbleViewDependencies
    @State private var answerHeight: CGFloat = 100
    @ObservedObject private var ttsService: TTSService
    @State private var isCopied: Bool = false
    @State private var selectedMode: QuickAskMode = .chat

    init(
        message: ChatMessage,
        dependencies: MessageBubbleViewDependencies
    ) {
        self.message = message
        self.dependencies = dependencies
        self.ttsService = dependencies.ttsService
    }

    @MainActor
    init(message: ChatMessage) {
        self.init(message: message, dependencies: .live)
    }

    /// 保存图片到文件
    private func saveImage(_ image: NSImage) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.nameFieldStringValue = "generated_image.png"
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData) else { return }

            let isPNG = url.pathExtension.lowercased() == "png"
            let imageData = isPNG
                ? bitmap.representation(using: .png, properties: [:])
                : bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])

            try? imageData?.write(to: url)
        }
    }

    /// 解析消息内容，提取 Workflow keyword 和实际内容
    private var parsedContent: (workflowKeyword: String?, text: String) {
        let content = message.content
        guard content.hasPrefix("/") else { return (nil, content) }

        // 匹配 /keyword 格式
        let pattern = #"^/([a-zA-Z0-9_-]+)\s*(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(
                in: content,
                options: [],
                range: NSRange(content.startIndex..., in: content)
              ),
              let keywordRange = Range(match.range(at: 1), in: content) else {
            return (nil, content)
        }

        let keyword = String(content[keywordRange])
        let remainingText: String
        if let textRange = Range(match.range(at: 2), in: content) {
            remainingText = String(content[textRange]).trimmingCharacters(in: .whitespaces)
        } else {
            remainingText = ""
        }

        return (keyword, remainingText)
    }

    var body: some View {
        if message.role == .user {
            let parsed = parsedContent

            VStack(alignment: .trailing, spacing: 8) {
                // 上下文来源标签（参考 Gemini 样式）
                if !message.contextSources.isEmpty || message.screenshotImage != nil {
                    HStack(spacing: 8) {
                        ForEach(message.contextSources, id: \.rawValue) { source in
                            ContextSourceBadge(source: source)
                        }

                        // 截图缩略图
                        if let cgImage = message.screenshotImage {
                            let nsImage = NSImage(
                                cgImage: cgImage,
                                size: NSSize(width: cgImage.width, height: cgImage.height)
                            )
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(DS.Colors.borderSecondary, lineWidth: DS.BorderWidth.thin)
                                )
                        }
                    }
                }

                // 附件缩略图
                if !message.attachments.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(message.attachments) { attachment in
                            if let thumbnail = attachment.thumbnail {
                                Image(nsImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }

                // Workflow 标签 + 问题文字
                if parsed.workflowKeyword != nil || !parsed.text.isEmpty || message.voiceTranscription != nil {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 8) {
                            // Workflow 标签（方框样式）
                            if let keyword = parsed.workflowKeyword {
                                WorkflowTagBadge(keyword: keyword)
                            }

                            // 手动输入文字（使用 SelectableTextView 支持选中和 Cmd+C）
                            if !parsed.text.isEmpty {
                                SelectableTextView(parsed.text)
                            }
                        }
                        
                        // 语音转录（灰色，分行显示）
                        if let voiceText = message.voiceTranscription, !voiceText.isEmpty {
                            SelectableTextView(voiceText, color: DS.Colors.NS.textSecondary)
                        }
                    }
                    .padding(12)
                    .background(DS.Colors.buttonHoverStrong)
                    .clipShape(RoundedRectangle(cornerRadius: DS.CornerRadius.lg))
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                // AI 生成的图片
                if !message.generatedImages.isEmpty {
                    ForEach(Array(message.generatedImages.enumerated()), id: \.offset) { _, imageData in
                        if let nsImage = NSImage(data: imageData) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 400, maxHeight: 400)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .contextMenu {
                                    Button("复制图片") {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.writeObjects([nsImage])
                                    }
                                    Button("保存图片...") {
                                        saveImage(nsImage)
                                    }
                                }
                        }
                    }
                }

                // AI 回答内容 (Markdown)
                if !message.content.isEmpty {
                    MarkdownWebView(text: message.content, dynamicHeight: $answerHeight)
                        .frame(minHeight: answerHeight)
                }

                // 操作按钮
                HStack(spacing: 12) {
                    // 朗读按钮
                    Button(action: { ttsService.toggleSpeak(message.content) }, label: {
                        Image(systemName: ttsService.isPlaying ? "stop.circle.fill" : "speaker.wave.2.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(DS.Colors.textSecondary)
                    })
                    .buttonStyle(.plain)

                    // 复制按钮
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message.content, forType: .string)
                        isCopied = true
                        scheduleMessageBubbleMain(after: 2) {
                            isCopied = false
                        }
                    }, label: {
                        Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(isCopied ? DS.Colors.success : DS.Colors.textPlaceholder)
                    })
                    .buttonStyle(.plain)

                    Spacer()

                    // 模式显示 (仅展示，不交互)
                    HStack(spacing: 4) {
                        Image(systemName: selectedMode.icon)
                            .font(.system(size: 12))
                        Text(selectedMode.rawValue)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(DS.Colors.textPlaceholder)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DS.Colors.chipBackground)
                    .clipShape(Capsule())
                }
            }
        }
    }
}

// MARK: - Context Source Badge

/// 上下文来源标签（参考 Gemini 样式）
struct ContextSourceBadge: View {
    let source: ContextSource

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: source.icon)
                .font(.system(size: 10))
            Text(source.rawValue)
                .font(.system(size: 11))
        }
        .foregroundStyle(DS.Colors.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(DS.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.CornerRadius.md)
                .stroke(DS.Colors.borderSecondary, lineWidth: DS.BorderWidth.thin)
        )
    }
}
