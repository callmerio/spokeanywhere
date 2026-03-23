import AppKit
import os
import SwiftUI

@MainActor
struct MessagePanelManagerDependencies {
    let state: MessagePanelState
    let historyService: SessionHistoryService
    let dictionaryHandler: AddToDictionaryHandler
    let hoverState: MessagePanelHoverState
    let hotKeyService: HotKeyService
    let tagLibrary: TagLibrary
    let summaryService: SummaryService
    let answerPanelManager: AnswerPanelManager
    let clipboardPipelineService: ClipboardPipelineService
}

/// 消息面板管理器
/// 负责面板窗口的生命周期和交互
@MainActor
final class MessagePanelManager {
    
    // MARK: - Singleton
    
    static let shared = MessagePanelManager(dependencies: .live)
    
    // MARK: - Properties
    
    private var panel: MessagePanelWindow?
    private let dependencies: MessagePanelManagerDependencies
    private let state: MessagePanelState
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "MessagePanel")
    
    /// 面板是否可见
    var isVisible: Bool { state.isVisible }
    
    // MARK: - Init
    
    private init(
        dependencies: MessagePanelManagerDependencies
    ) {
        self.dependencies = dependencies
        self.state = dependencies.state
        // 初始化键盘监听（用于 Cmd+V 粘贴图片）
        dependencies.hoverState.configure(
            dependencies: MessagePanelHoverStateDependencies(
                isPanelVisible: { [weak self] in self?.isVisible ?? false },
                addAttachmentToCard: { [weak self] image, id in
                    self?.state.addAttachment(image, to: id)
                },
                triggerClipboardPipeline: { [clipboardPipelineService = dependencies.clipboardPipelineService] in
                    clipboardPipelineService.trigger()
                }
            )
        )
    }
    
    // MARK: - Public API
    
    /// 获取状态（用于外部添加消息）
    var panelState: MessagePanelState { state }
    
    /// 显示面板
    func show() {
        createPanelIfNeeded()
        positionPanel()
        
        panel?.orderFront(nil)
        state.show()
        
        logger.info("📋 Message Panel shown")
    }
    
    /// 隐藏面板
    func hide() {
        state.hide()

        runMessagePanelAfterDelay(seconds: 0.4) { [weak self] in
            self?.panel?.orderOut(nil)
        }

        logger.info("📋 Message Panel hidden")
    }
    
    /// 切换显示/隐藏
    func toggle() {
        if state.isVisible {
            hide()
        } else {
            show()
        }
    }
    
    /// 添加 Welcome 消息
    func addWelcome(_ message: String) {
        state.addWelcome(message)
    }
    
    /// 添加 ASR 结果
    func addASRResult(model: String, content: String, duration: TimeInterval? = nil, sourceApp: SourceAppInfo? = nil) {
        state.addASRResult(model: model, content: content, duration: duration, sourceApp: sourceApp)
    }
    
    /// 添加 LLM 结果
    func addLLMResult(model: String, content: String, processingTime: TimeInterval? = nil, sourceApp: SourceAppInfo? = nil) {
        state.addLLMResult(model: model, content: content, processingTime: processingTime, sourceApp: sourceApp)
    }
    
    /// 添加剪贴板内容
    func addClipboardContent(content: String, sourceApp: SourceAppInfo? = nil) {
        state.addClipboardContent(content: content, sourceApp: sourceApp)
    }
    
    /// 添加系统消息
    func addSystemMessage(_ message: String) {
        state.addSystemMessage(message)
    }
    
    // MARK: - Private
    
    private func createPanelIfNeeded() {
        guard panel == nil else { return }
        
        let contentView = MessagePanelView(
            state: state,
            historyService: dependencies.historyService,
            dictionaryHandler: dependencies.dictionaryHandler,
            hoverState: dependencies.hoverState,
            hidePanel: { [weak self] in self?.hide() },
            startQuickAsk: { [weak self] in
                self?.hide()
                runMessagePanelAfterDelay(seconds: 0.1) { [weak self] in
                    self?.dependencies.hotKeyService.isQuickAskActive = true
                    self?.dependencies.hotKeyService.onQuickAskStart?()
                }
            },
            dependencies: MessagePanelViewDependencies(
                restoreConversation: { record in
                    let chatMessages = record.messages.map { msg in
                        ChatMessage(
                            role: msg.role == .user ? .user : .assistant,
                            content: msg.content,
                            attachments: []
                        )
                    }

                    let panelId = self.dependencies.answerPanelManager.show(
                        question: record.title,
                        attachments: []
                    )

                    runMessagePanelAfterDelay(seconds: 0.1) {
                        if let state = self.dependencies.answerPanelManager.state(for: panelId) {
                            state.messages = chatMessages
                            state.isLoading = false
                        }
                    }
                }
            ),
            cardDependencies: MessageCardViewDependencies(
                hoverState: dependencies.hoverState,
                resolveTags: { [tagLibrary = dependencies.tagLibrary] in tagLibrary.tags(for: $0) },
                setRecordType: { self.state.setRecordType($0, type: $1) },
                pasteImageFromClipboard: { self.state.pasteImageFromClipboard(to: $0) },
                addAttachment: { image, id in self.state.addAttachment(image, to: id) },
                generateSummary: { [summaryService = dependencies.summaryService] id, regenerate in
                    runMessagePanelDetached {
                        await summaryService.generateSummary(for: id, regenerate: regenerate)
                    }
                }
            )
        )
        let hostingView = NSHostingView(rootView: contentView)
        
        // 获取屏幕尺寸
        let screen = screenWithMouse() ?? NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.visibleFrame
        
        // 面板高度占满屏幕
        let panelHeight = screenFrame.height
        let panelWidth = MessagePanelState.panelWidth + 40  // 额外空间用于阴影
        
        let frame = NSRect(
            origin: .zero,
            size: NSSize(width: panelWidth, height: panelHeight)
        )
        
        let newPanel = MessagePanelWindow(contentRect: frame)
        newPanel.contentView = hostingView
        
        // 关键：确保 contentView 也完全透明
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
        self.panel = newPanel
        logger.info("📋 Message Panel created")
    }
    
    /// 定位面板到屏幕左侧
    private func positionPanel() {
        guard let panel = panel else { return }
        
        // 获取鼠标所在屏幕
        let screen = screenWithMouse() ?? NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.visibleFrame
        
        // 更新面板高度以适应屏幕
        let panelWidth = panel.frame.width
        let panelHeight = screenFrame.height
        
        // 左边缘，垂直居中
        let x = screenFrame.minX
        let y = screenFrame.minY
        
        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
    }
    
    /// 获取鼠标所在屏幕
    private func screenWithMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        }
    }
}

// MARK: - Message Panel Window

/// 消息面板窗口
final class MessagePanelWindow: NSPanel {
    
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            // 关键：加入 .fullSizeContentView 让内容穿透标题栏区域
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        configure()
    }
    
    private func configure() {
        // 窗口层级：悬浮在普通窗口之上
        level = .floating
        
        // 关键：窗口完全透明
        isOpaque = false
        backgroundColor = .clear
        
        // 关键：标题栏透明
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        
        // 不在 Dock/Mission Control 显示
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        
        // 动画
        animationBehavior = .utilityWindow
        
        // 禁用系统阴影（视图自己处理）
        hasShadow = false
        
        // 不可移动
        isMovableByWindowBackground = false
    }
}
