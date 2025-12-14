import SwiftUI
import AppKit

// MARK: - Design Tokens
// 统一的设计系统入口，所有样式定义的唯一真相来源
// 禁止在组件中硬编码 Color.white.opacity() / cornerRadius 等魔数

enum DesignTokens {
    
    // MARK: - Colors
    enum Colors {
        
        // MARK: Text
        /// 主文字颜色（转录文字、内容文字）
        static let textPrimary = Color.white.opacity(0.9)
        /// 次要文字颜色（标签、提示）
        static let textSecondary = Color.white.opacity(0.7)
        /// 占位符颜色（时间戳、hint）
        static let textPlaceholder = Color.white.opacity(0.4)
        /// 字幕原文（高亮白）
        static let textCaption = Color(red: 249/255, green: 250/255, blue: 251/255)
        /// 字幕译文（灰色）
        static let textTranslation = Color(red: 156/255, green: 163/255, blue: 175/255)
        
        // MARK: Background
        /// 卡片/缩略图背景
        static let cardBackground = Color.white.opacity(0.1)
        /// 深色叠加层
        static let overlayDark = Color.black.opacity(0.3)
        /// 字幕卡片背景
        static let captionCardBackground = Color(red: 27/255, green: 28/255, blue: 30/255).opacity(0.7)
        /// 工具栏背景
        static let toolbarBackground = Color(red: 31/255, green: 31/255, blue: 31/255)  // #1F1F1F
        
        // MARK: Settings 专用
        /// 设置页面背景 #1a1a1a
        static let settingsBackground = Color(red: 26/255, green: 26/255, blue: 26/255)
        /// 设置侧边栏背景 #141414
        static let settingsSidebarBackground = Color(red: 20/255, green: 20/255, blue: 20/255)
        /// 设置卡片背景 #252525
        static let settingsCardBackground = Color(red: 37/255, green: 37/255, blue: 37/255)
        /// 设置卡片边框
        static let settingsCardBorder = Color.white.opacity(0.06)
        
        // MARK: Border
        /// 主边框
        static let borderPrimary = Color.white.opacity(0.1)
        /// 次要边框（缩略图等）
        static let borderSecondary = Color.white.opacity(0.2)
        /// 字幕卡片边框
        static let borderCaption = Color.white.opacity(0.05)
        /// 分隔线
        static let separator = Color.white.opacity(0.15)
        
        // MARK: Interactive
        /// 按钮 Hover
        static let buttonHover = Color.white.opacity(0.1)
        /// 按钮激活
        static let buttonActive = Color.white.opacity(0.2)
        /// 拖动指示器
        static let dragIndicator = Color.white.opacity(0.2)
        
        // MARK: Accent
        /// 顶部渐变高光
        static let glowTop = Color.white.opacity(0.08)
        /// 跑马灯亮色
        static let accentBright = Color.white.opacity(0.9)
        /// 跑马灯暗色
        static let accentDim = Color.white.opacity(0.05)
        
        // MARK: Status
        /// 录音中晕染
        static let recordingGlow = Color.red
        /// 成功状态
        static let success = Color.green
        /// 警告状态
        static let warning = Color.orange
        /// 错误状态
        static let error = Color.red
        
        // MARK: Icon
        /// 图标颜色
        static let icon = Color.white.opacity(0.85)
    }
    
    // MARK: - Corner Radius
    enum CornerRadius {
        /// 微型元素（4pt）
        static let xs: CGFloat = 4
        /// 按钮（6pt）
        static let sm: CGFloat = 6
        /// 工具栏（10pt）
        static let md: CGFloat = 10
        /// 卡片（14pt）
        static let lg: CGFloat = 14
        /// 面板/HUD（16pt）
        static let xl: CGFloat = 16
        /// 字幕卡片（20pt）
        static let xxl: CGFloat = 20
    }
    
    // MARK: - Spacing
    enum Spacing {
        /// 最小间距（2pt）
        static let xxs: CGFloat = 2
        /// 紧凑间距（4pt）
        static let xs: CGFloat = 4
        /// 小间距（6pt）
        static let sm: CGFloat = 6
        /// 标准间距（8pt）
        static let md: CGFloat = 8
        /// 大间距（12pt）
        static let lg: CGFloat = 12
        /// 超大间距（16pt）
        static let xl: CGFloat = 16
        /// 内边距（24pt）- 用于卡片内部
        static let xxl: CGFloat = 24
    }
    
