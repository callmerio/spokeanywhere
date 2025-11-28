import SwiftUI
import AppKit

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

/// 回答面板状态
@Observable
@MainActor
final class AnswerPanelState {
    var question: String = ""
    var attachments: [QuickAskAttachment] = []
    var answer: String = ""
    var isLoading: Bool = false
    var error: String?
    var suggestedQuestions: [String] = []
}

/// Quick Ask 回答面板视图
struct AnswerPanelView: View {
    @Bindable var state: AnswerPanelState
    
    @State private var followUpInput: String = ""
    @FocusState private var isInputFocused: Bool
    
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
    
    /// 关闭回调
    var onClose: (() -> Void)?
    /// 追问回调
    var onFollowUp: ((String) -> Void)?
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
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 用户消息
                        userMessageBubble
                        
                        // AI 回答
                        if state.isLoading {
                            loadingView
                        } else if let error = state.error {
                            errorView(error)
                        } else if !state.answer.isEmpty {
                            answerView
                        }
                        
                        // 推荐问题
                        if !state.suggestedQuestions.isEmpty {
                            suggestedQuestionsView
                        }
                    }
                    .padding(16)
                    .padding(.top, 20) // 额外顶部内边距
                }
                
                // 底部输入框
                inputArea
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
    
    // MARK: - User Message
    
    private var userMessageBubble: some View {
        VStack(alignment: .trailing, spacing: 8) {
            // 附件缩略图
            if !state.attachments.isEmpty {
                HStack(spacing: 8) {
                    ForEach(state.attachments) { attachment in
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
            
            // 问题文字
            if !state.question.isEmpty {
                Text(state.question)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    
    // MARK: - Answer
    
    private var answerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // AI 回答内容 (Markdown) - 自适应高度，不截断
            MarkdownWebView(text: state.answer, dynamicHeight: $answerHeight)
                .frame(minHeight: answerHeight)
            
            // 操作按钮
            HStack(spacing: 16) {
                // 朗读按钮 (切换)
                Button(action: { ttsService.toggleSpeak(state.answer) }) {
                    HStack(spacing: 4) {
                        Image(systemName: ttsService.isPlaying ? "stop.fill" : "speaker.wave.2")
                            .font(.system(size: 12))
                        Text(ttsService.isPlaying ? "停止" : "朗读")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(ttsService.isPlaying ? Color.accentColor : .white.opacity(0.5))
                }
                .buttonStyle(.plain)
                
                // 复制按钮 (成功后打勾)
                Button(action: { copyAnswer() }) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundStyle(isCopied ? .green : .white.opacity(0.5))
                        Text(isCopied ? "已复制" : "复制")
                            .font(.system(size: 11))
                            .foregroundStyle(isCopied ? .green : .white.opacity(0.5))
                    }
                    .animation(.easeInOut(duration: 0.2), value: isCopied)
                }
                .buttonStyle(.plain)
                
                // 重新生成
                Button(action: { onRegenerate?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                        Text("重新生成")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // 模式选择器 (DeepResearch / Canvas / Mind)
                modeSelector
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func actionButton(icon: String, label: String, action: @escaping () -> Void = {}) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 11))
            }
            .foregroundStyle(.white.opacity(0.5))
        }
        .buttonStyle(.plain)
    }
    
    /// 复制回答到剪贴板
    private func copyAnswer() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(state.answer, forType: .string)
        
        withAnimation(.easeInOut(duration: 0.2)) {
            isCopied = true
        }
        
        // 2秒后恢复
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCopied = false
            }
        }
    }
    
    /// 模式选择器
    private var modeSelector: some View {
        Menu {
            ForEach(QuickAskMode.allCases, id: \.self) { mode in
                Button(action: { selectedMode = mode }) {
                    Label(mode.rawValue, systemImage: mode.icon)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selectedMode.icon)
                    .font(.system(size: 12))
                Text(selectedMode.rawValue)
                    .font(.system(size: 11))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundStyle(.white.opacity(0.5))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
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
                Button(action: { onFollowUp?(question) }) {
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
    
    // MARK: - Input Area
    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 文本输入区域
            if !isRecording {
                TextField("继续追问...", text: $followUpInput, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .focused($isInputFocused)
                    .lineLimit(2...6)
                    .frame(minHeight: 24, alignment: .top)
            } else {
                // 录音时显示波纹
                recordingWaveform
            }
            
            // 底部工具栏
            HStack(spacing: 12) {
                // 添加按钮 (未来扩展附件等)
                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // 麦克风按钮
                Button(action: { toggleRecording() }) {
                    Image(systemName: isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 16))
                        .foregroundStyle(isRecording ? Color.accentColor : .white.opacity(0.4))
                }
                .buttonStyle(.plain)
                
                // 发送按钮
                Button(action: {
                    if !followUpInput.isEmpty {
                        onFollowUp?(followUpInput)
                        followUpInput = ""
                    }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(followUpInput.isEmpty ? Color.white.opacity(0.2) : Color.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(followUpInput.isEmpty && !isRecording)
            }
            .padding(.top, 4) // 工具栏往下移
        }
        .padding(14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Recording Waveform
    
    /// 录音波纹动画（类似 HUD 但拉满整个宽度）
    private var recordingWaveform: some View {
        HStack(spacing: 2) {
            // 录音指示点
            Circle()
                .fill(Color.white.opacity(0.6))
                .frame(width: 6, height: 6)
            
            Text("Recording")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
            
            // 波纹条 - 拉满剩余宽度
            GeometryReader { geo in
                HStack(spacing: 1.5) {
                    ForEach(0..<Int(geo.size.width / 4), id: \.self) { index in
                        let level = audioLevels[index % audioLevels.count]
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 2, height: CGFloat(level) * 20 + 2)
                    }
                }
                .frame(height: 24, alignment: .center)
            }
            .frame(height: 24)
        }
        .frame(minHeight: 24)
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

// MARK: - Answer Panel Manager

/// 回答面板管理器
@MainActor
final class AnswerPanelManager {
    
    // MARK: - Singleton
    
    static let shared = AnswerPanelManager()
    
    // MARK: - Properties
    
    private var window: NSWindow?
    let state = AnswerPanelState()
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Public API
    
    func show(question: String, attachments: [QuickAskAttachment]) {
        state.question = question
        state.attachments = attachments
        state.answer = ""
        state.isLoading = true
        state.error = nil
        state.suggestedQuestions = []
        
        createWindowIfNeeded()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func updateAnswer(_ answer: String) {
        state.answer = answer
        state.isLoading = false
        
        // TODO: 可以让 LLM 生成推荐问题
        state.suggestedQuestions = []
    }
    
    func showError(_ message: String) {
        state.error = message
        state.isLoading = false
    }
    
    func hide() {
        window?.close()
    }
    
    // MARK: - Private
    
    private func createWindowIfNeeded() {
        guard window == nil else { return }
        
        var contentView = AnswerPanelView(state: state)
        contentView.onClose = { [weak self] in
            self?.hide()
        }
        contentView.onNewChat = { [weak self] in
            self?.state.question = ""
            self?.state.attachments = []
            self?.state.answer = ""
            self?.state.error = nil
        }
        contentView.onFollowUp = { [weak self] question in
            // TODO: 处理追问
            print("Follow up: \(question)")
            
            // 暂时先进入加载状态，避免 UI 无反馈
            self?.state.isLoading = true
        }
        contentView.onRegenerate = { [weak self] in
            guard let self = self else { return }
            print("🔄 Regenerate answer for: \(self.state.question)")
            
            // 重新进入加载状态
            self.state.isLoading = true
            self.state.answer = ""
            self.state.error = nil
            
            // TODO: 重新调用 LLM 生成回答
        }
        
        // 使用 NSPanel 实现无边框窗口
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .utilityWindow
        
        panel.contentView = NSHostingView(rootView: contentView)
        panel.center()
        
        self.window = panel
    }
}

// MARK: - Preview

#Preview {
    let state = AnswerPanelState()
    state.question = "这个是什么"
    state.answer = "这是一个名为 SpokenAnyWhere 的软件界面，看起来是一款用于语音处理、听写或 AI 语音相关的工具。\n\n从界面布局能看到：\n\n• 左侧是功能菜单（常规、听写模型、AI 处理、快捷键、历史记录）；\n• 右侧\"历史记录\"标签下，展示了过往的操作/对话记录，每条记录还配有导出、播放等功能按钮。"
    state.suggestedQuestions = [
        "SpokenAnyWhere有哪些特色功能？",
        "如何使用SpokenAnyWhere进行语音转文字？"
    ]
    
    return AnswerPanelView(state: state)
        .frame(width: 480, height: 600)
}
