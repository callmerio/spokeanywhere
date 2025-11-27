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
        // 外层容器：固定高度，内容从底部向上扩展
        VStack {
            Spacer() // 顶部弹性空间，把内容推到底部
            
            // 实际内容区域
            ZStack {
                // 正常内容层
                VStack(spacing: 0) {
                    // 上方：转写文字区域（向上扩展）
                    // .success 状态也保留文字显示，直到 UI 消失
                    if state.phase == .recording || state.phase == .processing || state.phase == .thinking || state.phase == .success {
                        textArea
                    }
                    
                    // 下方：固定控制栏（始终在底部）
                    controlBar
                }
                .opacity((isHovering && state.phase == .recording) ? 0 : 1)
                
                // Hover 操作层
                if isHovering && state.phase == .recording {
                    hoverOverlay
                        .transition(.opacity)
                }
            }
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
            // 思考状态：跑马灯边框
            // 非思考状态：普通边框
            Group {
                if state.phase == .thinking {
                    RunningLightBorder()
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                }
            }
        )
        .animation(.easeInOut(duration: 0.2), value: isHovering) // Hover 切换动画
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
        } // VStack 结束
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
            } else if state.phase == .thinking || state.phase == .success {
                // 思考中状态：文字模糊效果 + 提示
                // Success 状态下也保持这个布局，但提示语可能会变
                VStack(alignment: .leading, spacing: 8) {
                    if !state.partialText.isEmpty {
                        Text(state.partialText)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(state.phase == .success ? 0.9 : 0.5)) // 成功后变亮
                            .lineSpacing(4)
                            .blur(radius: state.phase == .thinking ? 2 : 0) // 思考时模糊，成功后清晰
                            .animation(.easeInOut(duration: 0.3), value: state.phase)
                    }
                    
                    if state.phase == .thinking {
                        HStack(spacing: 6) {
                            ThinkingIndicator()
                            Text("AI 思考中...")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .transition(.opacity)
                    }
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
            // 左侧：App 图标 (Success 状态下不再显示大勾勾，而是保持 App 图标)
            appIcon
            
            Spacer().frame(width: 12)
            
            if state.phase == .recording {
                ScrollingWaveform(levels: levels)
                    .frame(width: 120, height: 16)
            } else if state.phase == .thinking || state.phase == .success {
                // 思考中/成功：显示状态指示器 (Spinner -> Checkmark)
                StatusIndicator(isThinking: state.phase == .thinking)
                    .frame(width: 20, height: 20)
            }
            
            Spacer()
            
            if state.phase == .recording || state.phase == .thinking || state.phase == .success {
                brandLabel
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
    
    // MARK: - Helpers
    
    private func updateWaveform(_ level: Float) {
        var newLevels = levels
        newLevels.removeFirst()
        newLevels.append(level)
        // 缩短动画时间，让波形跳动更敏捷
        withAnimation(.linear(duration: 0.05)) {
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
                    // 动态高度：即使音量很小，也给一个基础波动
                    .frame(width: 2, height: barHeight(for: level))
            }
        }
    }
    
    private func barHeight(for level: Float) -> CGFloat {
        let minH: CGFloat = 4
        let maxH: CGFloat = 20 // 增加最大高度
        
        // 非线性映射：让小音量也能有明显的高度
        // pow(level, 0.7) 会提升小数值的权重
        let adjustedLevel = CGFloat(pow(Double(level), 0.7))
        
        return minH + adjustedLevel * (maxH - minH)
    }
    
    private func barColor(for index: Int) -> Color {
        let count = levels.count
        // 让右侧（最新）的波纹更亮更红
        let progress = Double(index) / Double(count - 1)
        // 增加一点不透明度
        return Color.red.opacity(0.4 + 0.6 * progress)
    }
}

// MARK: - Status Indicator (Spinner -> Checkmark)

struct StatusIndicator: View {
    /// 当前状态：true = thinking (spinner), false = success (checkmark)
    let isThinking: Bool
    
    @State private var checkmarkScale: CGFloat = 0
    @State private var rotation: Double = 0
    
    // 彩色点的颜色
    private let dotColors: [Color] = [
        Color(red: 0.3, green: 0.5, blue: 1.0),   // 蓝
        Color(red: 0.5, green: 0.3, blue: 1.0),   // 紫蓝
        Color(red: 0.8, green: 0.3, blue: 0.9),   // 紫
        Color(red: 1.0, green: 0.4, blue: 0.7),   // 粉
        Color(red: 1.0, green: 0.5, blue: 0.4),   // 橙红
        Color(red: 0.3, green: 0.7, blue: 0.9),   // 青
    ]
    
    var body: some View {
        ZStack {
            if isThinking {
                // 彩色点旋转
                ZStack {
                    ForEach(0..<6, id: \.self) { index in
                        Circle()
                            .fill(dotColors[index])
                            .frame(width: 4, height: 4)
                            .offset(y: -7) // 半径
                            .rotationEffect(.degrees(Double(index) * 60))
                    }
                }
                .rotationEffect(.degrees(rotation))
            } else {
                // 成功对号
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.green)
                    .scaleEffect(checkmarkScale)
            }
        }
        .frame(width: 18, height: 18)
        .onAppear {
            if isThinking {
                startSpinner()
            }
        }
        .onChange(of: isThinking) { wasThinking, nowThinking in
            if wasThinking && !nowThinking {
                // 转到成功状态
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    checkmarkScale = 1
                }
            } else if nowThinking {
                // 重置到思考状态
                checkmarkScale = 0
                rotation = 0
                startSpinner()
            }
        }
    }
    
    private func startSpinner() {
        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }
}

// MARK: - Thinking Indicator (文字旁的小动画)

struct ThinkingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 4, height: 4)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Running Light Border (白色流光边框)

struct RunningLightBorder: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // 外层光晕 (柔和扩散)
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.8),
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.8)
                        ],
                        center: .center,
                        angle: .degrees(rotation)
                    ),
                    lineWidth: 2
                )
                .blur(radius: 3)
            
            // 内层清晰边框
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.9),
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.9)
                        ],
                        center: .center,
                        angle: .degrees(rotation)
                    ),
                    lineWidth: 1.5
                )
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
