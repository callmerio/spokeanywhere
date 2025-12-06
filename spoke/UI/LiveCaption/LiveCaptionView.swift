import SwiftUI
import Translation
import AppKit

// MARK: - NSScrollView Bridge

/// NSScrollView 桥接，用于精确检测滚动位置
struct AppKitScrollView<Content: View>: NSViewRepresentable {
    let content: Content
    @Binding var isAtBottom: Bool
    let scrollTrigger: Int  // 当此值变化时滚动到底部
    
    /// 底部检测容差
    private let bottomThreshold: CGFloat = 30
    
    init(isAtBottom: Binding<Bool>, scrollTrigger: Int, @ViewBuilder content: () -> Content) {
        self.content = content()
        self._isAtBottom = isAtBottom
        self.scrollTrigger = scrollTrigger
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        
        // 让滚动条更透明
        scrollView.verticalScroller?.alphaValue = 0.3
        
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        let documentView = FlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(hostingView)
        
        // hostingView 填满 documentView
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: documentView.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
        ])
        
        scrollView.documentView = documentView
        
        // 关键：让 documentView 宽度跟随 clipView（内容区），这样文字才会换行
        NSLayoutConstraint.activate([
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])
        
        // 监听滚动
        context.coordinator.scrollView = scrollView
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSScrollView.didLiveScrollNotification,
            object: scrollView
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSScrollView.didEndLiveScrollNotification,
            object: scrollView
        )
        
        // 保存初始 trigger
        context.coordinator.lastScrollTrigger = scrollTrigger
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        // 更新内容
        if let documentView = scrollView.documentView,
           let hostingView = documentView.subviews.first as? NSHostingView<Content> {
            hostingView.rootView = content
        }
        
        // 更新 coordinator 的引用
        context.coordinator.isAtBottomBinding = $isAtBottom
        context.coordinator.bottomThreshold = bottomThreshold
        
        // 检查是否需要滚动到底部
        let shouldScroll = scrollTrigger != context.coordinator.lastScrollTrigger
        context.coordinator.lastScrollTrigger = scrollTrigger
        
        if shouldScroll && isAtBottom {
            // 下一个 RunLoop 执行，最小延迟
            DispatchQueue.main.async { [weak scrollView] in
                guard let scrollView = scrollView else { return }
                Self.scrollToBottom(scrollView)
            }
        }
    }
    
    private static func scrollToBottom(_ scrollView: NSScrollView) {
        guard let documentView = scrollView.documentView else { return }
        
        // 强制完成布局，确保获取正确的内容高度
        documentView.layoutSubtreeIfNeeded()
        
        let contentHeight = documentView.frame.height
        let clipHeight = scrollView.contentView.bounds.height
        let maxScrollY = max(0, contentHeight - clipHeight)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.allowsImplicitAnimation = true
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxScrollY))
        }
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }
    
    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isAtBottom: $isAtBottom, bottomThreshold: bottomThreshold)
    }
    
    class Coordinator: NSObject {
        var isAtBottomBinding: Binding<Bool>
        var bottomThreshold: CGFloat
        weak var scrollView: NSScrollView?
        var lastScrollTrigger: Int = 0
        
        init(isAtBottom: Binding<Bool>, bottomThreshold: CGFloat) {
            self.isAtBottomBinding = isAtBottom
            self.bottomThreshold = bottomThreshold
        }
        
        @objc func scrollViewDidScroll(_ notification: Notification) {
            guard let scrollView = scrollView,
                  let documentView = scrollView.documentView else { return }
            
            let contentHeight = documentView.frame.height
            let clipHeight = scrollView.contentView.bounds.height
            let scrollY = scrollView.contentView.bounds.origin.y
            let maxScrollY = max(0, contentHeight - clipHeight)
            
            // 检测是否在底部（含容差）
            let atBottom = scrollY >= maxScrollY - bottomThreshold
            
            DispatchQueue.main.async {
                if self.isAtBottomBinding.wrappedValue != atBottom {
                    self.isAtBottomBinding.wrappedValue = atBottom
                }
            }
        }
    }
    
    /// Flipped NSView（使坐标系从上到下）
    private class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }
}

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
    @State private var isAtBottom: Bool = true
    @State private var scrollTrigger: Int = 0  // 触发滚动的计数器
    @State private var isUserSelecting: Bool = false  // 用户正在选择文本时暂停滚动
    @State private var vocabularyRefreshTrigger: Int = 0  // 生词列表变化时触发全量刷新
    
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
        .onReceive(NotificationCenter.default.publisher(for: .vocabularyChanged)) { _ in
            // 生词列表变化时触发全量刷新（包括之前的内容）
            vocabularyRefreshTrigger += 1
        }
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
    
    /// 折叠状态 - 列表模式
    /// 显示最近的句子流：[已确定句1] -> [已确定句2] -> [正在输入句]
    private var collapsedContent: some View {
        let isEmpty = manager.lineBuffer.items.isEmpty && manager.lineBuffer.pendingText.isEmpty
        
        return Group {
            if isEmpty {
                // 空状态
                Text("等待音频...")
                    .font(.system(size: CaptionDesign.fontSize))
                    .foregroundColor(CaptionDesign.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            } else {
                AppKitScrollView(isAtBottom: $isAtBottom, scrollTrigger: scrollTrigger) {
                    VStack(alignment: .leading, spacing: 16) {
                        // 1. 已确定的句子（原文+译文）- 支持生词高亮
                        ForEach(manager.lineBuffer.items) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                // 原文（带生词高亮 + 右键菜单）
                                captionText(for: item.original)
                                
                                // 译文（如果有）
                                if let translation = item.translation {
                                    Text(translation)
                                        .font(.system(size: CaptionDesign.translatedFontSize, weight: .regular))
                                        .foregroundColor(CaptionDesign.textSecondary)
                                        .lineSpacing(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        
                        // 2. 正在输入的流式文本（原文 + 流式翻译）
                        if !manager.lineBuffer.pendingText.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                // 流式原文
                                Text(manager.lineBuffer.pendingText)
                                    .font(.system(size: CaptionDesign.fontSize, weight: .regular))
                                    .foregroundColor(CaptionDesign.textPrimary.opacity(0.7))
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                // 流式翻译（如果有）
                                if !manager.lineBuffer.pendingTranslation.isEmpty {
                                    Text(manager.lineBuffer.pendingTranslation)
                                        .font(.system(size: CaptionDesign.translatedFontSize, weight: .regular))
                                        .foregroundColor(CaptionDesign.textSecondary.opacity(0.7))
                                        .lineSpacing(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        
                        // 底部占位
                        Color.clear.frame(height: 20)
                    }
                    .padding(CaptionDesign.padding)
                    .textSelection(.enabled)  // 允许选中文字
                }
                .frame(height: CaptionDesign.collapsedContentHeight * 2.5)
                .mask(LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.1),
                        .init(color: .black, location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .onChange(of: manager.lineBuffer.items) { _, _ in
                    // 用户选中文本时暂停自动滚动
                    if isAtBottom && !isUserSelecting {
                        scrollTrigger += 1
                    }
                }
                .onChange(of: manager.lineBuffer.pendingText) { _, _ in
                    if isAtBottom && !isUserSelecting {
                        scrollTrigger += 1
                    }
                }
                .onChange(of: scrollTrigger) { _, _ in
                    // 通过改变 scrollTrigger 触发 NSScrollView 的更新
                }
            }
        }
    }
    
    /// 展开状态 - 复用折叠模式设计，高度更大
    private var expandedContent: some View {
        AppKitScrollView(isAtBottom: $isAtBottom, scrollTrigger: scrollTrigger) {
            VStack(alignment: .leading, spacing: 16) {
                // 已确定的句子（原文+译文）- 支持生词高亮
                ForEach(manager.lineBuffer.items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        captionText(for: item.original)
                        
                        if let translation = item.translation {
                            Text(translation)
                                .font(.system(size: CaptionDesign.translatedFontSize, weight: .regular))
                                .foregroundColor(CaptionDesign.textSecondary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                
                // 正在输入的流式文本
                if !manager.lineBuffer.pendingText.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(manager.lineBuffer.pendingText)
                            .font(.system(size: CaptionDesign.fontSize, weight: .regular))
                            .foregroundColor(CaptionDesign.textPrimary.opacity(0.7))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        if !manager.lineBuffer.pendingTranslation.isEmpty {
                            Text(manager.lineBuffer.pendingTranslation)
                                .font(.system(size: CaptionDesign.translatedFontSize, weight: .regular))
                                .foregroundColor(CaptionDesign.textSecondary.opacity(0.7))
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                
                // 底部占位
                Color.clear.frame(height: 8)
            }
            .padding(CaptionDesign.padding)
            .textSelection(.enabled)
        }
        .frame(height: 400)
        .onChange(of: manager.lineBuffer.items) { _, _ in
            if isAtBottom && !isUserSelecting { scrollTrigger += 1 }
        }
        .onChange(of: manager.lineBuffer.pendingText) { _, _ in
            if isAtBottom && !isUserSelecting { scrollTrigger += 1 }
        }
    }
    
    // MARK: - Components
    
    /// 字幕文本（带生词高亮 + 右键菜单）
    @ViewBuilder
    private func captionText(for original: String) -> some View {
        VocabularyHighlightText(
            text: original,
            fontSize: CaptionDesign.fontSize,
            onSelectionStarted: { isUserSelecting = true },
            onSelectionEnded: { isUserSelecting = false },
            refreshTrigger: vocabularyRefreshTrigger
        )
        .fixedSize(horizontal: false, vertical: true)
    }
    
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
        // 找到最后一个未翻译的 item
        guard let item = await MainActor.run(body: {
            manager.lineBuffer.items.last(where: { $0.translation == nil })
        }) else { return }
        
        let textToTranslate = item.original
        guard !textToTranslate.isEmpty else { return }
        
        do {
            let response = try await session.translate(textToTranslate)
            await MainActor.run {
                manager.lineBuffer.updateTranslation(id: item.id, translation: response.targetText)
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
