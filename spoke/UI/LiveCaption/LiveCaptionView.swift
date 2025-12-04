import SwiftUI

// MARK: - Live Caption View

/// 实时字幕视图
struct LiveCaptionView: View {
    
    @ObservedObject var manager: LiveCaptionManager
    @State private var isExpanded: Bool = false
    
    var onClose: () -> Void
    
    // MARK: - Constants
    
    private let collapsedHeight: CGFloat = 120
    private let expandedHeight: CGFloat = 400
    private let panelWidth: CGFloat = 600
    
    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            LiveCaptionToolbar(
                manager: manager,
                isExpanded: $isExpanded,
                onClose: onClose
            )
            
            // 分隔线
            Divider()
                .background(Color.white.opacity(0.1))
            
            // 内容区域
            if isExpanded {
                expandedContent
            } else {
                collapsedContent
            }
        }
        .frame(width: panelWidth)
        .frame(height: isExpanded ? expandedHeight : collapsedHeight)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
    
    // MARK: - Content Views
    
    /// 折叠状态 - 显示最新内容（不截断）
    private var collapsedContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // 显示最近几段（不用省略号）
                ForEach(recentSegments) { segment in
                    CaptionSegmentView(
                        segment: segment,
                        showOriginal: manager.showOriginal
                    )
                }
                
                // 正在输入的文本
                if !manager.pendingText.isEmpty {
                    Text(manager.pendingText)
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                // 空状态
                if manager.segments.isEmpty && manager.pendingText.isEmpty {
                    Text("等待音频...")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    /// 折叠状态显示的最近段落（最多3段）
    private var recentSegments: [CaptionSegment] {
        Array(manager.segments.suffix(3))
    }
    
    /// 展开状态 - 显示历史
    private var expandedContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(manager.segments) { segment in
                        CaptionSegmentView(
                            segment: segment,
                            showOriginal: manager.showOriginal
                        )
                        .id(segment.id)
                    }
                    
                    // 正在输入的文本
                    if !manager.pendingText.isEmpty {
                        Text(manager.pendingText)
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.6))
                            .id("pending")
                    }
                }
                .padding(16)
            }
            .onChange(of: manager.segments.count) {
                // 自动滚动到底部
                withAnimation {
                    if let lastId = manager.segments.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Background
    
    private var panelBackground: some View {
        ZStack {
            // 毛玻璃
            VisualEffectBlur(material: .hudWindow, cornerRadius: 12)
            
            // 深色叠加
            Color.black.opacity(0.4)
        }
    }
}

// MARK: - Caption Segment View

/// 单个字幕段落视图
struct CaptionSegmentView: View {
    
    let segment: CaptionSegment
    let showOriginal: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 原文
            if showOriginal {
                Text(segment.originalText)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .textSelection(.enabled)
            }
            
            // 译文
            if let translated = segment.translatedText {
                Text(translated)
                    .font(.system(size: 15))
                    .foregroundColor(showOriginal ? .white.opacity(0.7) : .white)
                    .textSelection(.enabled)
            } else if !showOriginal {
                // 没有译文且不显示原文时，显示原文
                Text(segment.originalText)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .textSelection(.enabled)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LiveCaptionView(
        manager: LiveCaptionManager.shared,
        onClose: {}
    )
    .frame(width: 600, height: 400)
    .background(Color.gray)
}
