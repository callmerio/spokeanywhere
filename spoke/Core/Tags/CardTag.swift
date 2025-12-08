import SwiftUI

// MARK: - Tag Color Palette

/// 预设标签颜色调色板（8色）
enum TagColor: String, Codable, CaseIterable {
    case gray
    case red
    case orange
    case yellow
    case green
    case teal
    case blue
    case purple
    case pink
    
    /// SwiftUI Color
    var color: Color {
        switch self {
        case .gray: return Color(white: 0.5)
        case .red: return Color(red: 0.85, green: 0.3, blue: 0.3)
        case .orange: return Color(red: 0.9, green: 0.55, blue: 0.25)
        case .yellow: return Color(red: 0.85, green: 0.75, blue: 0.3)
        case .green: return Color(red: 0.35, green: 0.7, blue: 0.45)
        case .teal: return Color(red: 0.3, green: 0.65, blue: 0.7)
        case .blue: return Color(red: 0.35, green: 0.5, blue: 0.85)
        case .purple: return Color(red: 0.6, green: 0.4, blue: 0.8)
        case .pink: return Color(red: 0.85, green: 0.45, blue: 0.55)
        }
    }
    
    /// 随机选择一个颜色
    static func random() -> TagColor {
        allCases.randomElement() ?? .gray
    }
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .gray: return "灰色"
        case .red: return "红色"
        case .orange: return "橙色"
        case .yellow: return "黄色"
        case .green: return "绿色"
        case .teal: return "青色"
        case .blue: return "蓝色"
        case .purple: return "紫色"
        case .pink: return "粉色"
        }
    }
}

// MARK: - Card Tag

/// 卡片标签
struct CardTag: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var color: TagColor
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, color: TagColor? = nil, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.color = color ?? TagColor.random()
        self.createdAt = createdAt
    }
    
    /// 快速创建（随机颜色）
    static func create(_ name: String) -> CardTag {
        CardTag(name: name)
    }
}

// MARK: - Tag Reference

/// 卡片中的标签引用（只存储 id，通过 TagLibrary 获取完整信息）
struct TagReference: Codable, Equatable, Hashable {
    let tagId: UUID
}
