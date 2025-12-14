# 颜色系统

> 📍 来源: `@spoke/UI/HUD/HUDTheme.swift`, `@spoke/Core/Tags/CardTag.swift`

---

## 1. 全局文字颜色 (HUDTheme)

> 来源: `@spoke/UI/HUD/HUDTheme.swift:6-56`

| 名称 | SwiftUI | NSColor | 用途 |
|------|---------|---------|------|
| `textPrimary` | `Color.white.opacity(0.9)` | `NSColor.white.withAlphaComponent(0.9)` | 主文字、转录内容 |
| `textSecondary` | `Color.white.opacity(0.7)` | `NSColor.white.withAlphaComponent(0.7)` | 标签、提示文字 |
| `textPlaceholder` | `Color.white.opacity(0.4)` | `NSColor.white.withAlphaComponent(0.4)` | 占位符、时间戳 |

```swift
// SwiftUI 用法
Text("内容").foregroundColor(HUDTheme.textPrimary)

// AppKit 用法
textView.textColor = HUDTheme.NS.textPrimary
```

---

## 2. 背景颜色 (HUDTheme)

> 来源: `@spoke/UI/HUD/HUDTheme.swift:19-25`

| 名称 | 值 | 用途 |
|------|-----|------|
| `cardBackground` | `Color.white.opacity(0.1)` | 卡片/缩略图背景 |
| `overlayDark` | `Color.black.opacity(0.3)` | 深色叠加层 |

---

## 3. 边框颜色 (HUDTheme)

> 来源: `@spoke/UI/HUD/HUDTheme.swift:27-33`

| 名称 | 值 | 用途 |
|------|-----|------|
| `borderPrimary` | `Color.white.opacity(0.1)` | 主边框 |
| `borderSecondary` | `Color.white.opacity(0.2)` | 缩略图边框 |

---

## 4. 高光/特效 (HUDTheme)

> 来源: `@spoke/UI/HUD/HUDTheme.swift:35-42`

| 名称 | 值 | 用途 |
|------|-----|------|
| `glowTop` | `Color.white.opacity(0.08)` | 顶部渐变高光 |
| `accentBright` | `Color.white.opacity(0.9)` | 跑马灯亮色 |
| `accentDim` | `Color.white.opacity(0.05)` | 跑马灯暗色 |

---

## 5. 标签调色板 (TagColor)

> 来源: `@spoke/Core/Tags/CardTag.swift:6-51`

9 种预设颜色，用于标签气泡：

```swift
enum TagColor: String, Codable, CaseIterable {
    case gray   // Color(white: 0.5)
    case red    // Color(red: 0.85, green: 0.3, blue: 0.3)
    case orange // Color(red: 0.9, green: 0.55, blue: 0.25)
    case yellow // Color(red: 0.85, green: 0.75, blue: 0.3)
    case green  // Color(red: 0.35, green: 0.7, blue: 0.45)
    case teal   // Color(red: 0.3, green: 0.65, blue: 0.7)
    case blue   // Color(red: 0.35, green: 0.5, blue: 0.85)
    case purple // Color(red: 0.6, green: 0.4, blue: 0.8)
    case pink   // Color(red: 0.85, green: 0.45, blue: 0.55)
}
```

**用法**：
```swift
tag.color.color  // 获取 SwiftUI Color
TagColor.random() // 随机颜色
```

---

## 6. 字幕卡片颜色 (CaptionDesign)

> 来源: `@spoke/UI/LiveCaption/LiveCaptionView.swift:248-259`

| 名称 | 值 | 用途 |
|------|-----|------|
| `cardBackground` | `Color(27/255, 28/255, 30/255).opacity(0.7)` | 字幕卡片背景 |
| `borderColor` | `Color.white.opacity(0.05)` | 字幕卡片边框 |
| `textPrimary` | `Color(249/255, 250/255, 251/255)` | 原文（#f9fafb） |
| `textSecondary` | `Color(156/255, 163/255, 175/255)` | 译文（#9ca3af） |
| `dragIndicatorColor` | `Color.white.opacity(0.2)` | 拖动指示器 |

---

## 7. 工具栏颜色 (ToolbarColors)

> 来源: `@spoke/UI/SelectionToolbar/SelectionToolbarView.swift:5-14`

| 名称 | 值 | 用途 |
|------|-----|------|
| `background` | `Color(hex: "1F1F1F")` | 工具栏背景 |
| `border` | `Color.white.opacity(0.1)` | 边框 |
| `buttonHover` | `Color.white.opacity(0.1)` | 按钮 Hover |
| `buttonActive` | `Color.white.opacity(0.2)` | 按钮激活 |
| `separator` | `Color.white.opacity(0.15)` | 分隔线 |
| `text` | `Color.white.opacity(0.95)` | 文字 |
| `textSecondary` | `Color.white.opacity(0.6)` | 次要文字 |
| `icon` | `Color.white.opacity(0.85)` | 图标 |

---

## 8. 状态颜色

### 录音状态
```swift
Color.red          // 录音中晕染
Color.blue         // 完成按钮
Color.red          // 取消按钮
Color.green        // 成功对勾
```

### 过滤器按钮
```swift
Color.orange  // Todo 筛选
Color.blue    // Note 筛选
```
