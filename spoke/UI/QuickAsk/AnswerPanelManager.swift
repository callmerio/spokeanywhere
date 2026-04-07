import AppKit
import SwiftUI

// MARK: - Answer Panel Window

/// 自定义 Panel 以支持 Key Window、输入法和标准编辑命令
class AnswerPanelWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    /// 处理标准编辑快捷键 (Cmd+C/V/X/A)
    /// 确保 WKWebView 和其他视图能正确响应复制/粘贴命令
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // 先尝试让 first responder 处理
        if let responder = firstResponder, responder !== self {
            if responder.performKeyEquivalent(with: event) {
                return true
            }
        }
        
        // 再让内容视图层级处理
        if contentView?.performKeyEquivalent(with: event) == true {
            return true
        }
        
        // 如果是标准编辑命令，尝试通过 sendAction 路由
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "c":
                if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self) {
                    return true
                }
            case "v":
                if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) {
                    return true
                }
            case "x":
                if NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self) {
                    return true
                }
            case "a":
                if NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self) {
                    return true
                }
            default:
                break
            }
        }
        
        return super.performKeyEquivalent(with: event)
    }
}

// MARK: - Answer Panel Instance

/// 单个回答面板实例
@MainActor
final class AnswerPanelInstance {
    let id: UUID
    let state: AnswerPanelState
    var window: NSWindow?

    init(id: UUID = UUID(), state: AnswerPanelState? = nil) {
        self.id = id
        self.state = state ?? AnswerPanelState()
    }
}

// MARK: - Answer Panel Manager

@MainActor
struct AnswerPanelManagerDependencies {
    let historyService: SessionHistoryService
}

/// 回答面板管理器（支持多窗口）
@MainActor
final class AnswerPanelManager {

    // MARK: - Singleton

    static let shared = AnswerPanelManager(dependencies: .live)

    // MARK: - Properties

    /// 所有活跃的面板实例
    private var panels: [UUID: AnswerPanelInstance] = [:]

    /// 窗口位置偏移（用于级联排列新窗口）
    private var windowOffset: CGFloat = 0
    private let offsetStep: CGFloat = 30
    private let dependencies: AnswerPanelManagerDependencies
    var onFollowUp: ((_ panelId: UUID, _ prompt: String) async -> Void)?

    // MARK: - Init

    private init(
        dependencies: AnswerPanelManagerDependencies
    ) {
        self.dependencies = dependencies
    }

    static func makeTesting(dependencies: AnswerPanelManagerDependencies) -> AnswerPanelManager {
        AnswerPanelManager(dependencies: dependencies)
    }

    // MARK: - Public API

    /// 创建并显示新的回答面板，返回 panelId
    /// - Parameters:
    ///   - question: 用户问题
    ///   - attachments: 附件列表
    ///   - contextSources: 上下文来源列表
    ///   - screenshotImage: 应用截图
    ///   - anchorPoint: 可选锚点位置（AppKit 坐标系），面板将显示在此位置下方
    @discardableResult
    func show(
        question: String,
        voiceTranscription: String? = nil,
        attachments: [QuickAskAttachment],
        contextSources: [ContextSource] = [],
        screenshotImage: CGImage? = nil,
        anchorPoint: CGPoint? = nil
    ) -> UUID {
        let instance = makeInstance(
            question: question,
            voiceTranscription: voiceTranscription,
            attachments: attachments,
            contextSources: contextSources,
            screenshotImage: screenshotImage
        )
        let panelId = instance.id

        createWindow(for: instance)
        panels[panelId] = instance

        if let anchor = anchorPoint, let window = instance.window {
            positionWindow(window, belowAnchor: anchor)
        }

        instance.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        return panelId
    }

    /// 在指定锚点下方显示面板（用于 Selection Toolbar 触发）
    @discardableResult
    func showBelowAnchor(
        question: String,
        attachments: [QuickAskAttachment] = [],
        anchorPoint: CGPoint
    ) -> UUID {
        show(question: question, attachments: attachments, anchorPoint: anchorPoint)
    }

