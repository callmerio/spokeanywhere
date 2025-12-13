import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Quick Ask 模式
enum QuickAskMode: String, CaseIterable {
    case chat = "Chat"
    case deepResearch = "DeepResearch"
    case canvas = "Canvas"
    case mind = "Mind"
    
    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .deepResearch: return "magnifyingglass"
        case .canvas: return "paintbrush"
        case .mind: return "brain.head.profile"
        }
    }
}

/// 消息角色
enum MessageRole: Equatable {
    case user
    case assistant
}

/// 聊天消息模型
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let attachments: [QuickAskAttachment]
    /// AI 生成的图片（仅 assistant 消息有效）
    let generatedImages: [Data]
    var timestamp = Date()
    
    init(role: MessageRole, content: String, attachments: [QuickAskAttachment], generatedImages: [Data] = []) {
        self.role = role
        self.content = content
        self.attachments = attachments
        self.generatedImages = generatedImages
    }
}

/// 回答面板状态
@Observable
@MainActor
final class AnswerPanelState {
    var messages: [ChatMessage] = []
    var isLoading: Bool = false
    var error: String?
    var suggestedQuestions: [String] = []
    
    // 兼容旧代码的计算属性
    var answer: String {
        messages.last(where: { $0.role == .assistant })?.content ?? ""
    }
}

/// Quick Ask 回答面板视图
struct AnswerPanelView: View {
    @Bindable var state: AnswerPanelState
    
    @State private var followUpInput: String = ""
    
    /// Workflow 状态
    @State private var workflowState = WorkflowState.shared
    
    /// 录音状态
    @State private var isRecording: Bool = false
    @State private var audioLevels: [Float] = Array(repeating: 0.05, count: 40)
    
    // Markdown Height (初始值设大一点，避免加载时截断)
    @State private var answerHeight: CGFloat = 200
    // Toolbar Hover State
    @State private var isHoveringToolbar: Bool = false
    @State private var isHoveringCloseButton: Bool = false
    @State private var isHoveringNewChatButton: Bool = false
    
    // 操作按钮状态
    @State private var isCopied: Bool = false
    @ObservedObject private var ttsService = TTSService.shared
    @ObservedObject private var ttsSettings = TTSSettings.shared
    
    // 模式选择
    @State private var selectedMode: QuickAskMode = .chat
    
    // 自动朗读追踪
    @State private var lastAutoReadAnswer: String = ""
    
    // 待发送附件
    @State private var pendingAttachments: [Attachment] = []
    
    // 拖拽状态
    @State private var isDragOver: Bool = false
    
    /// 关闭回调
    var onClose: (() -> Void)?
    /// 追问回调
    var onFollowUp: ((String, [Attachment]) -> Void)?
    /// 新对话回调
    var onNewChat: (() -> Void)?
    /// 重新生成回调
    var onRegenerate: (() -> Void)?
    
    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // 顶部占位 (避免内容被 Toolbar 遮挡，或者留白)
                Color.clear.frame(height: 10)
                
                // 对话内容区
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // 消息列表
                            ForEach(state.messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }
                            
                            // Loading
                            if state.isLoading {
                                loadingView
                            } else if let error = state.error {
                                errorView(error)
                            }
                            
