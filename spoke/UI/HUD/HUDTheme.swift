import SwiftUI
import AppKit

/// HUD 全局主题
/// 集中管理所有 HUD 组件的颜色和样式
enum HUDTheme {
    
    // MARK: - 文字颜色
    
    /// 主文字颜色（转录文字、输入文字等）
    static let textPrimary = Color.white.opacity(0.9)
    
    /// 次要文字颜色（标签、提示等）
    static let textSecondary = Color.white.opacity(0.7)
    
    /// 占位符颜色
    static let textPlaceholder = Color.white.opacity(0.4)
    
    // MARK: - 背景颜色
    
    /// 卡片/缩略图背景
    static let cardBackground = Color.white.opacity(0.1)
    
    /// 深色叠加层
    static let overlayDark = Color.black.opacity(0.3)
    
    // MARK: - 边框颜色
    
    /// 主边框
    static let borderPrimary = Color.white.opacity(0.1)
    
    /// 次要边框（缩略图等）
    static let borderSecondary = Color.white.opacity(0.2)
    
    // MARK: - 高光/特效
    
    /// 顶部渐变高光起始
    static let glowTop = Color.white.opacity(0.08)
    
    /// 强调色（跑马灯等）
    static let accentBright = Color.white.opacity(0.9)
    static let accentDim = Color.white.opacity(0.05)
    
    // MARK: - NSColor 版本（用于 AppKit）
    
    enum NS {
        /// 主文字颜色
        static let textPrimary = NSColor.white.withAlphaComponent(0.9)
        
        /// 占位符颜色
        static let textPlaceholder = NSColor.white.withAlphaComponent(0.4)
    }
}
