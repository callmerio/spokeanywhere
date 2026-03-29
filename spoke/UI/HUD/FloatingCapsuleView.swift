import AppKit
import SwiftUI

private typealias DS = DesignTokens

/// 悬浮面板视图 - Spokenly 风格
/// 纵向布局：上方文字区域（向上扩展）+ 下方控制栏
struct FloatingCapsuleView: View {
    @State private var levels: [Float] = Array(repeating: 0.05, count: 30)
    @State private var isHovering = false
    @State private var isHoveringComplete = false
    @State private var isHoveringCancel = false
    @State private var contentHeight: CGFloat = 0
    @State private var textContentHeight: CGFloat = 0
    @State private var pendingAutoScrollWorkItem: DispatchWorkItem?
    
    /// 文字区域最大高度（窗口高度 - controlBar高度 - padding）
    private let maxTextAreaHeight: CGFloat = 220
    
    /// 窗口固定高度（和 FloatingHUDManager 保持一致）
    private let windowHeight: CGFloat = 300
    
    /// 内容是否到达窗口顶部（需要显示遮罩）
    private var isContentAtTop: Bool {
        contentHeight >= windowHeight - 20 // 留 20px 的容差
    }
    
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
            VStack(spacing: 0) {
                // 上方：转写文字区域（向上扩展）
                // .success 状态也保留文字显示，直到 UI 消失
                let showText = state.phase == .recording
                    || state.phase == .processing
                    || state.phase == .thinking
                    || state.phase == .success
                if showText {
                    textArea
                }
                
                // 下方：固定控制栏（始终在底部）
                controlBar
            }
            .opacity((isHovering && state.phase == .recording) ? 0 : 1)
            // Hover 操作层：自动填充当前可见内容区域，上下各占一半
            .overlay {
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
                DS.Colors.overlayDark
                
                // 底部红色晕染 (仅在非 Hover 时显示)
                if state.phase == .recording && !isHovering {
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
                
                // 顶部微光
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
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.CornerRadius.xl))
        // 跟踪内容高度
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(ContentHeightKey.self) { height in
            contentHeight = height
        }
        .overlay(
            // 思考状态：跑马灯边框
            // 非思考状态：普通边框
            Group {
                if state.phase == .thinking {
                    RunningLightBorder()
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(DS.Colors.borderPrimary, lineWidth: 0.5)
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
        } // VStack 结束
        // 窗口顶部渐变遮罩：只有当内容到达窗口顶部时才可见（“传送门”效果）
        .overlay(alignment: .top) {
            if isContentAtTop {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.95),
                        Color.black.opacity(0.6),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 50)
                .allowsHitTesting(false)
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }
        }
        .accessibilityIdentifier(UITestIdentifiers.Element.floatingHUDRoot)
    }
    
    // MARK: - Text Area (上方，向上扩展)
    
    private var textArea: some View {
        // 使用 ScrollView + 动态高度，当内容超出时可滚动
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    // 转写文字（最新的在底部，可滚动）
                    if case .failure(let message, let reason, let suggestion) = state.phase {
                        VStack(alignment: .leading, spacing: 12) {
                            // 即使 AI 失败，如果已经有转写文本，也显示出来
                            if !state.partialText.isEmpty {
                                Text(state.partialText)
                                    .font(.system(size: 14))
                                    .foregroundStyle(DS.Colors.textSecondary)
                                    .lineSpacing(4)
                                    .italic()
                                
                                Divider()
                                    .background(DS.Colors.borderPrimary.opacity(0.2))
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 8) {
                                                                    Image(systemName: "exclamationmark.triangle.fill")
                                                                        .foregroundStyle(DS.Colors.error)
                                                                        .font(.system(size: 14))
                                                                        VStack(alignment: .leading, spacing: 4) {
                                        Text(message)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(DS.Colors.textPrimary)
                                        
                                        if let reason = reason {
                                            Text(reason)
                                                .font(.system(size: 13))
                                                .foregroundStyle(DS.Colors.textSecondary)
                                        }
                                    }
                                }
                                
                                                            if let suggestion = suggestion {
                                
                                                                Text(suggestion)
                                
                                                                    .font(.system(size: 12))
                                
                                                                    .padding(.vertical, 4)
                                
                                                                    .padding(.horizontal, 8)
                                
                                                                    .background(DS.Colors.accentInfo.opacity(0.1))
                                
                                                                    .foregroundStyle(DS.Colors.accentInfo)
                                
                                                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                
                                                            }
                                
                                
                            }
                        }
                    } else if !state.partialText.isEmpty {
                        Text(state.partialText)
                            .font(.system(size: 14))
                            .foregroundStyle(DS.Colors.textPrimary)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if state.phase == .processing {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("处理中...")
                                .font(.system(size: 14))
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                    } else if state.phase == .thinking || state.phase == .success {
                        // 思考中状态：文字模糊效果 + 提示
                        VStack(alignment: .leading, spacing: 8) {
                            if !state.partialText.isEmpty {
                                Text(state.partialText)
                                    .font(.system(size: 14))
                                    .foregroundStyle(
                                        state.phase == .success ? DS.Colors.textPrimary : DS.Colors.textSecondary
                                    )
                                    .lineSpacing(4)
                                    .blur(radius: state.phase == .thinking ? 2 : 0)
                                    .animation(.easeInOut(duration: 0.3), value: state.phase)
                            }
                            
                            if state.phase == .thinking {
                                HStack(spacing: 6) {
                                    ThinkingIndicator()
                                    Text("AI 思考中...")
                                        .font(.system(size: 13))
                                        .foregroundStyle(DS.Colors.textPrimary)
                                }
                                .transition(.opacity)
                            }
                        }
                    } else {
                        Text("正在聆听...")
                            .font(.system(size: 14))
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                    
                    // 底部锚点，用于自动滚动
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                // 测量内容实际高度
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: TextContentHeightKey.self, value: geo.size.height)
                    }
                )
            }
            .onPreferenceChange(TextContentHeightKey.self) { height in
                textContentHeight = height
            }
            .onChange(of: state.partialText) { _, _ in
                // 高频流式文本更新时做短防抖，避免同帧触发多次滚动导致 SwiftUI 警告
                pendingAutoScrollWorkItem?.cancel()
                let workItem = DispatchWorkItem {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
                pendingAutoScrollWorkItem = workItem
                scheduleFloatingCapsuleWorkItem(after: 0.08, workItem)
            }
            .onDisappear {
                pendingAutoScrollWorkItem?.cancel()
                pendingAutoScrollWorkItem = nil
            }
        }
        // 🔑 关键：动态高度 - 内容少时自适应，超出时固定在 maxHeight
        .frame(maxHeight: min(textContentHeight, maxTextAreaHeight))
        // 顶部渐变遮罩：当内容超出可视区域时显示
        .mask(
            VStack(spacing: 0) {
                // 顶部渐变（仅当内容可滚动时生效）
                if textContentHeight > maxTextAreaHeight {
                    LinearGradient(
                        colors: [.clear, .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 30)
                }
                
                // 主体区域完全可见
                Rectangle().fill(.black)
            }
        )
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
            } else if case .failure = state.phase {
                // 失败：显示红色警告图标
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(DS.Colors.error)
                    .font(.system(size: 16))
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
            Button {
                onComplete?()
            } label: {
                ZStack {
                    // Hover 时显示淡淡的蓝色，否则几乎透明（显示底部的灰黑色）
                    DS.Colors.accentInfo.opacity(isHoveringComplete ? 0.15 : 0.001)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(DS.Colors.accentInfo)
                            .shadow(color: DS.Colors.accentInfo.opacity(0.5), radius: 4)
                        
                        Text("完成录音")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(DS.Colors.textPrimary)
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
                .overlay(DS.Colors.borderPrimary)
            
            // 下半部分：取消录音
            Button {
                onCancel?()
            } label: {
                ZStack {
                    // Hover 时显示淡淡的红色，否则几乎透明
                    DS.Colors.error.opacity(isHoveringCancel ? 0.15 : 0.001)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(DS.Colors.error)
                            .shadow(color: DS.Colors.error.opacity(0.5), radius: 4)
                        
                        Text("取消录音")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(DS.Colors.textPrimary)
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
        .clipShape(RoundedRectangle(cornerRadius: DS.CornerRadius.xl))
        .background(DS.Colors.overlayLight) // 稍微加深底色，使文字更清晰
    }
    
    private var appIcon: some View {
        Group {
            if let icon = state.targetApp?.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app.fill")
                    .foregroundStyle(DS.Colors.textPrimary)
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
        .foregroundStyle(DS.Colors.textSecondary)
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

// MARK: - Custom Blur Background (CIGaussianBlur)

/// 自定义高斯模糊背景（可调节模糊强度）
struct CustomBlurBackground: NSViewRepresentable {
    var radius: CGFloat = 20
    var cornerRadius: CGFloat = 0
    var tintColor: NSColor?
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        
        // 高斯模糊滤镜
        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(radius, forKey: kCIInputRadiusKey)
            view.layer?.backgroundFilters = [blur]
        }
        
        // 圆角
        if cornerRadius > 0 {
            view.layer?.cornerRadius = cornerRadius
            view.layer?.masksToBounds = true
        }
        
        // 染色层（可选）
        if let tint = tintColor {
            view.layer?.backgroundColor = tint.cgColor
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(radius, forKey: kCIInputRadiusKey)
            nsView.layer?.backgroundFilters = [blur]
        }
        if cornerRadius > 0 {
            nsView.layer?.cornerRadius = cornerRadius
            nsView.layer?.masksToBounds = true
        }
        if let tint = tintColor {
            nsView.layer?.backgroundColor = tint.cgColor
        }
    }
}

// MARK: - Visual Effect Background (毛玻璃)

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var cornerRadius: CGFloat = 0
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        effectView.material = material
        effectView.blendingMode = blendingMode
        effectView.state = .active
        
        // 强调模式：让模糊更明显
        effectView.isEmphasized = true
        
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = cornerRadius
        effectView.layer?.masksToBounds = true
        return effectView
    }
    
    func updateNSView(_ effectView: NSVisualEffectView, context: Context) {
        effectView.material = material
        effectView.blendingMode = blendingMode
        effectView.state = .active
        
        if cornerRadius > 0 {
            effectView.layer?.cornerRadius = cornerRadius
            effectView.layer?.masksToBounds = true
        }
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
        return DS.Colors.recordingGlow.opacity(0.4 + 0.6 * progress)
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
        DS.Colors.accentInfo,
        DS.Colors.accentProcessing,
        DS.Colors.accentGlow,
        DS.Colors.accentDangerText,
        DS.Colors.warning,
        DS.Colors.accentGradientStart
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
                    .foregroundStyle(DS.Colors.success)
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
                    .fill(DS.Colors.textPrimary)
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
                            DS.Colors.accentBright,
                            DS.Colors.borderPrimary,
                            DS.Colors.borderPrimary,
                            DS.Colors.borderPrimary,
                            DS.Colors.accentBright
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
                            DS.Colors.accentBright,
                            DS.Colors.accentDim,
                            DS.Colors.accentDim,
                            DS.Colors.accentDim,
                            DS.Colors.accentBright
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

// MARK: - Content Height PreferenceKey

/// 用于检测内容高度的 PreferenceKey
private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// 用于检测文字区域内容高度的 PreferenceKey
private struct TextContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
