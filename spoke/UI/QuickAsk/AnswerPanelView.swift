import AppKit
import SwiftUI

@MainActor
struct AnswerPanelViewDependencies {
    let workflowState: WorkflowState
    let ttsService: TTSService
    let ttsSettings: TTSSettings
    let messageBubbleDependencies: MessageBubbleViewDependencies
    let inputDependencies: AnswerPanelInputDependencies
    let openSettings: () -> Void
}

@MainActor
struct AnswerPanelInputDependencies {
    let addImage: (_ image: NSImage, _ onAdd: @escaping @MainActor @Sendable (Attachment) -> Void) -> Void
    let handleDrop: (_ providers: [NSItemProvider], _ onAdd: @escaping @MainActor @Sendable (Attachment) -> Void) -> Void
}

/// Quick Ask 回答面板视图
struct AnswerPanelView: View {
    @Bindable var state: AnswerPanelState
    let dependencies: AnswerPanelViewDependencies
    
    @State var followUpInput: String = ""
    
    /// Workflow 状态
    @State var workflowState: WorkflowState
    
    /// 录音状态
    @State var isRecording: Bool = false
    @State var audioLevels: [Float] = Array(repeating: 0.05, count: 40)
    
    // Markdown Height (初始值设大一点，避免加载时截断)
    @State private var answerHeight: CGFloat = 200
    // Toolbar Hover State
    @State private var isHoveringToolbar: Bool = false
    @State var isHoveringCloseButton: Bool = false
    @State var isHoveringNewChatButton: Bool = false
    
    // 操作按钮状态
    @State private var isCopied: Bool = false
    @ObservedObject private var ttsService: TTSService
    @ObservedObject private var ttsSettings: TTSSettings
    
    // 模式选择
    @State private var selectedMode: QuickAskMode = .chat
    
    // 自动朗读追踪
    @State private var lastAutoReadAnswer: String = ""
    
    // 待发送附件
    @State var pendingAttachments: [Attachment] = []
    
    // 拖拽状态
    @State var isDragOver: Bool = false
    
    /// 关闭回调
    var onClose: (() -> Void)?
    /// 追问回调
    var onFollowUp: ((String, [Attachment]) -> Void)?
    /// 新对话回调
    var onNewChat: (() -> Void)?
    /// 重新生成回调
    var onRegenerate: (() -> Void)?

    init(
        state: AnswerPanelState,
        dependencies: AnswerPanelViewDependencies,
        onClose: (() -> Void)? = nil,
        onFollowUp: ((String, [Attachment]) -> Void)? = nil,
        onNewChat: (() -> Void)? = nil,
        onRegenerate: (() -> Void)? = nil
    ) {
        self.state = state
        self.dependencies = dependencies
        self._workflowState = State(initialValue: dependencies.workflowState)
        self.ttsService = dependencies.ttsService
        self.ttsSettings = dependencies.ttsSettings
        self.onClose = onClose
        self.onFollowUp = onFollowUp
        self.onNewChat = onNewChat
        self.onRegenerate = onRegenerate
    }

    @MainActor
    init(
        state: AnswerPanelState,
        onClose: (() -> Void)? = nil,
        onFollowUp: ((String, [Attachment]) -> Void)? = nil,
        onNewChat: (() -> Void)? = nil,
        onRegenerate: (() -> Void)? = nil
    ) {
        self.init(
            state: state,
            dependencies: .live,
            onClose: onClose,
            onFollowUp: onFollowUp,
            onNewChat: onNewChat,
            onRegenerate: onRegenerate
        )
    }
    
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
                                MessageBubbleView(
                                    message: message,
                                    dependencies: dependencies.messageBubbleDependencies
                                )
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
        dependencies.openSettings()
    }
}