                            // 推荐问题 (仅在非 loading 且无错误时显示)
                            if !state.isLoading && state.error == nil && !state.suggestedQuestions.isEmpty {
                                suggestedQuestionsView
                            }
                        }
                        .padding(16)
                        .padding(.top, 20) // 额外顶部内边距
                    }
                    .onChange(of: state.messages) { _, messages in
                        if let lastId = messages.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // 底部输入框
                inputArea
            }
            
            // Workflow Picker（悬浮在对话上方，Z-index 高于对话内容）
            if workflowState.isPickerVisible {
                VStack {
                    Spacer()
                    workflowPickerOverlay
                }
            }
            
            // 顶部 Hover 区域 (固定高度，包含 toolbar)
            ZStack(alignment: .top) {
                // 透明热区 (始终存在，确保 hover 检测)
                Color.clear
                    .frame(height: 56)
                
                // toolbar (受 opacity 控制)
                toolbar
                    .opacity(isHoveringToolbar ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isHoveringToolbar)
            }
            .frame(maxWidth: .infinity, maxHeight: 56, alignment: .top)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHoveringToolbar = hovering
                }
            }
        }
        .background(
            ZStack {
                // 磨砂玄效果
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                // 深色叠加
                Color.black.opacity(0.4)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .background {
            // 隐藏的快捷键监听：Cmd + , 打开设置
            Button("") {
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            .hidden()
            
            // Cmd + W 关闭窗口
            Button("") {
                onClose?()
            }
            .keyboardShortcut("w", modifiers: .command)
            .hidden()
        }
        .onChange(of: state.isLoading) { _, isLoading in
            // 当 loading 结束且有回复时，触发自动朗读
            if !isLoading && !state.answer.isEmpty && ttsSettings.autoReadAloud {
                // 避免重复朗读同一段内容
                if state.answer != lastAutoReadAnswer {
                    lastAutoReadAnswer = state.answer
                    ttsService.speak(state.answer)
                }
            }
        }
        .onDisappear {
            // 页面消失时停止 TTS
            ttsService.stop()
        }
    }
    
    /// 打开设置窗口
    private func openSettings() {
        // 通过 AppDelegate 打开设置
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.openSettings()
        }
    }
    
    // MARK: - Toolbar
    
    private var toolbar: some View {
        HStack(spacing: 12) {
            // 关闭按钮 (hover: 圆形 → 圆角正方形)
            Button(action: { onClose?() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(isHoveringCloseButton ? 0.9 : 0.6))
                    .frame(width: 22, height: 22)
                    .background(Color.white.opacity(isHoveringCloseButton ? 0.15 : 0.1))
                    .clipShape(RoundedRectangle(cornerRadius: isHoveringCloseButton ? 6 : 11))
                    .animation(.easeInOut(duration: 0.2), value: isHoveringCloseButton)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHoveringCloseButton = hovering
            }
            
            Spacer()
            
            // 新对话按钮 (hover: 胶囊 → 圆角长方形)
            Button(action: { onNewChat?() }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                    Text("新对话")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.white.opacity(isHoveringNewChatButton ? 1.0 : 0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(isHoveringNewChatButton ? 0.15 : 0))
                .clipShape(RoundedRectangle(cornerRadius: isHoveringNewChatButton ? 6 : 12))
                .animation(.easeInOut(duration: 0.2), value: isHoveringNewChatButton)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHoveringNewChatButton = hovering
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    // MARK: - Loading
    
    private var loadingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("思考中...")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Error
    
    private func errorView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Suggested Questions
    
    private var suggestedQuestionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(state.suggestedQuestions, id: \.self) { question in
                Button(action: { onFollowUp?(question, []) }) {
                    HStack {
                        Text(question)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(2)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Workflow Picker Overlay
    
    /// 悬浮的 Workflow Picker（覆盖在对话上方，不挡住输入框）
    private var workflowPickerOverlay: some View {
        WorkflowPickerView(
            filter: workflowState.filterKeyword,
            onSelect: { workflow in
                selectWorkflowForInput(workflow)
            }
        )
        .frame(maxWidth: .infinity, maxHeight: 200)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            ZStack {
                VisualEffectBackground(material: .popover, blendingMode: .behindWindow)
                Color.black.opacity(0.3) // 更透明
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 16, y: -4)
        .padding(.horizontal, 16)
        .padding(.bottom, 140) // 往上移，避免交错
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeOut(duration: 0.2), value: workflowState.isPickerVisible)
    }
    
    /// 选择 Workflow 后显示标签在输入框中，等待用户继续输入
    private func selectWorkflowForInput(_ workflow: WorkflowAction) {
        workflowState.select(workflow)
        followUpInput = ""
    }
    
    // MARK: - Input Area
    
    private var inputArea: some View {
        inputAreaContent
            .padding(14)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .overlay {
                AttachmentDropOverlay(cornerRadius: 14, isVisible: isDragOver)
            }
            .onDrop(of: [.image, .fileURL], isTargeted: $isDragOver) { providers in
                handleDropProviders(providers)
                return true
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .padding(.top, 8)
    }
    
    private var inputAreaContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 待发送附件预览
            if !pendingAttachments.isEmpty {
                pendingAttachmentsView
            }
            
            // 文本输入或录音
            if !isRecording {
                textEditorView
            } else {
                recordingWaveform
            }
            
            // 底部工具栏
            inputToolbar
        }
    }
    
    private var pendingAttachmentsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(pendingAttachments) { attachment in
                    AttachmentThumbnailView(
                        attachment: attachment,
                        onRemove: { removeAttachment(attachment.id) },
                        size: 60
                    )
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
        }
    }
    
    private var textEditorView: some View {
        HStack(alignment: .top, spacing: 8) {
            // Workflow 标签（选中后显示）
            if let workflow = workflowState.selectedWorkflow {
                WorkflowTagView(keyword: workflow.keyword) {
                    workflowState.reset()
                }
            }
            
            AnswerPanelTextEditor(
                text: $followUpInput,
                placeholder: workflowState.selectedWorkflow != nil ? "输入内容..." : "继续追问...",
                onSend: { sendMessage() },
                onPasteImage: { image in handlePasteImage(image) },
                onTextChange: { text, hasMarkedText in
                    _ = workflowState.detectSlashPrefix(text: text, hasMarkedText: hasMarkedText)
                }
            )
            .frame(minHeight: 20, maxHeight: 60)
        }
    }
    
    private var inputToolbar: some View {
        HStack(spacing: 12) {
            AttachmentPickerMenu(onAdd: { attachment in
                withAnimation { pendingAttachments.append(attachment) }
            })
            
            Spacer()
            
            if !isRecording {
                Button(action: { toggleRecording() }) {
                    Image(systemName: "mic")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            
            sendButton
        }
        .padding(.top, 4)
    }
    
    private var sendButton: some View {
        Button(action: { sendMessage() }) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(canSend ? Color.accentColor : Color.white.opacity(0.2))
        }
        .buttonStyle(.plain)
        .disabled(!canSend && !isRecording)
    }
    
    private var canSend: Bool {
        !followUpInput.isEmpty || !pendingAttachments.isEmpty
    }
    
    private func sendMessage() {
        guard canSend else { return }
        
        // 如果选中了 Workflow，带上 /keyword 前缀
        var message = followUpInput
        if let workflow = workflowState.selectedWorkflow {
            message = "/\(workflow.keyword) \(followUpInput)".trimmingCharacters(in: .whitespaces)
        }
        
        onFollowUp?(message, pendingAttachments)
        followUpInput = ""
        pendingAttachments = []
        workflowState.reset()
    }
    
    private func removeAttachment(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            pendingAttachments.removeAll { $0.id == id }
        }
    }
    
    private func handlePasteImage(_ image: NSImage) {
        AttachmentManager.shared.addImage(image, source: .paste) { attachment in
            withAnimation { pendingAttachments.append(attachment) }
        }
    }
    
    private func handleDropProviders(_ providers: [NSItemProvider]) {
        AttachmentManager.shared.handleDrop(providers: providers) { attachment in
            withAnimation { pendingAttachments.append(attachment) }
        }
    }
    
    // MARK: - Recording Waveform
    
    /// 录音波纹动画（红色风格）
    private var recordingWaveform: some View {
        HStack(spacing: 8) {
            // 录音指示点
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .opacity(isRecording ? 1 : 0.5)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isRecording)
            
            Text("Recording")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
            
            Spacer()
            
            // 波纹条
            HStack(spacing: 2) {
                ForEach(0..<20, id: \.self) { index in
                    let level = audioLevels[index % audioLevels.count]
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white.opacity(0.7))
                        .frame(width: 2, height: CGFloat(level) * 16 + 4)
                        .animation(.easeInOut(duration: 0.1), value: level)
                }
            }
            .frame(height: 24)
            
            Spacer()
            
            // 停止按钮
            Button(action: { toggleRecording() }) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .frame(height: 32)
        .onAppear {
            startWaveformAnimation()
        }
        .onDisappear {
            stopWaveformAnimation()
        }
    }
    
    // MARK: - Recording Actions
    
    private func toggleRecording() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isRecording.toggle()
        }
        
        if isRecording {
            startWaveformAnimation()
            // TODO: 实际开始录音
        } else {
            stopWaveformAnimation()
            // TODO: 停止录音并转录
        }
    }
    
    private func startWaveformAnimation() {
        // 模拟波纹动画
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if !isRecording {
                timer.invalidate()
                return
            }
            
            withAnimation(.easeInOut(duration: 0.1)) {
                audioLevels = audioLevels.map { _ in Float.random(in: 0.1...1.0) }
            }
        }
    }
    
    private func stopWaveformAnimation() {
        audioLevels = Array(repeating: 0.05, count: 40)
    }
}

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: ChatMessage
    @State private var answerHeight: CGFloat = 100
    @ObservedObject private var ttsService = TTSService.shared
    @State private var isCopied: Bool = false
    @State private var selectedMode: QuickAskMode = .chat
    
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
              let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
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
                if parsed.workflowKeyword != nil || !parsed.text.isEmpty {
                    HStack(spacing: 8) {
                        // Workflow 标签（方框样式）
                        if let keyword = parsed.workflowKeyword {
                            WorkflowTagBadge(keyword: keyword)
                        }
                        
                        // 问题文字
                        if !parsed.text.isEmpty {
                            Text(parsed.text)
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                // AI 生成的图片
                if !message.generatedImages.isEmpty {
                    ForEach(Array(message.generatedImages.enumerated()), id: \.offset) { index, imageData in
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
                HStack(spacing: 16) {
                    // 朗读按钮
                    Button(action: { ttsService.toggleSpeak(message.content) }) {
                        Image(systemName: ttsService.isPlaying ? "stop.circle.fill" : "speaker.wave.2.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    
                    // 复制按钮
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message.content, forType: .string)
                        isCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isCopied = false
                        }
                    }) {
                        Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(isCopied ? Color.green : .white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    // 模式显示 (仅展示，不交互)
                    HStack(spacing: 4) {
                        Image(systemName: selectedMode.icon)
                            .font(.system(size: 12))
                        Text(selectedMode.rawValue)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
            }
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let quickAskFollowUpRequested = Notification.Name("QuickAskFollowUpRequested")
}

// MARK: - Answer Panel Window

/// 自定义 Panel 以支持 Key Window 和输入法
class AnswerPanelWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Answer Panel Instance

/// 单个回答面板实例
@MainActor
final class AnswerPanelInstance {
    let id: UUID
    let state: AnswerPanelState
    var window: NSWindow?
    
    init(id: UUID = UUID()) {
        self.id = id
        self.state = AnswerPanelState()
    }
}

// MARK: - Answer Panel Manager

/// 回答面板管理器（支持多窗口）
@MainActor
final class AnswerPanelManager {
    
    // MARK: - Singleton
    
    static let shared = AnswerPanelManager()
    
    // MARK: - Properties
    
    /// 所有活跃的面板实例
    private var panels: [UUID: AnswerPanelInstance] = [:]
    
    /// 窗口位置偏移（用于级联排列新窗口）
    private var windowOffset: CGFloat = 0
    private let offsetStep: CGFloat = 30
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Public API
    
    /// 创建并显示新的回答面板，返回 panelId
    /// - Parameters:
    ///   - question: 用户问题
    ///   - attachments: 附件列表
    ///   - anchorPoint: 可选锚点位置（AppKit 坐标系），面板将显示在此位置下方
    @discardableResult
    func show(question: String, attachments: [QuickAskAttachment], anchorPoint: CGPoint? = nil) -> UUID {
        let instance = AnswerPanelInstance()
        let panelId = instance.id
        
        // 初始化状态
        instance.state.messages = [
            ChatMessage(role: .user, content: question, attachments: attachments)
        ]
        instance.state.isLoading = true
        instance.state.error = nil
        instance.state.suggestedQuestions = []
        
        // 创建窗口
        createWindow(for: instance)
        
        // 存储实例
        panels[panelId] = instance
        
        // 设置窗口位置
        if let anchor = anchorPoint, let window = instance.window {
            positionWindow(window, belowAnchor: anchor)
        }
        
        // 显示窗口
        instance.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        return panelId
    }
    
    /// 在指定锚点下方显示面板（用于 Selection Toolbar 触发）
    /// - Parameters:
    ///   - question: 用户问题
    ///   - anchorPoint: 锚点位置（AppKit 坐标系），面板将显示在此位置下方
    @discardableResult
    func showBelowAnchor(question: String, attachments: [QuickAskAttachment] = [], anchorPoint: CGPoint) -> UUID {
        return show(question: question, attachments: attachments, anchorPoint: anchorPoint)
    }
    
    /// 更新指定面板的回答（支持图片）
    func updateAnswer(_ response: LLMResponse, for panelId: UUID) {
        guard let instance = panels[panelId] else { return }
        
        if let lastMsg = instance.state.messages.last, lastMsg.role == .assistant {
            let updatedMsg = ChatMessage(role: .assistant, content: response.text, attachments: [], generatedImages: response.images)
            instance.state.messages[instance.state.messages.count - 1] = updatedMsg
        } else {
            instance.state.messages.append(ChatMessage(role: .assistant, content: response.text, attachments: [], generatedImages: response.images))
        }
        
        instance.state.isLoading = false
        instance.state.suggestedQuestions = []
    }
    
    /// 兼容旧 API（纯文本回答）
    func updateAnswer(_ answer: String, for panelId: UUID) {
        updateAnswer(LLMResponse(text: answer), for: panelId)
    }
    
    /// 兼容旧 API（更新最近创建的面板）
    func updateAnswer(_ answer: String) {
        guard let lastPanel = panels.values.max(by: { 
            ($0.state.messages.first?.timestamp ?? .distantPast) < ($1.state.messages.first?.timestamp ?? .distantPast) 
        }) else { return }
        updateAnswer(answer, for: lastPanel.id)
    }
    
    /// 追加用户消息到指定面板
    func appendUserMessage(_ content: String, attachments: [QuickAskAttachment], for panelId: UUID) {
        guard let instance = panels[panelId] else { return }
        instance.state.messages.append(ChatMessage(role: .user, content: content, attachments: attachments))
        instance.state.isLoading = true
        instance.state.error = nil
    }
    
    /// 显示错误到指定面板
    func showError(_ message: String, for panelId: UUID) {
        guard let instance = panels[panelId] else { return }
        instance.state.error = message
        instance.state.isLoading = false
    }
    
    /// 兼容旧 API
    func showError(_ message: String) {
        guard let lastPanel = panels.values.max(by: { 
            ($0.state.messages.first?.timestamp ?? .distantPast) < ($1.state.messages.first?.timestamp ?? .distantPast) 
        }) else { return }
        showError(message, for: lastPanel.id)
    }
    
    /// 关闭指定面板
    func hide(panelId: UUID) {
        guard let instance = panels[panelId] else { return }
        
        // 保存对话到历史记录（如果有消息）
        if !instance.state.messages.isEmpty {
            SessionHistoryService.shared.saveConversation(
                panelId: panelId,
                messages: instance.state.messages
            )
        }
        
        instance.window?.close()
        panels.removeValue(forKey: panelId)
        
        // 如果没有活跃面板，恢复辅助应用模式
        if panels.isEmpty {
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    /// 关闭所有面板
    func hideAll() {
        for (panelId, _) in panels {
            hide(panelId: panelId)
        }
    }
    
    /// 获取指定面板的 state（用于追问）
    func state(for panelId: UUID) -> AnswerPanelState? {
        panels[panelId]?.state
    }
    
    // MARK: - Private
    
    private func createWindow(for instance: AnswerPanelInstance) {
        var contentView = AnswerPanelView(state: instance.state)
        let panelId = instance.id
        
        contentView.onClose = { [weak self] in
            self?.hide(panelId: panelId)
        }
        contentView.onNewChat = { [weak self] in
            guard let state = self?.panels[panelId]?.state else { return }
            state.messages = []
            state.error = nil
        }
        contentView.onFollowUp = { [weak self] question, attachments in
            guard let self = self, self.panels[panelId] != nil else { return }
            print("Follow up [\(panelId)]: \(question), attachments: \(attachments.count)")
            
            // 添加用户消息并进入加载状态
            self.appendUserMessage(question, attachments: attachments, for: panelId)
            
            // 发送追问通知，带上 panelId
            NotificationCenter.default.post(
                name: .quickAskFollowUpRequested,
                object: nil,
                userInfo: [
                    "panelId": panelId,
                    "prompt": question, 
                    "attachments": attachments
                ]
            )
        }
        contentView.onRegenerate = { [weak self] in
            guard let state = self?.panels[panelId]?.state else { return }
            print("🔄 Regenerate answer [\(panelId)]")
            state.isLoading = true
            state.error = nil
        }
        
        // 创建窗口
        let panel = AnswerPanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
            styleMask: [.titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .utilityWindow
        panel.hidesOnDeactivate = false
        
        // 隐藏标题栏
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        
        panel.contentView = NSHostingView(rootView: contentView)
        
        // 级联排列窗口位置
        panel.center()
        if let frame = panel.screen?.visibleFrame {
            let newOrigin = NSPoint(
                x: panel.frame.origin.x + windowOffset,
                y: panel.frame.origin.y - windowOffset
            )
            // 确保窗口在屏幕内
            if frame.contains(NSRect(origin: newOrigin, size: panel.frame.size)) {
                panel.setFrameOrigin(newOrigin)
            }
        }
        windowOffset += offsetStep
        if windowOffset > 150 { windowOffset = 0 }  // 重置偏移
        
        instance.window = panel
    }
    
    /// 将窗口定位到锚点下方，处理边界情况
    private func positionWindow(_ window: NSWindow, belowAnchor anchor: CGPoint) {
        // 找到锚点所在的屏幕（多屏幕支持）
        let screen = NSScreen.screens.first { NSPointInRect(anchor, $0.frame) } ?? NSScreen.main
        guard let screen else { return }
        
        let screenFrame = screen.visibleFrame
        let windowSize = window.frame.size
        let padding: CGFloat = 10
        let gap: CGFloat = 8
        
        // 计算初始位置：锚点下方，水平居中
        var origin = CGPoint(
            x: anchor.x - windowSize.width / 2,
            y: anchor.y - windowSize.height - gap
        )
        
        // 边界修正：左右
        if origin.x < screenFrame.minX + padding {
            origin.x = screenFrame.minX + padding
        }
        if origin.x + windowSize.width > screenFrame.maxX - padding {
            origin.x = screenFrame.maxX - padding - windowSize.width
        }
        
        // 边界修正：下方空间不足时，改为显示在锚点上方
        if origin.y < screenFrame.minY + padding {
            origin.y = anchor.y + gap
            // 如果上方也不够，则贴底显示
            if origin.y + windowSize.height > screenFrame.maxY - padding {
                origin.y = screenFrame.minY + padding
            }
        }
        
        window.setFrameOrigin(origin)
    }
}

// MARK: - Answer Panel Text Editor

/// 回答面板专用文本编辑器
/// 复用 QuickAskNSTextView 的核心逻辑
struct AnswerPanelTextEditor: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var onSend: (() -> Void)?
    var onPasteImage: ((NSImage) -> Void)?
    var onTextChange: ((String, Bool) -> Void)?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        
        let textView = AnswerPanelNSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = .white
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 0, height: 4)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]
        textView.isSelectable = true
        textView.isEditable = true
        textView.insertionPointColor = .white
        textView.placeholderString = placeholder
        
        textView.onSend = onSend
        textView.onPasteImage = onPasteImage
        
        scrollView.documentView = textView
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? AnswerPanelNSTextView else { return }
        
        // 避免干扰输入法
        if textView.hasMarkedText() { return }
        
        if textView.string != text {
            textView.string = text
        }
        
        textView.onSend = onSend
        textView.onPasteImage = onPasteImage
        
        if textView.placeholderString != placeholder {
            textView.placeholderString = placeholder
            textView.needsDisplay = true
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
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

/// 回答面板专用 NSTextView
class AnswerPanelNSTextView: NSTextView {
    var onSend: (() -> Void)?
    var onPasteImage: ((NSImage) -> Void)?
    var placeholderString: String = ""
    
    override var canBecomeKeyView: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    
    // 点击时获取焦点
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        window?.makeFirstResponder(self)
    }
    
    // 成为 FirstResponder 时激活输入法
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            inputContext?.activate()
        }
        return result
    }
    
    // 键盘事件处理（上下箭头用于 Workflow Picker 导航）
    override func keyDown(with event: NSEvent) {
        // 让 WorkflowState 先处理键盘事件
        if WorkflowState.shared.handleKeyEvent(event) {
            return
        }
        super.keyDown(with: event)
    }
    
    // Enter 发送，Shift+Enter 换行，Tab 选择 Workflow
    override func doCommand(by selector: Selector) {
        // Tab 键：如果 Picker 可见，已在 keyDown 中处理
        if selector == #selector(insertTab(_:)) {
            if WorkflowState.shared.isPickerVisible {
                return // 已被 keyDown 处理
            }
            super.doCommand(by: selector)
            return
        }
        
        // Enter 键
        if selector == #selector(insertNewline(_:)) {
            if markedRange().length > 0 {
                super.doCommand(by: selector)
            } else if WorkflowState.shared.isPickerVisible {
                // Picker 可见时，Enter 确认选择（由 keyDown 处理）
                return
            } else {
                onSend?()
            }
            return
        }
        
        if selector == #selector(insertNewlineIgnoringFieldEditor(_:)) {
            super.doCommand(by: selector)
            return
        }
        
        super.doCommand(by: selector)
    }
    
    /// 捕获 ⌘V 粘贴
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
        
        // 优先检查图片
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
        
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            onPasteImage?(image)
            return
        }
        
        // 检查图片文件 URL
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
        
        // 普通文本粘贴
        super.paste(sender)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // 绘制 placeholder
        if string.isEmpty && !placeholderString.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 15),
                .foregroundColor: NSColor.white.withAlphaComponent(0.4)
            ]
            let placeholderRect = NSRect(
                x: textContainerInset.width,
                y: textContainerInset.height,
                width: bounds.width,
                height: bounds.height
            )
            placeholderString.draw(in: placeholderRect, withAttributes: attributes)
        }
    }
}

// MARK: - Preview

#Preview {
    let state = AnswerPanelState()
    state.messages = [
        ChatMessage(role: .user, content: "这个是什么", attachments: []),
        ChatMessage(role: .assistant, content: "这是一个名为 SpokenAnyWhere 的软件界面，看起来是一款用于语音处理、听写或 AI 语音相关的工具。\n\n从界面布局能看到：\n\n• 左侧是功能菜单（常规、听写模型、AI 处理、快捷键、历史记录）；\n• 右侧\"历史记录\"标签下，展示了过往的操作/对话记录，每条记录还配有导出、播放等功能按钮。", attachments: [])
    ]
    state.suggestedQuestions = [
        "SpokenAnyWhere有哪些特色功能？",
        "如何使用SpokenAnyWhere进行语音转文字？"
    ]
    
    return AnswerPanelView(state: state)
        .frame(width: 480, height: 600)
}
