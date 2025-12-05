import SwiftUI
import Translation

// MARK: - Design Constants

/// 字幕卡片设计常量 - 参考 Tailwind CSS 设计系统
private enum CaptionDesign {
    // MARK: - Colors
    /// 卡片背景色 - rgba(27, 28, 30, 0.7)
    static let cardBackground = Color(red: 27/255, green: 28/255, blue: 30/255).opacity(0.7)
    /// 边框颜色 - rgba(255, 255, 255, 0.05)
    static let borderColor = Color.white.opacity(0.05)
    /// 主文本色 - #f9fafb
    static let textPrimary = Color(red: 249/255, green: 250/255, blue: 251/255)
    /// 次要文本色 - #9ca3af (译文)
    static let textSecondary = Color(red: 156/255, green: 163/255, blue: 175/255)
    /// 拖动指示器颜色 - white/20
    static let dragIndicatorColor = Color.white.opacity(0.2)
    
    // MARK: - Dimensions
    /// 卡片最大宽度 - max-w-2xl ≈ 672px
    static let maxWidth: CGFloat = 672
    /// 折叠状态内容区高度（2行英文 + 2行译文 + 间距）
    static let collapsedContentHeight: CGFloat = 100
    /// 圆角 - rounded-xl = 1.25rem ≈ 20pt
    static let cornerRadius: CGFloat = 20
    /// 内边距 - p-6 = 1.5rem ≈ 24pt
    static let padding: CGFloat = 24
    /// 字体大小 - text-lg ≈ 18pt
    static let fontSize: CGFloat = 18
    /// 译文字体大小
    static let translatedFontSize: CGFloat = 16
    /// 行间距 - space-y-1 ≈ 4pt
    static let lineSpacing: CGFloat = 4
    /// 毛玻璃模糊半径 - blur(20px)
    static let blurRadius: CGFloat = 20
    /// 阴影半径 - shadow-2xl
    static let shadowRadius: CGFloat = 25
    /// 拖动指示器宽度 - w-8 = 32pt
    static let dragIndicatorWidth: CGFloat = 32
    /// 拖动指示器高度 - h-1 = 4pt
    static let dragIndicatorHeight: CGFloat = 4
}

// MARK: - Live Caption View

/// 实时字幕视图 - 简洁卡片式设计
/// 集成 Apple Translation API 实现实时翻译（macOS 15+）
struct LiveCaptionView: View {
    
    @ObservedObject var manager: LiveCaptionManager
    @ObservedObject var translator = TranslationService.shared
    
    @State private var isExpanded: Bool = false
    @State private var isHovering: Bool = false
    
    var onClose: () -> Void
    