    /// 更新指定面板的回答（支持图片）
    func updateAnswer(_ response: LLMResponse, for panelId: UUID) {
        guard let instance = panels[panelId] else { return }

        if let lastMsg = instance.state.messages.last, lastMsg.role == .assistant {
            let updatedMsg = ChatMessage(
                role: .assistant,
                content: response.text,
                attachments: [],
                generatedImages: response.images
            )
            instance.state.messages[instance.state.messages.count - 1] = updatedMsg
        } else {
            instance.state.messages.append(
                ChatMessage(
                    role: .assistant,
                    content: response.text,
                    attachments: [],
                    generatedImages: response.images
                )
            )
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
        guard let panelId = latestPanelId() else { return }
        updateAnswer(answer, for: panelId)
    }

    /// 追加用户消息到指定面板
    func appendUserMessage(
        _ content: String,
        attachments: [QuickAskAttachment],
        for panelId: UUID
    ) {
        guard let instance = panels[panelId] else { return }
        instance.state.messages.append(
            ChatMessage(role: .user, content: content, attachments: attachments)
        )
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
        guard let panelId = latestPanelId() else { return }
        showError(message, for: panelId)
    }

    /// 关闭指定面板
    func hide(panelId: UUID) {
        guard let instance = panels[panelId] else { return }

        // 保存对话到历史记录（如果有消息）
        if !instance.state.messages.isEmpty {
            dependencies.historyService.saveConversation(
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

    @discardableResult
    func installTestingPanel(id: UUID = UUID(), state: AnswerPanelState? = nil) -> UUID {
        panels[id] = AnswerPanelInstance(id: id, state: state)
        return id
    }

    func handleFollowUpRequest(
        question: String,
        attachments: [QuickAskAttachment],
        for panelId: UUID
    ) {
        guard panels[panelId] != nil else { return }
        appendUserMessage(question, attachments: attachments, for: panelId)
        Task { [weak self] in
            guard let self else { return }
            await self.onFollowUp?(panelId, question)
        }
    }

    // MARK: - Private

    private func makeInstance(
        question: String,
        voiceTranscription: String?,
        attachments: [QuickAskAttachment],
        contextSources: [ContextSource],
        screenshotImage: CGImage?
    ) -> AnswerPanelInstance {
        let instance = AnswerPanelInstance()

        instance.state.messages = [
            ChatMessage(
                role: .user,
                content: question,
                attachments: attachments,
                contextSources: contextSources,
                screenshotImage: screenshotImage,
                voiceTranscription: voiceTranscription
            )
        ]
        instance.state.isLoading = true
        instance.state.error = nil
        instance.state.suggestedQuestions = []

        return instance
    }

    private func latestPanelId() -> UUID? {
        panels.values.max(by: { lhs, rhs in
            (lhs.state.messages.first?.timestamp ?? .distantPast)
                < (rhs.state.messages.first?.timestamp ?? .distantPast)
        })?.id
    }

    private func createWindow(for instance: AnswerPanelInstance) {
        let panelId = instance.id
        let contentView = makeContentView(panelId: panelId, state: instance.state)
        let panel = makePanel()

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.identifier = NSUserInterfaceItemIdentifier(UITestIdentifiers.Element.answerPanelRoot)
        hostingView.setAccessibilityIdentifier(UITestIdentifiers.Element.answerPanelRoot)
        panel.contentView = hostingView
        panel.identifier = NSUserInterfaceItemIdentifier(UITestIdentifiers.Window.answerPanel)
        panel.setAccessibilityIdentifier(UITestIdentifiers.Window.answerPanel)
        applyWindowCascade(panel)
        instance.window = panel
    }

    private func makeContentView(
        panelId: UUID,
        state: AnswerPanelState
    ) -> AnswerPanelView {
        var contentView = AnswerPanelView(state: state)

        contentView.onClose = { [weak self] in
            self?.hide(panelId: panelId)
        }
        contentView.onNewChat = { [weak self] in
            guard let state = self?.panels[panelId]?.state else { return }
            state.messages = []
            state.error = nil
        }
        contentView.onFollowUp = { [weak self] question, attachments in
            guard let self, self.panels[panelId] != nil else { return }
            print("Follow up [\(panelId)]: \(question), attachments: \(attachments.count)")
            self.handleFollowUpRequest(question: question, attachments: attachments, for: panelId)
        }
        contentView.onRegenerate = { [weak self] in
            guard let state = self?.panels[panelId]?.state else { return }
            print("🔄 Regenerate answer [\(panelId)]")
            state.isLoading = true
            state.error = nil
        }

        return contentView
    }

    private func makePanel() -> AnswerPanelWindow {
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

        return panel
    }

    private func applyWindowCascade(_ panel: NSWindow) {
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
    }

    /// 将窗口定位到锚点下方，处理边界情况
    private func positionWindow(_ window: NSWindow, belowAnchor anchor: CGPoint) {
        // 找到锚点所在的屏幕（多屏幕支持）
        let screen = NSScreen.screens.first { $0.frame.contains(anchor) } ?? NSScreen.main
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
