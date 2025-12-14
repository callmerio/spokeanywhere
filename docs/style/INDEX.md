# SpokenAnyWhere 设计体系

> 📍 最后更新: 2024-12-14
> 📁 路径: `docs/style/`

## ⚠️ 唯一真相来源

**所有样式定义必须使用 `DesignTokens`，禁止硬编码！**

```swift
// ✅ 正确
.foregroundColor(DesignTokens.Colors.textPrimary)
.cornerRadius(DesignTokens.CornerRadius.lg)

// ❌ 禁止
.foregroundColor(Color.white.opacity(0.9))
.cornerRadius(14)
```

---

## 设计原则

1. **深色优先** - 所有 UI 基于深色主题，适配 HUD 风格
2. **毛玻璃质感** - 使用 `NSVisualEffectView` 实现原生模糊效果
3. **高对比度文字** - 白色系文字 + 透明度层级
4. **微动效** - 轻量 easeInOut 动画，避免干扰用户

---

## 文档索引

| 文档 | 说明 |
|------|------|
| [colors.md](./colors.md) | 颜色系统（主题色、文字色、背景色） |
| [typography.md](./typography.md) | 字体系统（字号、字重、行高） |
| [components.md](./components.md) | 组件样式（按钮、卡片、标签） |
| [animations.md](./animations.md) | 动画系统（过渡、交互反馈） |
| [layouts.md](./layouts.md) | 布局常量（圆角、间距、尺寸） |

---

## 核心主题文件

```
┌─────────────────────────────────────────────────────────────────┐
│  主题定义文件                                                      │
├─────────────────────────────────────────────────────────────────┤
│  @spoke/UI/Theme/DesignTokens.swift  → ⭐ 唯一真相来源            │
│  @spoke/UI/HUD/HUDTheme.swift        → [deprecated] 向后兼容     │
│  @spoke/Core/Tags/CardTag.swift      → 标签颜色调色板              │
└─────────────────────────────────────────────────────────────────┘
```

---

## 快速参考

### 文字颜色

```swift
DesignTokens.Colors.textPrimary     // white/0.9  主文字
DesignTokens.Colors.textSecondary   // white/0.7  次要文字
DesignTokens.Colors.textPlaceholder // white/0.4  占位符
DesignTokens.Colors.textCaption     // #f9fafb    字幕原文
DesignTokens.Colors.textTranslation // #9ca3af    字幕译文
```

### 标签颜色

```swift
TagColor.allCases  // gray, red, orange, yellow, green, teal, blue, purple, pink
```

### 圆角

```swift
DesignTokens.CornerRadius.xs   //  4pt - 微型元素
DesignTokens.CornerRadius.sm   //  6pt - 按钮
DesignTokens.CornerRadius.md   // 10pt - 工具栏
DesignTokens.CornerRadius.lg   // 14pt - 卡片
DesignTokens.CornerRadius.xl   // 16pt - 面板
DesignTokens.CornerRadius.xxl  // 20pt - 字幕卡片
```

### 间距

```swift
DesignTokens.Spacing.xs   //  4pt - 紧凑
DesignTokens.Spacing.sm   //  6pt - 小间距
DesignTokens.Spacing.md   //  8pt - 标准
DesignTokens.Spacing.lg   // 12pt - 大间距
DesignTokens.Spacing.xl   // 16pt - 超大
DesignTokens.Spacing.xxl  // 24pt - 内边距
```

### 动画

```swift
DesignTokens.Animation.fast   // 150ms - Hover
DesignTokens.Animation.normal // 200ms - 状态切换
DesignTokens.Animation.slow   // 300ms - 展开/折叠
DesignTokens.Animation.spring // 弹性展开
```