    var body: some View {
        ZStack {
            // 内容
            VStack(spacing: 0) {
                if isExpanded {
                    expandedContent
                } else {
                    collapsedContent
                }
                
                // 底部拖动指示器
                dragIndicator
            }
            
            // Hover 时显示工具栏
            if isHovering {
                VStack {
                    HStack {
                        Spacer()
                        hoverToolbar
                    }
                    .padding(12)
                    Spacer()
                }
            }
        }
        .frame(width: CaptionDesign.maxWidth)
        .fixedSize(horizontal: false, vertical: true)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CaptionDesign.cornerRadius))
        .overlay(cardBorder)
        .shadow(color: .black.opacity(0.4), radius: CaptionDesign.shadowRadius, x: 0, y: 10)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onAppear {
            setupTranslation()
        }
        .onChange(of: manager.translationEnabled) { _, enabled in
            if enabled {
                setupTranslation()
            }
        }
        // 翻译功能暂时禁用 - 等待后续优化（节流/后台线程）
        // .onChange(of: manager.lineBuffer.stableTextForTranslation) { _, newText in
        //     if let text = newText, !text.isEmpty, manager.translationEnabled {
        //         triggerTranslation()
        //     }
        // }
        // .modifier(TranslationTaskModifier(
        //     manager: manager,
        //     translator: translator,
        //     onTranslationTriggered: { setupTranslation() }
        // ))
    }
    
    // MARK: - Translation
    
    /// 设置翻译（准备 configuration）
    private func setupTranslation() {
        guard manager.translationEnabled else { return }
        
        if #available(macOS 15.0, *) {
            translator.prepareSession(
                source: manager.captionLocale,
                target: translator.targetLanguage
            )
        }
    }
    
    /// 触发翻译
    private func triggerTranslation() {
        if #available(macOS 15.0, *) {
            translator.invalidateSession()
            setupTranslation()
        }
    }
    
    // MARK: - Content Views
    
    /// 折叠状态 - 简洁卡片
    /// 显示连续的文本流，限制最多 2 行
    private var collapsedContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            let displayText = manager.lineBuffer.displayText
            
            if displayText.isEmpty && manager.pendingText.isEmpty {
                // 空状态
                Text("等待音频...")
                    .font(.system(size: CaptionDesign.fontSize))
                    .foregroundColor(CaptionDesign.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                // 原文 - 白色，限制 2 行
                let originalText = displayText.isEmpty ? manager.pendingText : displayText
                
                if !originalText.isEmpty {
                    Text(originalText)
                        .font(.system(size: CaptionDesign.fontSize, weight: .regular))
                        .foregroundColor(CaptionDesign.textPrimary)
                        .lineSpacing(4)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0.5, y: 0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .animation(.easeInOut(duration: 0.15), value: originalText)
                }
                
                // 译文 - 灰色，限制 2 行
                let translatedText = manager.lineBuffer.translatedText
                if manager.translationEnabled && !translatedText.isEmpty {
                    Text(translatedText)
                        .font(.system(size: CaptionDesign.translatedFontSize, weight: .regular))
                        .foregroundColor(CaptionDesign.textSecondary)
                        .lineSpacing(3)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .animation(.easeInOut(duration: 0.15), value: translatedText)
                }
            }
        }
        .padding(CaptionDesign.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    /// 展开状态 - 显示历史
    private var expandedContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    // 安全地复制 segments 避免并发修改
                    let segmentsCopy = Array(manager.segments.prefix(100))
                    ForEach(segmentsCopy) { segment in
                        CaptionSegmentView(
                            segment: segment,
                            showOriginal: manager.showOriginal
                        )
                        .id(segment.id)
                    }
                    
                    // 正在输入的文本
                    if !manager.pendingText.isEmpty {
                        Text(manager.pendingText)
                            .font(.system(size: CaptionDesign.fontSize - 2))
                            .foregroundColor(CaptionDesign.textSecondary)
                            .id("pending")
                    }
                }
                .padding(CaptionDesign.padding)
            }
            .frame(height: 300)
            .onChange(of: manager.segments.count) { _, newCount in
                // 安全滚动到底部
                if newCount > 0 {
                    proxy.scrollTo("pending", anchor: .bottom)
                }
            }
        }
    }
    
    // MARK: - Components
    
    /// 底部拖动指示器
    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: CaptionDesign.dragIndicatorHeight / 2)
            .fill(CaptionDesign.dragIndicatorColor)
            .frame(width: CaptionDesign.dragIndicatorWidth, height: CaptionDesign.dragIndicatorHeight)
            .padding(.bottom, 8)
    }
    
    /// Hover 工具栏
    private var hoverToolbar: some View {
        HStack(spacing: 8) {
            // 展开/收起
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            // 关闭
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Background & Border
    
    /// 卡片背景 - 毛玻璃 + 深色叠加
    private var cardBackground: some View {
        ZStack {
            // 毛玻璃效果
            VisualEffectBlur(material: .hudWindow, cornerRadius: CaptionDesign.cornerRadius)
            // 深色叠加
            CaptionDesign.cardBackground
        }
    }
    
    /// 卡片边框
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: CaptionDesign.cornerRadius)
            .stroke(CaptionDesign.borderColor, lineWidth: 1)
    }
}

// MARK: - Caption Line View

