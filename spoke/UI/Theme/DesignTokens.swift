import AppKit
import SwiftUI

// MARK: - Design Tokens
// 统一的设计系统入口，所有样式定义的唯一真相来源
// 禁止在组件中硬编码白色透明层 / cornerRadius 等魔数

enum DesignTokens {
    
    // MARK: - Colors
    enum Colors {
        
        // MARK: Text
        /// 主文字颜色（转录文字、内容文字）
        static let textPrimary = Color(nsColor: NSColor.white.withAlphaComponent(0.9))
        /// 次要文字颜色（标签、提示）
        static let textSecondary = Color(nsColor: NSColor.white.withAlphaComponent(0.7))
        /// 占位符颜色（时间戳、hint）
        static let textPlaceholder = Color(nsColor: NSColor.white.withAlphaComponent(0.4))
        /// 字幕原文（高亮白）
        static let textCaption = Color(red: 249 / 255, green: 250 / 255, blue: 251 / 255)
        /// 字幕译文（灰色）
        static let textTranslation = Color(red: 156 / 255, green: 163 / 255, blue: 175 / 255)
        
        // MARK: Background
        /// 透明色（占位/无填充）
        static let clear = Color.clear
        /// 卡片/缩略图背景
        static let cardBackground = Color(nsColor: NSColor.white.withAlphaComponent(0.1))
        /// 深色叠加层
        static let overlayDark = Color.black.opacity(0.3)
        /// 深色叠加层（浅）
        static let overlayLight = Color.black.opacity(0.4)
        /// 深色叠加层（中）
        static let overlayMedium = Color.black.opacity(0.6)
        /// 深色叠加层（强）
        static let overlayStrong = Color.black.opacity(0.8)
        /// PinnedText 背景（#222）
        static let pinnedTextBackground = Color(red: 34 / 255, green: 34 / 255, blue: 34 / 255)
        /// PinnedText 前景（#DCCEA9）
        static let pinnedTextForeground = Color(red: 220 / 255, green: 206 / 255, blue: 169 / 255)
        /// 字幕卡片背景
        static let captionCardBackground = Color(red: 27 / 255, green: 28 / 255, blue: 30 / 255).opacity(0.7)
        /// 工具栏背景
        static let toolbarBackground = Color(red: 31 / 255, green: 31 / 255, blue: 31 / 255)  // #1F1F1F
        /// 输入框系统背景
        static let textFieldBackground = Color(NSColor.textBackgroundColor)
        /// Chip 背景
        static let chipBackground = Color(nsColor: NSColor.white.withAlphaComponent(0.08))
        /// 训练短语卡片背景（默认）
        static let trainingCardBackground = Color(nsColor: NSColor.white.withAlphaComponent(0.03))
        /// 训练短语卡片背景（Hover）
        static let trainingCardBackgroundHover = Color(nsColor: NSColor.white.withAlphaComponent(0.08))
        /// 极浅表面背景
        static let surfaceThin = Color(nsColor: NSColor.white.withAlphaComponent(0.02))
        
        // MARK: Settings 专用
        /// 设置页面背景 #1a1a1a
        static let settingsBackground = Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255)
        /// 设置侧边栏背景 #141414
        static let settingsSidebarBackground = Color(red: 20 / 255, green: 20 / 255, blue: 20 / 255)
        /// 设置卡片背景 #252525
        static let settingsCardBackground = Color(red: 37 / 255, green: 37 / 255, blue: 37 / 255)
        /// 设置面板背景 #1e1e1e
        static let settingsPanelBackground = Color(red: 30 / 255, green: 30 / 255, blue: 30 / 255)
        /// 设置面板次级背景 #232323
        static let settingsPanelSecondary = Color(red: 35 / 255, green: 35 / 255, blue: 35 / 255)
        /// 设置工具条背景 #2a2a2a
        static let settingsToolbarBackground = Color(red: 42 / 255, green: 42 / 255, blue: 42 / 255)
        /// 设置卡片边框
        static let settingsCardBorder = Color(nsColor: NSColor.white.withAlphaComponent(0.06))
        /// 设置区域底色（提升层级）
        static let settingsSurfaceElevated = Color(white: 0.15)
        
        // MARK: Border
        /// 主边框
        static let borderPrimary = Color(nsColor: NSColor.white.withAlphaComponent(0.1))
        /// 次要边框（缩略图等）
        static let borderSecondary = Color(nsColor: NSColor.white.withAlphaComponent(0.2))
        /// 字幕卡片边框
        static let borderCaption = Color(nsColor: NSColor.white.withAlphaComponent(0.05))
        /// 分隔线
        static let separator = Color(nsColor: NSColor.white.withAlphaComponent(0.15))
        /// 分隔线（强调）
        static let separatorStrong = Color(nsColor: NSColor.white.withAlphaComponent(0.3))
        
