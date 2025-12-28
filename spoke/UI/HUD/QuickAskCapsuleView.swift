import AppKit
import SwiftUI
import UniformTypeIdentifiers

private typealias DS = DesignTokens

/// Quick Ask 悬浮面板视图
/// 复用 FloatingCapsuleView 的样式，上方改为输入框
struct QuickAskCapsuleView: View {
    @State private var levels: [Float] = Array(repeating: 0.05, count: 30)
    
    @Bindable var state: QuickAskState
    
    /// Workflow 状态
    @State private var workflowState = WorkflowState.shared
    
    /// 左下角图标 hover 状态或菜单打开状态
    @State private var isIconHovering = false
    /// 菜单是否打开
    @State private var isMenuOpen = false
    
    /// 是否显示加号图标（hover 或菜单打开时）
    private var showPlusIcon: Bool {
        isIconHovering || isMenuOpen
    }
    
    /// 发送回调
    var onSend: (() -> Void)?
    /// 取消回调（ESC 键）
    var onCancel: (() -> Void)?
    
    /// 拖拽状态
    @State private var isDragOver = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // 主面板（Picker + 输入框 + 控制栏）
            VStack(spacing: 0) {
                // Workflow Picker（在输入框上方，共享背景）
                if workflowState.isPickerVisible {
                    WorkflowPickerView(
                        filter: workflowState.filterKeyword,
                        onSelect: { workflow in
                            workflowState.select(workflow)
                            state.userInput = ""
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .onAppear {
                        // 设置键盘确认回调
                        workflowState.onKeyboardConfirm = { _ in
                            // 选中 Workflow 后，清空输入框（移除 /keyword），让用户开始输入内容
                            state.userInput = ""
                            // 注意：不立即执行 executeWorkflow，等待用户输入后按 Enter 发送
                        }
                    }
                    .onDisappear {
                        workflowState.onKeyboardConfirm = nil
                    }
                }
                
                // 输入区域
                if state.phase == .recording || state.phase == .sending {
                    QuickAskInputView(
                        state: state,
                        onSend: {
                            // 检查是否有选中的 Workflow
                            if let workflow = workflowState.selectedWorkflow {
                                // 如果用户没有输入任何内容，不执行（刚选中 Workflow，等待输入）
                                if state.userInput.trimmingCharacters(in: .whitespaces).isEmpty {
                                    return
                                }
                                executeWorkflow(workflow)
                            } else {
                                onSend?()
                            }
                        },
                        onCancel: {
                            if workflowState.isPickerVisible {
                                workflowState.hidePicker()
                            } else if state.userInput.hasPrefix("/") {
                                state.userInput = ""
                                workflowState.reset()
                            } else {
                                onCancel?()
                            }
                        },
                        onDragEntered: { isDragOver = true },
                        onDragExited: { isDragOver = false },
                        onDrop: { providers in
                            isDragOver = false
                            AttachmentManager.shared.handleDrop(providers: providers) { attachment in
                                state.addAttachment(attachment)
                            }
                        },
                        onTextChange: { text, hasMarkedText in
                            _ = workflowState.detectSlashPrefix(text: text, hasMarkedText: hasMarkedText)
                        }
                    )
                }
                
                // 下方：固定控制栏
                controlBar
            }
            .background(
                ZStack {
                    // 毛玻璃底层
                    VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                    
                    // 深色叠加
                    DS.Colors.overlayDark
                    
                    // 底部红色晕染 (录音中)
                    if state.phase == .recording {
                        recordingGlow
                    }
                    
                    // 顶部微光
                    topGlow
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                Group {
                    if state.phase == .sending {
                        RunningLightBorder()
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(DS.Colors.borderPrimary, lineWidth: 0.5)
                    }
                }
            )
            .overlay {
                // 拖拽蒙版（使用通用组件）
                AttachmentDropOverlay(cornerRadius: 16, isVisible: isDragOver)
            }
            // 拖拽处理（使用 AttachmentManager）
            .onDrop(of: [.image, .fileURL, .folder, .zip], isTargeted: $isDragOver) { providers in
                AttachmentManager.shared.handleDrop(providers: providers) { attachment in
                    state.addAttachment(attachment)
                }
                return true
            }
            .onChange(of: state.audioLevel) { _, newLevel in
                updateWaveform(newLevel)
            }
            .animation(.easeOut(duration: 0.15), value: workflowState.isPickerVisible)
        }
        .background {
            // 隐藏的快捷键监听：Cmd + , 打开设置
            Button("") {
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.openSettings()
                }
            }
            .keyboardShortcut(",", modifiers: .command)
            .hidden()
        }
    }
    
    // MARK: - Background Elements
    
