import SwiftUI
import AppKit

// MARK: - Attachment Thumbnail View

/// 通用附件缩略图视图
/// 可复用于 QuickAsk、HUD 等多个入口
struct AttachmentThumbnailView: View {
    let attachment: Attachment
    var onRemove: (() -> Void)?
    
    /// 缩略图尺寸
    var size: CGFloat = 52
    
    @State private var isHovering = false
    @State private var videoThumbnail: NSImage?
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 内容
            contentView
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
            
            // 删除按钮（Hover 时显示）
            if isHovering, let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .background(Circle().fill(Color.black.opacity(0.6)))
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        switch attachment {
        case .image(_, let thumbnail, _), .screenshot(_, let thumbnail, _):
            imageContent(thumbnail: thumbnail)
            
        case .file(let url, _):
            fileContent(url: url)
            
        case .textBundle(_, let source, let count, _):
            textBundleContent(source: source, count: count)
        }
    }
    
    // MARK: - Image Content
    
    @ViewBuilder
    private func imageContent(thumbnail: NSImage?) -> some View {
        if let thumb = thumbnail {
            Image(nsImage: thumb)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            // 缩略图生成中
            ZStack {
                Color.white.opacity(0.1)
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
    }
    
    // MARK: - File Content
    
    @ViewBuilder
    private func fileContent(url: URL) -> some View {
        if attachment.isVideo {
            // 视频：显示缩略图 + 播放图标
            ZStack {
                if let thumb = videoThumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.white.opacity(0.1)
                    ProgressView()
                        .scaleEffect(0.6)
                }
                
                Image(systemName: "play.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.8))
                    .shadow(radius: 2)
            }
            .onAppear {
                loadVideoThumbnail(url: url)
            }
        } else {
            // 普通文件：图标 + 扩展名
            ZStack {
                Color.white.opacity(0.1)
                
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size * 0.6, height: size * 0.6)
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(url.pathExtension.uppercased())
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                .padding(4)
            }
        }
    }
    
    // MARK: - Text Bundle Content
    
    @ViewBuilder
    private func textBundleContent(source: String, count: Int) -> some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 2) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.8))
                
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func loadVideoThumbnail(url: URL) {
        Task.detached(priority: .userInitiated) {
            let thumbnail = Attachment.makeVideoThumbnail(from: url)
            await MainActor.run {
                self.videoThumbnail = thumbnail
            }
        }
    }
}

// MARK: - Attachments Area View

/// 附件区域视图（横向滚动）
struct AttachmentsAreaView: View {
    let attachments: [Attachment]
    let onRemove: (UUID) -> Void
    
    /// 缩略图尺寸
    var thumbnailSize: CGFloat = 52
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    AttachmentThumbnailView(
                        attachment: attachment,
                        onRemove: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                onRemove(attachment.id)
                            }
                        },
                        size: thumbnailSize
                    )
                }
            }
            .padding(.vertical, 4) // 给删除按钮留出空间
        }
        .frame(height: thumbnailSize + 16) // 缩略图 + padding
        .clipped()
    }
}

// MARK: - Preview

#Preview("Single Thumbnail") {
    ZStack {
        Color.black.opacity(0.8)
        
        HStack(spacing: 16) {
            // 图片
            AttachmentThumbnailView(
                attachment: .image(NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!, nil, UUID()),
                onRemove: {}
            )
            
            // 文本包
            AttachmentThumbnailView(
                attachment: .textBundle("content", "my-project", 42, UUID()),
                onRemove: {}
            )
        }
    }
    .frame(width: 200, height: 100)
}
