import AppKit
import SwiftUI

/// HUD 全局主题
/// ⚠️ 已迁移到 DesignTokens，此文件保留向后兼容
/// 新代码请直接使用 DesignTokens.Colors / DesignTokens.CornerRadius 等
@available(*, deprecated, message: "Use DesignTokens instead")
enum HUDTheme {
    
    // MARK: - 文字颜色 (委托到 DesignTokens)
    
    static let textPrimary = DesignTokens.Colors.textPrimary
    static let textSecondary = DesignTokens.Colors.textSecondary
    static let textPlaceholder = DesignTokens.Colors.textPlaceholder
    
    // MARK: - 背景颜色
    
    static let cardBackground = DesignTokens.Colors.cardBackground
    static let overlayDark = DesignTokens.Colors.overlayDark
    
    // MARK: - 边框颜色
    
    static let borderPrimary = DesignTokens.Colors.borderPrimary
    static let borderSecondary = DesignTokens.Colors.borderSecondary
    
    // MARK: - 高光/特效
    
    static let glowTop = DesignTokens.Colors.glowTop
    static let accentBright = DesignTokens.Colors.accentBright
    static let accentDim = DesignTokens.Colors.accentDim
    
    // MARK: - NSColor 版本（用于 AppKit）
    
    enum NS {
        static let textPrimary = DesignTokens.Colors.NS.textPrimary
        static let textSecondary = DesignTokens.Colors.NS.textSecondary
        static let textPlaceholder = DesignTokens.Colors.NS.textPlaceholder
    }
}
