import Foundation
import AppKit
import Observation

// MARK: - Screenshot Appearance

/// 截图窗口外观样式
enum ScreenshotAppearance: String, Codable, CaseIterable {
    case `default` = "default"
    case minimal = "minimal"
    case shadow = "shadow"
}

// MARK: - Screenshot Item

/// 截图项数据模型
/// 使用 class + @Observable 确保状态同步（参考 CaptionItem 模式）
@Observable
@MainActor
final class ScreenshotItem: Identifiable {
    
    // MARK: - Properties
    
    let id: UUID
    let createdAt: Date
    
    /// 图片文件路径（持久化存储）
    var imagePath: String
    
    /// 窗口位置尺寸
    var frame: CGRect
    
    /// 原始图片尺寸（用于保持宽高比）
    var originalSize: CGSize
    
    /// 是否已钉住（固定在当前 Space）
    var isPinned: Bool = false
    
    /// 是否已锁定（禁止拖拽/缩放）
    var isLocked: Bool = false
    
    /// 透明度 (0.0-1.0)
    var opacity: Double = 1.0
    
    /// 缩放级别
    var zoomLevel: Double = 1.0
    
    /// 外观样式
    var appearance: ScreenshotAppearance = .default
    
    // MARK: - Transient (不持久化)
    
    /// 缓存的图片（不持久化）
    var cachedImage: NSImage?
    
    // MARK: - Init
    
    init(
        id: UUID = UUID(),
        imagePath: String,
        frame: CGRect,
        originalSize: CGSize? = nil,
        isPinned: Bool = false,
        isLocked: Bool = false,
        opacity: Double = 1.0,
        zoomLevel: Double = 1.0,
        appearance: ScreenshotAppearance = .default,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.imagePath = imagePath
        self.frame = frame
        self.originalSize = originalSize ?? frame.size
        self.isPinned = isPinned
        self.isLocked = isLocked
        self.opacity = opacity
        self.zoomLevel = zoomLevel
        self.appearance = appearance
        self.createdAt = createdAt
    }
    
    // MARK: - Image Loading
    
    /// 加载图片（带缓存）
    func loadImage() -> NSImage? {
        if let cached = cachedImage {
            return cached
        }
        
        let url = URL(fileURLWithPath: imagePath)
        guard let image = NSImage(contentsOf: url) else {
            return nil
        }
        
        cachedImage = image
        return image
    }
    
    /// 清除缓存
    func clearCache() {
        cachedImage = nil
    }
}

// MARK: - Codable

extension ScreenshotItem: @preconcurrency Codable {
    
    enum CodingKeys: String, CodingKey {
        case id, imagePath, frame, originalSize, isPinned, isLocked
        case opacity, zoomLevel, appearance, createdAt
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let id = try container.decode(UUID.self, forKey: .id)
        let imagePath = try container.decode(String.self, forKey: .imagePath)
        let frame = try container.decode(CGRect.self, forKey: .frame)
        let originalSize = try container.decodeIfPresent(CGSize.self, forKey: .originalSize)
        let isPinned = try container.decode(Bool.self, forKey: .isPinned)
        let isLocked = try container.decode(Bool.self, forKey: .isLocked)
        let opacity = try container.decode(Double.self, forKey: .opacity)
        let zoomLevel = try container.decode(Double.self, forKey: .zoomLevel)
        let appearance = try container.decode(ScreenshotAppearance.self, forKey: .appearance)
        let createdAt = try container.decode(Date.self, forKey: .createdAt)
        
        self.init(
            id: id,
            imagePath: imagePath,
            frame: frame,
            originalSize: originalSize,
            isPinned: isPinned,
            isLocked: isLocked,
            opacity: opacity,
            zoomLevel: zoomLevel,
            appearance: appearance,
            createdAt: createdAt
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(imagePath, forKey: .imagePath)
        try container.encode(frame, forKey: .frame)
        try container.encode(originalSize, forKey: .originalSize)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(isLocked, forKey: .isLocked)
        try container.encode(opacity, forKey: .opacity)
        try container.encode(zoomLevel, forKey: .zoomLevel)
        try container.encode(appearance, forKey: .appearance)
        try container.encode(createdAt, forKey: .createdAt)
    }
}
