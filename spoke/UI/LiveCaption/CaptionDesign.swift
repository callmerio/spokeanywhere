import SwiftUI

private typealias DS = DesignTokens

// MARK: - Design Constants

/// 字幕卡片设计常量 - 参考 Tailwind CSS 设计系统
enum CaptionDesign {
    // MARK: - Colors
    /// 卡片背景色 - rgba(27, 28, 30, 0.7)
    static let cardBackground = DS.Colors.captionCardBackground
    /// 边框颜色 - rgba(255, 255, 255, 0.05)
    static let borderColor = DS.Colors.borderCaption
    /// 主文本色 - #f9fafb
    static let textPrimary = DS.Colors.textCaption
    /// 次要文本色 - #9ca3af (译文)
    static let textSecondary = DS.Colors.textTranslation
    /// 拖动指示器颜色 - white/20
    static let dragIndicatorColor = DS.Colors.dragIndicator
    
    // MARK: - Dimensions
    /// 卡片最大宽度 - max-w-2xl ≈ 672px
    static let maxWidth: CGFloat = DS.Layout.captionMaxWidth
    /// 折叠状态内容区高度（2行英文 + 2行译文 + 间距）
    static let collapsedContentHeight: CGFloat = DS.Layout.captionCollapsedHeight
    /// 圆角 - rounded-xl = 1.25rem ≈ 20pt
    static let cornerRadius: CGFloat = DS.CornerRadius.xxl
    /// 内边距 - p-6 = 1.5rem ≈ 24pt
    static let padding: CGFloat = DS.Spacing.xxl
    /// 字体大小 - text-lg ≈ 18pt
    static let fontSize: CGFloat = DS.Typography.fontSizeBody
    /// 译文字体大小
    static let translatedFontSize: CGFloat = DS.Typography.fontSizeBodySecondary
    /// 行间距 - space-y-1 ≈ 4pt
    static let lineSpacing: CGFloat = DS.LineSpacing.normal
    /// 毛玻璃模糊半径 - blur(20px)
    static let blurRadius: CGFloat = DS.Layout.blurRadius
    /// 阴影半径 - shadow-2xl
    static let shadowRadius: CGFloat = DS.Shadow.caption.radius
    /// 拖动指示器宽度 - w-8 = 32pt
    static let dragIndicatorWidth: CGFloat = DS.Layout.dragIndicatorSize.width
    /// 拖动指示器高度 - h-1 = 4pt
    static let dragIndicatorHeight: CGFloat = DS.Layout.dragIndicatorSize.height
    
    // MARK: - Scroll
    /// 底部检测容差（容忍布局误差）
    static let scrollBottomThreshold: CGFloat = 50
    /// 追加滚动检测阈值（越小越灵敏）
    static let scrollCatchUpThreshold: CGFloat = 5
    /// 滚动额外偏移量（确保底部内容完全露出）
    static let scrollExtraOffset: CGFloat = 8
    /// 内容底部占位高度
    static let contentBottomPadding: CGFloat = 0
    /// 展开模式底部占位
    static let expandedBottomPadding: CGFloat = 8
    
    // MARK: - Glow Effect (Hover)
    /// 光晕预留空间（每侧），用于阴影/光晕扩散
    static let glowPadding: CGFloat = 25
    /// Hover 光晕半径（微弱效果）
    static let glowRadius: CGFloat = 8
    /// Hover 光晕颜色（白色，微弱）
    static let glowColor = Color.white.opacity(0.25)
    /// Hover 边框颜色（白色，微弱）
    static let glowBorderColor = Color.white.opacity(0.18)
    /// Hover 边框宽度
    static let glowBorderWidth: CGFloat = 1
}