/// 单行字幕视图（用于折叠模式）
/// 原文白色 + 译文灰色的双行布局
struct CaptionLineView: View {
    
    let line: CaptionLine
    let showOriginal: Bool
    let fontSize: CGFloat
    
    /// 主文本色 - #f9fafb
    private var textPrimary: Color {
        Color(red: 249/255, green: 250/255, blue: 251/255)
    }
    /// 次要文本色 - #9ca3af (译文)
    private var textSecondary: Color {
        Color(red: 156/255, green: 163/255, blue: 175/255)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 原文 - 白色
            if showOriginal {
                Text(line.original)
                    .font(.system(size: fontSize, weight: .regular))
                    .foregroundColor(textPrimary)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // 译文 - 灰色（占位符：中文译文）
            if let translated = line.translated {
                Text(translated)
                    .font(.system(size: fontSize, weight: .regular))
                    .foregroundColor(textSecondary)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !showOriginal {
                // 没有译文且不显示原文时，显示原文
                Text(line.original)
                    .font(.system(size: fontSize, weight: .regular))
                    .foregroundColor(textPrimary)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Caption Segment View

/// 单个字幕段落视图（用于展开模式）
/// 原文白色 + 译文灰色
struct CaptionSegmentView: View {
    
    let segment: CaptionSegment
    let showOriginal: Bool
    
    /// 主文本色 - #f9fafb
    private var textPrimary: Color {
        Color(red: 249/255, green: 250/255, blue: 251/255)
    }
    /// 次要文本色 - #9ca3af (译文)
    private var textSecondary: Color {
        Color(red: 156/255, green: 163/255, blue: 175/255)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 原文 - 白色
            if showOriginal {
                Text(segment.originalText)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(textPrimary)
                    .lineSpacing(6)
                    .textSelection(.enabled)
            }
            
            // 译文 - 灰色（占位符：中文译文）
            if let translated = segment.translatedText {
                Text(translated)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(textSecondary)
                    .lineSpacing(6)
                    .textSelection(.enabled)
            } else if !showOriginal {
                // 没有译文且不显示原文时，显示原文
                Text(segment.originalText)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(textPrimary)
                    .lineSpacing(6)
                    .textSelection(.enabled)
            }
        }
    }
}

// MARK: - Translation Task Modifier

/// 翻译任务修饰符（macOS 15+）
/// 封装 .translationTask 以处理版本兼容性
struct TranslationTaskModifier: ViewModifier {
    @ObservedObject var manager: LiveCaptionManager
    @ObservedObject var translator: TranslationService
    var onTranslationTriggered: () -> Void
    
    func body(content: Content) -> some View {
        Group {
            if #available(macOS 15.0, *) {
                content
                    .modifier(TranslationTaskModifier15(
                        manager: manager,
                        translator: translator
                    ))
            } else {
                content
            }
        }
    }
}

/// macOS 15+ 专用的翻译修饰符
@available(macOS 15.0, *)
struct TranslationTaskModifier15: ViewModifier {
    @ObservedObject var manager: LiveCaptionManager
    @ObservedObject var translator: TranslationService
    
    func body(content: Content) -> some View {
        content
            .translationTask(translator.configuration) { session in
                await performTranslation(session: session)
            }
    }
    
    private func performTranslation(session: TranslationSession) async {
        guard let textToTranslate = manager.lineBuffer.stableTextForTranslation,
              !textToTranslate.isEmpty else { return }
        
        do {
            let response = try await session.translate(textToTranslate)
            await MainActor.run {
                manager.lineBuffer.updateTranslation(response.targetText)
            }
        } catch {
            // 翻译失败，静默处理
        }
    }
}

// MARK: - Preview

#Preview("Live Caption Card") {
    ZStack {
        // 背景模拟
        LinearGradient(
            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack {
            Spacer()
            LiveCaptionView(
                manager: LiveCaptionManager.shared,
                onClose: {}
            )
            .padding(.bottom, 60)
        }
    }
    .frame(width: 800, height: 600)
}
