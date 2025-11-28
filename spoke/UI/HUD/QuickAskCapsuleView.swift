import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Quick Ask 悬浮面板视图
/// 复用 FloatingCapsuleView 的样式，上方改为输入框
struct QuickAskCapsuleView: View {
    @State private var levels: [Float] = Array(repeating: 0.05, count: 30)
    
    @Bindable var state: QuickAskState
    
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
        VStack {
            Spacer()
            
            // 实际内容区域（主内容决定尺寸）
            VStack(spacing: 0) {
                // 上方：输入区域
                if state.phase == .recording || state.phase == .sending {
                    QuickAskInputView(
                        state: state,
                        onSend: onSend,
                        onCancel: onCancel,
                        onDragEntered: { isDragOver = true },
                        onDragExited: { isDragOver = false },
                        onDrop: { providers in
                            isDragOver = false
                            AttachmentManager.shared.handleDrop(providers: providers) { attachment in
                                state.addAttachment(attachment)
                            }
                        }
                    )
                }
                
                // 下方：固定控制栏（和转录 HUD 一样）
                controlBar
            }
            .background(
                ZStack {
                    // 毛玻璃底层
                    VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                    
                    // 深色叠加
                    Color.black.opacity(0.3)
                    
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
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
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
                    Color.red.opacity(0.25),
                    Color.red.opacity(0.08),
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
                    Color.white.opacity(0.08),
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
            Button(action: { AttachmentManager.shared.pickFiles { state.addAttachment($0) } }) {
                Label("从设备上传", systemImage: "doc.badge.plus")
            }
            
            Divider()
            
            // 导入文件夹
            Button(action: { AttachmentManager.shared.pickFolder { state.addAttachment($0) } }) {
                Label("导入文件夹 (转为文本)", systemImage: "folder.badge.plus")
            }
            
            // 导入 ZIP
            Button(action: { AttachmentManager.shared.pickZIP { state.addAttachment($0) } }) {
                Label("导入 ZIP (转为文本)", systemImage: "doc.zipper")
            }
            
            Divider()
            
            // 图库
            Button(action: { AttachmentManager.shared.pickFromPhotos { state.addAttachment($0) } }) {
                Label("图库", systemImage: "photo.on.rectangle")
            }
            
            // 屏幕截图
            Button(action: { AttachmentManager.shared.captureScreen { state.addAttachment($0) } }) {
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
                    .foregroundStyle(.white)
                    .opacity(showPlusIcon ? 1 : 0)
            }
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(showPlusIcon ? Color.white.opacity(0.15) : Color.clear)
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
                .foregroundStyle(HUDTheme.textPrimary)
        }
    }
    
    private var brandLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "waveform")
                .font(.system(size: 12))
            Text("SpokenAnyWhere")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(HUDTheme.textSecondary)
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
}

// MARK: - Preview

#Preview {
    let state = QuickAskState()
    state.phase = .recording
    
    return QuickAskCapsuleView(state: state)
        .frame(width: 340, height: 200)
}
