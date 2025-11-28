import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Quick Ask 悬浮面板视图
/// 复用 FloatingCapsuleView 的样式，上方改为输入框
struct QuickAskCapsuleView: View {
    @State private var levels: [Float] = Array(repeating: 0.05, count: 30)
    
    @Bindable var state: QuickAskState
    
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
                    QuickAskInputView(state: state, onSend: onSend, onCancel: onCancel)
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
            .overlay(
                // 拖拽蒙版（用 overlay 不影响布局）
                Group {
                    if isDragOver {
                        dropOverlay
                    }
                }
            )
            // 拖拽直接绑定在主视图上，不用透明 overlay
            .onDrop(of: [.image, .fileURL], isTargeted: $isDragOver) { providers in
                handleDrop(providers: providers)
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
    
    // MARK: - Drop Overlay
    
    private var dropOverlay: some View {
        ZStack {
            // 半透明背景（填充整个区域）
            Color.black.opacity(0.6)
            
            // 蓝色背景
            Color.blue.opacity(0.15)
            
            // 虚线边框
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                .foregroundStyle(Color.blue.opacity(0.6))
                .padding(4)
            
            // 提示内容
            VStack(spacing: 12) {
                Image(systemName: "paperclip")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.blue)
                
                Text("Drop files here")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.blue)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Drop Handler
    
    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            // 处理图片
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadObject(ofClass: NSImage.self) { image, _ in
                    if let image = image as? NSImage {
                        Task { @MainActor in
                            state.addImage(image)
                        }
                    }
                }
            }
            
            // 处理文件
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    if let data = data as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        Task { @MainActor in
                            // 判断是否是图片文件
                            if let uti = UTType(filenameExtension: url.pathExtension),
                               uti.conforms(to: .image),
                               let image = NSImage(contentsOf: url) {
                                state.addImage(image)
                            } else {
                                state.addFile(url)
                            }
                        }
                    }
                }
            }
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
            // 左侧：App 图标
            appIcon
            
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
        .padding(.vertical, 10)
        .frame(height: 44)
    }
    
    // MARK: - Components
    
    private var appIcon: some View {
        Group {
            if let icon = state.targetApp?.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app.fill")
                    .foregroundStyle(HUDTheme.textPrimary)
            }
        }
        .frame(width: 24, height: 24)
        .clipShape(RoundedRectangle(cornerRadius: 6))
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