    // MARK: - Typography
    enum Typography {
        /// 大标题（20pt bold）
        static let titleLarge: Font = .system(size: 20, weight: .bold)
        /// 标题（17pt semibold）
        static let title: Font = .system(size: 17, weight: .semibold)
        /// 正文/字幕原文（18pt）
        static let body: Font = .system(size: 18, weight: .regular)
        /// 字幕译文（16pt）
        static let bodySecondary: Font = .system(size: 16, weight: .regular)
        /// 内容文字（14pt）
        static let content: Font = .system(size: 14, weight: .regular)
        /// 按钮/标签（13pt）
        static let button: Font = .system(size: 13, weight: .regular)
        /// 小标签（12pt medium）
        static let caption: Font = .system(size: 12, weight: .medium)
        /// 微型文字（11pt medium）
        static let captionSmall: Font = .system(size: 11, weight: .medium)
        /// 时间戳（10pt）
        static let timestamp: Font = .system(size: 10, weight: .regular)
        
        // MARK: Font Sizes (用于需要数值的场景)
        static let fontSizeTitleLarge: CGFloat = 20
        static let fontSizeTitle: CGFloat = 17
        static let fontSizeBody: CGFloat = 18
        static let fontSizeBodySecondary: CGFloat = 16
        static let fontSizeContent: CGFloat = 14
        static let fontSizeButton: CGFloat = 13
        static let fontSizeCaption: CGFloat = 12
        static let fontSizeCaptionSmall: CGFloat = 11
        static let fontSizeTimestamp: CGFloat = 10
    }
    
    // MARK: - Animation
    enum Animation {
        /// 快速动画（150ms）- Hover
        static let fast: SwiftUI.Animation = .easeInOut(duration: 0.15)
        /// 标准动画（200ms）- 状态切换
        static let normal: SwiftUI.Animation = .easeInOut(duration: 0.2)
        /// 慢速动画（300ms）- 展开/折叠
        static let slow: SwiftUI.Animation = .easeInOut(duration: 0.3)
        /// 弹性动画 - 卡片展开
        static let spring: SwiftUI.Animation = .spring(response: 0.3)
        /// 弹性动画（强） - 成功反馈
        static let springBouncy: SwiftUI.Animation = .spring(response: 0.4, dampingFraction: 0.6)
        
        // MARK: Duration (用于需要数值的场景)
        static let durationFast: Double = 0.15
        static let durationNormal: Double = 0.2
        static let durationSlow: Double = 0.3
    }
    
    // MARK: - Shadow
    enum Shadow {
        /// 贴边阴影
        static func tight(_ opacity: Double = 0.08) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (Color.black.opacity(opacity), 1, 0, 0.5)
        }
        /// 中层阴影
        static func medium(_ opacity: Double = 0.12) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (Color.black.opacity(opacity), 6, 0, 3)
        }
        /// 远层阴影
        static func far(_ opacity: Double = 0.08) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (Color.black.opacity(opacity), 20, 0, 8)
        }
        /// 字幕卡片阴影
        static let caption: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = 
            (Color.black.opacity(0.4), 25, 0, 10)
    }
    
    // MARK: - Layout
    enum Layout {
        /// 字幕卡片最大宽度
        static let captionMaxWidth: CGFloat = 672
        /// 字幕折叠高度
        static let captionCollapsedHeight: CGFloat = 100
        /// 工具栏高度
        static let toolbarHeight: CGFloat = 40
        /// 工具栏按钮高度
        static let toolbarButtonHeight: CGFloat = 32
        /// 图标尺寸（工具栏）
        static let iconSizeToolbar: CGFloat = 15
        /// 图标尺寸（标准）
        static let iconSizeStandard: CGFloat = 20
        /// 图标尺寸（大）
        static let iconSizeLarge: CGFloat = 24
        /// 毛玻璃模糊半径
        static let blurRadius: CGFloat = 20
        /// 拖动指示器尺寸
        static let dragIndicatorSize: (width: CGFloat, height: CGFloat) = (32, 4)
    }
    
    // MARK: - Line Spacing
    enum LineSpacing {
        /// 紧凑行距
        static let tight: CGFloat = 3
        /// 标准行距
        static let normal: CGFloat = 4
        /// 宽松行距
        static let relaxed: CGFloat = 6
    }
}

// MARK: - NSColor 版本（用于 AppKit）
extension DesignTokens.Colors {
    enum NS {
        static let textPrimary = NSColor.white.withAlphaComponent(0.9)
        static let textSecondary = NSColor.white.withAlphaComponent(0.7)
        static let textPlaceholder = NSColor.white.withAlphaComponent(0.4)
        static let cardBackground = NSColor.white.withAlphaComponent(0.1)
        static let borderPrimary = NSColor.white.withAlphaComponent(0.1)
    }
}

// MARK: - 向后兼容 HUDTheme
// 保留旧 API，逐步迁移后可删除
@available(*, deprecated, message: "Use DesignTokens.Colors instead")
typealias HUDThemeCompat = DesignTokens.Colors
