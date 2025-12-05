import SwiftUI

// MARK: - Live Caption View

/// 实时字幕视图
struct LiveCaptionView: View {
    
    @ObservedObject var manager: LiveCaptionManager
    @State private var isExpanded: Bool = false
    
    var onClose: () -> Void
    
    // MARK: - Constants
    
    /// 字幕字体大小
    private let captionFontSize: CGFloat = 20
    /// 折叠高度（2行原文 + 2行译文 + padding）
    private let collapsedHeight: CGFloat = 160
    private let expandedHeight: CGFloat = 400
    private let panelWidth: CGFloat = 600
    /// 内边距
    private let contentPadding: CGFloat = 20
    
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
    
    /// 折叠状态 - 固定2行滚动窗口，不可滚动
    private var collapsedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 使用行缓冲区显示
            let lines = manager.lineBuffer.lines
            
            if lines.isEmpty && manager.lineBuffer.pendingFragment.isEmpty {
                // 空状态
                Text("等待音频...")
                    .font(.system(size: captionFontSize))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                // 显示缓冲区的行
                ForEach(lines) { line in
                    CaptionLineView(
                        line: line,
                        showOriginal: manager.showOriginal,
                        fontSize: captionFontSize
                    )
                }
                
                // 正在输入的文本（pending）
                if !manager.lineBuffer.pendingFragment.isEmpty {
                    Text(manager.lineBuffer.pendingFragment)
                        .font(.system(size: captionFontSize, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Spacer(minLength: 0)
            }
        }
        .padding(contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            
            // 深色叠加 - 提高对比度
            Color.black.opacity(0.6)
        }
    }
}

// MARK: - Caption Line View

/// 单行字幕视图（用于折叠模式）
struct CaptionLineView: View {
    
    let line: CaptionLine
    let showOriginal: Bool
    let fontSize: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 原文
            if showOriginal {
                Text(line.original)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // 译文
            if let translated = line.translated {
                Text(translated)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !showOriginal {
                // 没有译文且不显示原文时，显示原文
                Text(line.original)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Caption Segment View

/// 单个字幕段落视图（用于展开模式）
struct CaptionSegmentView: View {
    
    let segment: CaptionSegment
    let showOriginal: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 原文
            if showOriginal {
                Text(segment.originalText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .textSelection(.enabled)
            }
            
            // 译文
            if let translated = segment.translatedText {
                Text(translated)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .textSelection(.enabled)
            } else if !showOriginal {
                // 没有译文且不显示原文时，显示原文
                Text(segment.originalText)
                    .font(.system(size: 16, weight: .medium))
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
