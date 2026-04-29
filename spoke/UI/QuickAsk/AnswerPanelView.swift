import AppKit
import SwiftUI

private typealias DS = DesignTokens

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
    private let injectedWorkflowState: WorkflowState
    
    @State private var _followUpInput: String = ""
    
    /// 录音状态
    @State private var _isRecording: Bool = false
    @State private var _audioLevels: [Float] = Array(repeating: 0.05, count: 40)
    
    // Markdown Height (初始值设大一点，避免加载时截断)
    @State private var answerHeight: CGFloat = DS.Layout.toolbarHeight * 5
    // Toolbar Hover State
    @State private var isHoveringToolbar: Bool = false
    @State private var _isHoveringCloseButton: Bool = false
    @State private var _isHoveringNewChatButton: Bool = false
    
    // 操作按钮状态
    @State private var isCopied: Bool = false
    @ObservedObject private var ttsService: TTSService
    @ObservedObject private var ttsSettings: TTSSettings
    
    // 模式选择
    @State private var selectedMode: QuickAskMode = .chat
    
    // 自动朗读追踪
    @State private var lastAutoReadAnswer: String = ""
    
    // 待发送附件
    @State private var _pendingAttachments: [Attachment] = []
    
    // 拖拽状态
    @State private var _isDragOver: Bool = false
    
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
        self.injectedWorkflowState = dependencies.workflowState
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
            VStack(spacing: DS.BorderWidth.none) {
                // 顶部占位 (避免内容被 Toolbar 遮挡，或者留白)
                Color.clear.frame(height: DS.CornerRadius.md)
                
                // 对话内容区
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
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
                        .padding(DS.Spacing.xl)
                        .padding(.top, DS.Spacing.xxl - DS.Spacing.xs) // 额外顶部内边距
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
                    .frame(height: DS.Layout.toolbarHeight + DS.Spacing.xl)
                
                // toolbar (受 opacity 控制)
                toolbar
                    .opacity(isHoveringToolbar ? 1 : 0)
                    .animation(DS.Animation.normal, value: isHoveringToolbar)
            }
            .frame(maxWidth: .infinity, maxHeight: DS.Layout.toolbarHeight + DS.Spacing.xl, alignment: .top)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(DS.Animation.fast) {
                    isHoveringToolbar = hovering
                }
            }
        }
        .background(
            ZStack {
                // 磨砂玄效果
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                // 深色叠加
                DS.Colors.overlayLight
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.CornerRadius.xl))
        .background {
            // 隐藏的快捷键监听：Cmd + , 打开设置
            Button("") {
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            
            // Cmd + W 关闭窗口
            Button("") {
                onClose?()
            }
            .keyboardShortcut("w", modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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

    var workflowState: WorkflowState {
        injectedWorkflowState
    }

    var followUpInput: String {
        get { _followUpInput }
        nonmutating set { _followUpInput = newValue }
    }

    var followUpInputBinding: Binding<String> {
        $_followUpInput
    }

    var isRecording: Bool {
        get { _isRecording }
        nonmutating set { _isRecording = newValue }
    }

    var audioLevels: [Float] {
        get { _audioLevels }
        nonmutating set { _audioLevels = newValue }
    }

    var isHoveringCloseButton: Bool {
        get { _isHoveringCloseButton }
        nonmutating set { _isHoveringCloseButton = newValue }
    }

    var isHoveringNewChatButton: Bool {
        get { _isHoveringNewChatButton }
        nonmutating set { _isHoveringNewChatButton = newValue }
    }

    var pendingAttachments: [Attachment] {
        get { _pendingAttachments }
        nonmutating set { _pendingAttachments = newValue }
    }

    var isDragOver: Bool {
        get { _isDragOver }
        nonmutating set { _isDragOver = newValue }
    }

    var isDragOverBinding: Binding<Bool> {
        $_isDragOver
    }
}