    private var recordingGlow: some View {
        VStack {
            Spacer()
            LinearGradient(
                colors: [
                    DS.Colors.recordingGlow.opacity(0.25),
                    DS.Colors.recordingGlow.opacity(0.08),
                    Color.clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 44)
        }
    }
    
    private var topGlow: some View {
        VStack {
            LinearGradient(
                colors: [
                    DS.Colors.glowTop,
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 30)
            Spacer()
        }
    }
    
    // MARK: - Control Bar (和转录 HUD 一样)
    
    private var controlBar: some View {
        HStack(spacing: 0) {
            // 左侧：App 图标 + 附件菜单（hover 时变加号）
            attachmentMenuButton
            
            Spacer().frame(width: 12)
            
            // 波形（和转录 HUD 一样）
            if state.phase == .recording {
                ScrollingWaveform(levels: levels)
                    .frame(width: 120, height: 16)
            } else if state.phase == .sending {
                // 发送中：显示思考状态
                StatusIndicator(isThinking: true)
                    .frame(width: 20, height: 20)
            }
            
            Spacer()
            
            // 右侧：品牌标签
            brandLabel
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 40)
    }
    
    // MARK: - Components
    
    /// 左下角附件菜单按钮（hover 或菜单打开时从应用图标 fade 变成加号）
    private var attachmentMenuButton: some View {
        Menu {
            // 从设备上传
            Button {
                AttachmentManager.shared.pickFiles { state.addAttachment($0) }
            } label: {
                Label("从设备上传", systemImage: "doc.badge.plus")
            }
            
            Divider()
            
            // 导入文件夹
            Button {
                AttachmentManager.shared.pickFolder { state.addAttachment($0) }
            } label: {
                Label("导入文件夹 (转为文本)", systemImage: "folder.badge.plus")
            }
            
            // 导入 ZIP
            Button {
                AttachmentManager.shared.pickZIP { state.addAttachment($0) }
            } label: {
                Label("导入 ZIP (转为文本)", systemImage: "doc.zipper")
            }
            
            Divider()
            
            // 图库
            Button {
                AttachmentManager.shared.pickFromPhotos { state.addAttachment($0) }
            } label: {
                Label("图库", systemImage: "photo.on.rectangle")
            }
            
            // 屏幕截图
            Button {
                AttachmentManager.shared.captureScreen { state.addAttachment($0) }
            } label: {
                Label("屏幕截图", systemImage: "camera.viewfinder")
            }
        } label: {
            ZStack {
                // 默认：应用图标
                appIconView
                    .opacity(showPlusIcon ? 0 : 1)
                
                // Hover 或菜单打开：加号
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .opacity(showPlusIcon ? 1 : 0)
            }
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(showPlusIcon ? DS.Colors.buttonHoverStrong : Color.clear)
            )
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.2), value: showPlusIcon)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .onHover { hovering in
            isIconHovering = hovering
        }
        .onTapGesture {
            // 点击时设置菜单打开状态
            isMenuOpen = true
            // 延迟重置（菜单关闭后）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if !isIconHovering {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isMenuOpen = false
                    }
                }
            }
        }
    }
    
    /// 应用图标视图
    @ViewBuilder
    private var appIconView: some View {
        if let icon = state.targetApp?.icon {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: 14))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
        }
    }
    
    private var brandLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "waveform")
                .font(.system(size: 12))
            Text("SpokenAnyWhere")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(DesignTokens.Colors.textSecondary)
    }
    
    // MARK: - Helpers
    
    private func updateWaveform(_ level: Float) {
        var newLevels = levels
        newLevels.removeFirst()
        newLevels.append(level)
        withAnimation(.linear(duration: 0.05)) {
            self.levels = newLevels
        }
    }
    
    // MARK: - Workflow Execution
    
    private func executeWorkflow(_ workflow: WorkflowAction) {
        let userInput = workflowState.getUserInput(from: state.userInput)
        let question = "/\(workflow.keyword) \(userInput)".trimmingCharacters(in: .whitespaces)
        let attachments = state.attachments
        
        // 构建上下文
        let context = WorkflowContext(
            userInput: userInput,
            screenContext: nil,
            selectedText: nil,
            voiceTranscription: state.voiceTranscription,
            clipboardContent: NSPasteboard.general.string(forType: .string)
        )
        
        // 重置状态
        workflowState.reset()
        state.userInput = ""
        
        // 切换到发送状态
        state.startSending()
        
        // 隐藏 HUD
        QuickAskHUDManager.shared.hide(restorePolicy: false)
        
        // 显示 Answer Panel
        let panelId = AnswerPanelManager.shared.show(
            question: question,
            attachments: attachments
        )
        
        // 执行 Workflow
        Task {
            let result = await WorkflowExecutor.shared.execute(workflow, context: context)
            
            switch result {
            case .success(let response):
                // 显示结果到 Answer Panel
                AnswerPanelManager.shared.updateAnswer(response, for: panelId)
                
            case .failure(let error):
                // 显示错误
                AnswerPanelManager.shared.showError(error.localizedDescription, for: panelId)
            }
            
            // 重置 Quick Ask 状态
            state.reset()
        }
    }
}

// MARK: - Preview

#Preview {
    let state = QuickAskState()
    state.phase = .recording
    
    return QuickAskCapsuleView(state: state)
        .frame(width: 340, height: 200)
}
