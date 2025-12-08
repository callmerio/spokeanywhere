import SwiftUI
import AppKit
import OSLog

private let logger = Logger(subsystem: "com.spokeanywhere", category: "CardAttachment")

// MARK: - Card Attachment

/// 卡片附件（支持 JSON 持久化）
/// 图片存储为文件路径，按需加载
struct CardAttachment: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    
    /// 图片文件名（存储在 attachments 目录下）
    let fileName: String
    
    /// 原图尺寸（用于布局计算）
    let originalWidth: CGFloat
    let originalHeight: CGFloat
    
    init(id: UUID = UUID(), createdAt: Date = Date(), fileName: String, originalWidth: CGFloat, originalHeight: CGFloat) {
        self.id = id
        self.createdAt = createdAt
        self.fileName = fileName
        self.originalWidth = originalWidth
        self.originalHeight = originalHeight
    }
    
    /// 宽高比
    var aspectRatio: CGFloat {
        guard originalHeight > 0 else { return 1 }
        return originalWidth / originalHeight
    }
    
    /// 是否为横向图片
    var isLandscape: Bool {
        aspectRatio > 1
    }
}

// MARK: - Attachment Storage

/// 附件存储管理
@MainActor
final class CardAttachmentStorage {
    
    static let shared = CardAttachmentStorage()
    
    /// 附件存储目录
    private var attachmentsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let spokeDir = appSupport.appendingPathComponent("Spoke", isDirectory: true)
        return spokeDir.appendingPathComponent("attachments", isDirectory: true)
    }
    
    private init() {
        // 确保目录存在
        try? FileManager.default.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Save
    
    /// 保存图片并返回附件对象
    func saveImage(_ image: NSImage) -> CardAttachment? {
        let id = UUID()
        let fileName = "\(id.uuidString).png"
        let fileURL = attachmentsDirectory.appendingPathComponent(fileName)
        
        // 获取原图尺寸
        let size = image.size
        guard size.width > 0, size.height > 0 else {
            logger.error("❌ 图片尺寸无效")
            return nil
        }
        
        // 保存为 PNG
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            logger.error("❌ 图片转换失败")
            return nil
        }
        
        do {
            try pngData.write(to: fileURL, options: .atomic)
            logger.info("💾 保存附件: \(fileName)")
            
            return CardAttachment(
                id: id,
                fileName: fileName,
                originalWidth: size.width,
                originalHeight: size.height
            )
        } catch {
            logger.error("❌ 保存附件失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Load
    
    /// 加载缩略图
    func loadThumbnail(for attachment: CardAttachment, maxSize: CGFloat = 200) -> NSImage? {
        let fileURL = attachmentsDirectory.appendingPathComponent(attachment.fileName)
        guard let image = NSImage(contentsOf: fileURL) else {
            logger.warning("⚠️ 无法加载附件: \(attachment.fileName)")
            return nil
        }
        
        // 生成缩略图
        return makeThumbnail(from: image, maxSize: maxSize)
    }
    
    /// 加载原图
    func loadOriginal(for attachment: CardAttachment) -> NSImage? {
        let fileURL = attachmentsDirectory.appendingPathComponent(attachment.fileName)
        return NSImage(contentsOf: fileURL)
    }
    
    /// 获取文件 URL
    func fileURL(for attachment: CardAttachment) -> URL {
        attachmentsDirectory.appendingPathComponent(attachment.fileName)
    }
    
    // MARK: - Delete
    
    /// 删除附件文件
    func deleteAttachment(_ attachment: CardAttachment) {
        let fileURL = attachmentsDirectory.appendingPathComponent(attachment.fileName)
        try? FileManager.default.removeItem(at: fileURL)
        logger.info("🗑️ 删除附件: \(attachment.fileName)")
    }
    
    /// 批量删除附件
    func deleteAttachments(_ attachments: [CardAttachment]) {
        for attachment in attachments {
            deleteAttachment(attachment)
        }
    }
    
    // MARK: - Thumbnail Generation
    
    private func makeThumbnail(from image: NSImage, maxSize: CGFloat) -> NSImage {
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
}

// MARK: - Image Cache

/// 图片缓存（避免重复加载）
@MainActor
final class AttachmentImageCache {
    static let shared = AttachmentImageCache()
    
    private var thumbnailCache: [UUID: NSImage] = [:]
    private var originalCache: [UUID: NSImage] = [:]
    
    private init() {}
    
    /// 获取缩略图（带缓存）
    func thumbnail(for attachment: CardAttachment, maxSize: CGFloat = 200) -> NSImage? {
        if let cached = thumbnailCache[attachment.id] {
            return cached
        }
        
        if let image = CardAttachmentStorage.shared.loadThumbnail(for: attachment, maxSize: maxSize) {
            thumbnailCache[attachment.id] = image
            return image
        }
        
        return nil
    }
    
    /// 获取原图（带缓存）
    func original(for attachment: CardAttachment) -> NSImage? {
        if let cached = originalCache[attachment.id] {
            return cached
        }
        
        if let image = CardAttachmentStorage.shared.loadOriginal(for: attachment) {
            originalCache[attachment.id] = image
            return image
        }
        
        return nil
    }
    
    /// 清除指定附件的缓存
    func clearCache(for attachmentId: UUID) {
        thumbnailCache.removeValue(forKey: attachmentId)
        originalCache.removeValue(forKey: attachmentId)
    }
    
    /// 清除所有缓存
    func clearAll() {
        thumbnailCache.removeAll()
        originalCache.removeAll()
    }
}
