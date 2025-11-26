import SwiftUI
import AppKit

/// 悬浮面板视图 - Spokenly 风格
/// 纵向布局：上方文字区域（向上扩展）+ 下方控制栏
struct FloatingCapsuleView: View {
    @State private var levels: [Float] = Array(repeating: 0.05, count: 30)
    @State private var isHovering = false
    @State private var isHoveringComplete = false
    @State private var isHoveringCancel = false
    
    let state: RecordingState
    
    /// 完成录音回调
    var onComplete: (() -> Void)?
    /// 取消录音回调
    var onCancel: (() -> Void)?
    /// Hover 状态改变回调
    var onHoverChange: ((Bool) -> Void)?
    
    var body: some View {
        ZStack {
            // 正常内容层
            VStack(spacing: 0) {
                // 上方：转写文字区域（向上扩展）
                if state.phase == .recording || state.phase == .processing {
                    textArea
                        .transition(.asymmetric(
                            insertion: .opacity.animation(.easeInOut(duration: 0.15).delay(0.1)),
                            removal: .opacity.animation(.easeInOut(duration: 0.1))
                        ))
                }
                
                // 下方：固定控制栏（始终在底部）
                controlBar
            }
            .frame(minHeight: 44, alignment: .bottom)
            .opacity((isHovering && state.phase == .recording) ? 0 : 1)
            
            // Hover 操作层
            if isHovering && state.phase == .recording {
                hoverOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isHovering) // Hover 切换动画
        .background(
            ZStack {
                // 毛玻璃底层
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                
                // 深色叠加
                Color.black.opacity(0.3)
                
                // 底部红色晕染 (仅在非 Hover 时显示)
                if state.phase == .recording && !isHovering {
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
                
                // 顶部微光
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
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .onChange(of: state.audioLevel) { _, newLevel in
            updateWaveform(newLevel)
        }
        // 监听整个视图的 Hover 状态
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
            onHoverChange?(hovering)
        }
    }
    
    // MARK: - Text Area (上方，向上扩展)
    
    private var textArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 转写文字（最新的在底部，可滚动）
            if !state.partialText.isEmpty {
                Text(state.partialText)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true) // 高度自适应
            } else if state.phase == .processing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("处理中...")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                }
            } else {
                Text("正在聆听...")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Control Bar (下方固定)
    
    private var controlBar: some View {
        HStack(spacing: 0) {
            appIcon
            Spacer().frame(width: 12)
            
            if state.phase == .recording {
                ScrollingWaveform(levels: levels)
                    .frame(width: 120, height: 16)
            }
            
            Spacer()
            
            if state.phase == .recording {
                brandLabel
            } else if state.phase == .success {
                successIcon
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(height: 44)
    }
    
    // MARK: - Hover Overlay
    
    private var hoverOverlay: some View {
        VStack(spacing: 0) {
            // 上半部分：完成录音
            Button(action: { onComplete?() }) {
                ZStack {
                    // Hover 时显示淡淡的蓝色，否则几乎透明（显示底部的灰黑色）
                    Color.blue.opacity(isHoveringComplete ? 0.15 : 0.001)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.blue)
                            .shadow(color: .blue.opacity(0.5), radius: 4)
                        
                        Text("完成录音")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .shadow(radius: 1)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(maxHeight: .infinity)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHoveringComplete = hovering
                }
            }
            
            // 分割线 (纯色)
            Divider()
                .overlay(Color.white.opacity(0.1))
            
            // 下半部分：取消录音
            Button(action: { onCancel?() }) {
                ZStack {
                    // Hover 时显示淡淡的红色，否则几乎透明
                    Color.red.opacity(isHoveringCancel ? 0.15 : 0.001)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.red)
                            .shadow(color: .red.opacity(0.5), radius: 4)
                        
                        Text("取消录音")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .shadow(radius: 1)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(maxHeight: .infinity)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHoveringCancel = hovering
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .background(Color.black.opacity(0.4)) // 稍微加深底色，使文字更清晰
    }
    
    private var appIcon: some View {
        Group {
            if let icon = state.targetApp?.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app.fill")
                    .foregroundStyle(.white.opacity(0.8))
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
        .foregroundStyle(.white.opacity(0.6))
    }
    
    private var successIcon: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
            .font(.system(size: 20))
    }
    
    // MARK: - Helpers
    
    private func updateWaveform(_ level: Float) {
        var newLevels = levels
        newLevels.removeFirst()
        newLevels.append(level)
        withAnimation(.linear(duration: 0.08)) {
            self.levels = newLevels
        }
    }
}

// MARK: - Visual Effect Background (毛玻璃)

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Scrolling Waveform

struct ScrollingWaveform: View {
    let levels: [Float]
    
    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                Capsule()
                    .fill(barColor(for: index))
                    .frame(width: 2, height: barHeight(for: level))
            }
        }
    }
    
    private func barHeight(for level: Float) -> CGFloat {
        let minH: CGFloat = 3
        let maxH: CGFloat = 14
        return minH + CGFloat(level) * (maxH - minH)
    }
    
    private func barColor(for index: Int) -> Color {
        let count = levels.count
        let progress = Double(index) / Double(count - 1)
        return Color.red.opacity(0.3 + 0.7 * progress)
    }
}
