import Foundation
import AppKit
import AVFoundation
import UniformTypeIdentifiers

// MARK: - Attachment Type

/// 通用附件类型
/// 可复用于 QuickAsk、HUD、以及未来的各种输入入口
enum Attachment: Identifiable, Equatable {
    /// 图片：原图 + 缩略图 + ID
    case image(NSImage, NSImage?, UUID)
    
    /// 截图：原图 + 缩略图 + ID
    case screenshot(NSImage, NSImage?, UUID)
    
    /// 普通文件：URL + ID
    case file(URL, UUID)
    
    /// 文本包：从 ZIP/文件夹提取的合并文本
    /// 参数：合并后的文本内容、来源描述、文件数量、ID
    case textBundle(String, String, Int, UUID)
    
    var id: UUID {
        switch self {
        case .image(_, _, let id),
             .screenshot(_, _, let id),
             .file(_, let id),
             .textBundle(_, _, _, let id):
            return id
        }
    }
    
    /// 缩略图（用于显示）
    var thumbnail: NSImage? {
        switch self {
        case .image(_, let thumb, _), .screenshot(_, let thumb, _):
            return thumb
        case .file, .textBundle:
            return nil // 这些类型在 View 层单独处理图标
        }
    }
    
    /// 原图（用于发送）
    var originalImage: NSImage? {
        switch self {
        case .image(let image, _, _), .screenshot(let image, _, _):
            return image
        default:
            return nil
        }
    }
    
    /// 文件名
    var fileName: String? {
        switch self {
        case .file(let url, _):
            return url.lastPathComponent
        case .textBundle(_, let source, _, _):
            return source
        default:
            return nil
        }
    }
    
    /// 显示标题
    var displayTitle: String {
        switch self {
        case .image:
            return "图片"
        case .screenshot:
            return "截图"
        case .file(let url, _):
            return url.lastPathComponent
        case .textBundle(_, let source, let count, _):
            return "\(source) (\(count) 文件)"
        }
    }
    
    /// 是否是视频文件
    var isVideo: Bool {
        if case .file(let url, _) = self {
            if let uti = UTType(filenameExtension: url.pathExtension) {
                return uti.conforms(to: .movie) || uti.conforms(to: .video)
            }
        }
        return false
    }
    
    /// 是否是文本包
    var isTextBundle: Bool {
        if case .textBundle = self { return true }
        return false
    }
    
    /// 文本内容（用于发送给 LLM）
    var textContent: String? {
        switch self {
        case .textBundle(let content, _, _, _):
            return content
        default:
            return nil
        }
    }
    
    static func == (lhs: Attachment, rhs: Attachment) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Thumbnail Generation

extension Attachment {
    /// 生成缩略图（同步，建议在后台线程调用）
    static func makeThumbnail(from image: NSImage, maxSize: CGFloat = 256) -> NSImage {
        let size = image.size
        guard size.width > 0 && size.height > 0 else { return image }
        
        let scale = min(maxSize / size.width, maxSize / size.height, 1.0)
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)
        
        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy, fraction: 1.0)
        thumbnail.unlockFocus()
        
        return thumbnail
    }
    
    /// 从视频生成缩略图
    static func makeVideoThumbnail(from url: URL, maxSize: CGFloat = 256) -> NSImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxSize, height: maxSize)
        
        do {
            let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        } catch {
            print("Failed to generate video thumbnail: \(error)")
            return nil
        }
    }
}

// MARK: - Attachment Source

/// 附件来源（用于区分添加方式）
enum AttachmentSource {
    case paste          // 粘贴
    case drop           // 拖拽
    case picker         // 文件选择器
    case screenshot     // 屏幕截图
    case photos         // 图库
    case folder         // 文件夹导入
    case zip            // ZIP 导入
}