        // MARK: Interactive
        /// 按钮 Hover
        static let buttonHover = Color(nsColor: NSColor.white.withAlphaComponent(0.1))
        /// 按钮 Hover（强化）
        static let buttonHoverStrong = Color(nsColor: NSColor.white.withAlphaComponent(0.15))
        /// 按钮激活
        static let buttonActive = Color(nsColor: NSColor.white.withAlphaComponent(0.2))
        /// 按钮按下
        static let buttonPressed = Color(nsColor: NSColor.white.withAlphaComponent(0.3))
        /// 拖动指示器
        static let dragIndicator = Color(nsColor: NSColor.white.withAlphaComponent(0.2))
        /// 行 Hover
        static let rowHover = Color(nsColor: NSColor.white.withAlphaComponent(0.05))
        /// 次级标签底色
        static let badgeBackground = Color.secondary.opacity(0.2)
        /// 输入控件边框
        static let fieldBorder = Color.secondary.opacity(0.3)
        /// 图标按钮底色
        static let iconButtonBackground = Color.secondary.opacity(0.2)
        
        // MARK: Accent
        /// 顶部渐变高光
        static let glowTop = Color(nsColor: NSColor.white.withAlphaComponent(0.08))
        /// 跑马灯亮色
        static let accentBright = Color(nsColor: NSColor.white.withAlphaComponent(0.9))
        /// 跑马灯暗色
        static let accentDim = Color(nsColor: NSColor.white.withAlphaComponent(0.05))
        /// 主强调色（遵循系统 Accent Color）
        static let accentPrimary = Color.accentColor
        /// 轻微高饱和渐变起点
        static let accentGradientStart = Color(red: 0.6, green: 0.8, blue: 1.0)
        /// 轻微高饱和渐变终点
        static let accentGradientEnd = Color(red: 1.0, green: 0.6, blue: 1.0)
        /// 渐变光晕
        static let accentGlow = Color(red: 0.7, green: 0.5, blue: 1.0)
        /// 蓝色强调（功能提示）
        static let accentInfo = Color(red: 90 / 255, green: 159 / 255, blue: 212 / 255)
        /// 紫色强调（运行/处理中）
        static let accentProcessing = Color(red: 167 / 255, green: 139 / 255, blue: 250 / 255)
        /// 错误强调（文本）
        static let accentDangerText = Color(red: 1.0, green: 107 / 255, blue: 107 / 255)
        /// 错误强调（背景）
        static let accentDangerBackground = Color(red: 1.0, green: 68 / 255, blue: 68 / 255)
        /// 训练短语高亮色
        static let highlightGold = Color(red: 0.84, green: 0.61, blue: 0)
        
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
        static let icon = Color(nsColor: NSColor.white.withAlphaComponent(0.85))
    }

    // MARK: - Gradients
    enum Gradients {
        /// 工具栏 Logo 渐变
        static let toolbarLogo = LinearGradient(
            colors: [Colors.accentGradientStart, Colors.accentGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        /// CTA 渐变（暖色）
        static let ctaWarm = LinearGradient(
            colors: [Colors.warning, Colors.warning.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
        /// 特大间距（40pt）
        static let xxxl: CGFloat = 40
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
        struct Token {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }

        struct LayerToken: Equatable {
            let color: NSColor
            let opacity: Float
            let radius: CGFloat
            let offset: CGSize
        }
        
        /// 贴边阴影
        static func tight(_ opacity: Double = 0.08) -> Token {
            Token(color: Color.black.opacity(opacity), radius: 1, x: 0, y: 0.5)
        }
        /// 中层阴影
        static func medium(_ opacity: Double = 0.12) -> Token {
            Token(color: Color.black.opacity(opacity), radius: 6, x: 0, y: 3)
        }
        /// 远层阴影
        static func far(_ opacity: Double = 0.08) -> Token {
            Token(color: Color.black.opacity(opacity), radius: 20, x: 0, y: 8)
        }
        /// 字幕卡片阴影（柔和阴影，融入背景）
        static let caption = Token(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 8)

        enum PinnedText {
            static let card = LayerToken(color: .black, opacity: 0, radius: 0, offset: .zero)
        }
    }

    // MARK: - Glow
    enum Glow {
        struct Style: Equatable {
            let lineWidth: CGFloat
            let shadowRadius: CGFloat
            let shadowOpacity: Float

            // Optional fill for layer-backed glow sources; screenshot-style glows use stroke instead.
            let fillOpacity: CGFloat

            init(
                lineWidth: CGFloat,
                shadowRadius: CGFloat,
                shadowOpacity: Float,
                fillOpacity: CGFloat = 0
            ) {
                self.lineWidth = lineWidth
                self.shadowRadius = shadowRadius
                self.shadowOpacity = shadowOpacity
                self.fillOpacity = fillOpacity
            }
        }

        enum ScreenshotCard {
            static let hover = Style(lineWidth: 1.5, shadowRadius: 10, shadowOpacity: 0.45)
            static let mark = Style(lineWidth: 1.5, shadowRadius: 12, shadowOpacity: 0.5)
            static let idle = Style(lineWidth: 1.5, shadowRadius: 10, shadowOpacity: 0.6)
        }

        enum OverlayContract {
            static let hover = ScreenshotCard.hover
            static let mark = ScreenshotCard.mark
            static let idle = ScreenshotCard.idle
        }

        enum PinnedText {
            static let hover = OverlayContract.hover
            static let mark = OverlayContract.mark
            static let idle = OverlayContract.idle
        }
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
        /// 图标尺寸（小）
        static let iconSizeSmall: CGFloat = 11
        /// 图标尺寸（中）
        static let iconSizeMedium: CGFloat = 16
        /// 图标尺寸（标准）
        static let iconSizeStandard: CGFloat = 20
        /// 图标尺寸（大）
        static let iconSizeLarge: CGFloat = 24
        /// 图标尺寸（特大）
        static let iconSizeXLarge: CGFloat = 32
        /// 图标底座尺寸
        static let iconBackdropSize: CGFloat = 40
        /// 毛玻璃模糊半径
        static let blurRadius: CGFloat = 20
        /// 拖动指示器尺寸
        static let dragIndicatorSize: (width: CGFloat, height: CGFloat) = (32, 4)
        /// 工具栏分隔线高度
        static let toolbarSeparatorHeight: CGFloat = 20
    }

    // MARK: - Border Width
    enum BorderWidth {
        /// 无描边
        static let none: CGFloat = 0
        /// 细线
        static let hairline: CGFloat = 0.5
        /// 标准线
        static let thin: CGFloat = 1
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
        static let clear = NSColor.clear
        static let inkLight = NSColor.white
        static let inkDark = NSColor.black
        static let inkMuted = NSColor.darkGray
        static let textPrimary = NSColor.white.withAlphaComponent(0.9)
        static let textSecondary = NSColor.white.withAlphaComponent(0.7)
        static let textPlaceholder = NSColor.white.withAlphaComponent(0.4)
        static let cardBackground = NSColor.white.withAlphaComponent(0.1)
        static let borderPrimary = NSColor.white.withAlphaComponent(0.1)
        static let separator = NSColor.white.withAlphaComponent(0.15)
        static let separatorStrong = NSColor.white.withAlphaComponent(0.3)
        static let buttonHover = NSColor.white.withAlphaComponent(0.1)
        static let buttonHoverStrong = NSColor.white.withAlphaComponent(0.15)
        static let buttonActive = NSColor.white.withAlphaComponent(0.2)
        static let buttonPressed = NSColor.white.withAlphaComponent(0.3)
        static let overlayDark = NSColor.black.withAlphaComponent(0.3)
        static let overlayLight = NSColor.black.withAlphaComponent(0.4)
        static let overlayBase = NSColor.black.withAlphaComponent(0.5)
        static let overlayMedium = NSColor.black.withAlphaComponent(0.6)
        static let overlayStrong = NSColor.black.withAlphaComponent(0.8)
        static let pinnedTextBackground = NSColor(
            red: 34 / 255,
            green: 34 / 255,
            blue: 34 / 255,
            alpha: 1.0
        )
        static let pinnedTextForeground = NSColor(
            red: 220 / 255,
            green: 206 / 255,
            blue: 169 / 255,
            alpha: 1.0
        )
        static let codeBackground = NSColor.white.withAlphaComponent(0.1)
        static let highlightGold = NSColor(red: 0.84, green: 0.61, blue: 0, alpha: 1.0)
        static let accentPrimary = NSColor.controlAccentColor
        static let accentInfo = NSColor(red: 90 / 255, green: 159 / 255, blue: 212 / 255, alpha: 1.0)
        static let warning = NSColor.systemOrange
        static let error = NSColor.systemRed
        static let selectionShadow = NSColor.black.withAlphaComponent(0.9)
        static let annotationPrimary = NSColor.systemRed
        static let annotationHighlight = NSColor.systemYellow
        static let annotationText = NSColor.white
        static let glowMarkStroke = NSColor(red: 0.95, green: 0.6, blue: 0.2, alpha: 0.4)
        static let glowMarkShadow = NSColor(red: 0.95, green: 0.55, blue: 0.2, alpha: 1.0)
        static let glowHoverStroke = NSColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 0.4)
        static let glowHoverShadow = NSColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1.0)
        static let glowIdle = NSColor.black
    }
}

// MARK: - 向后兼容 HUDTheme
// 保留旧 API，逐步迁移后可删除
@available(*, deprecated, message: "Use DesignTokens.Colors instead")
typealias HUDThemeCompat = DesignTokens.Colors
