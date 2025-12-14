# 字体系统

> 📍 来源: 项目全局 SwiftUI 视图

---

## 1. 字号规范

| 场景 | 字号 | 字重 | 示例来源 |
|------|------|------|----------|
| **大标题** | 20pt | `.bold` | Pipeline 标题 |
| **正文/字幕** | 18pt | `.regular` | 字幕原文 |
| **内容文字** | 14-15pt | `.regular/.medium` | 卡片内容、按钮 |
| **标签/工具栏** | 13pt | `.regular` | 工具栏文字 |
| **辅助文字** | 11-12pt | `.medium` | 时间戳、标签 |
| **微型文字** | 9-10pt | `.medium` | 元数据、提示 |

---

## 2. 字体定义示例

### MessagePanelView 头部标题
> 来源: `@spoke/UI/MessagePanel/MessagePanelView.swift:174-176`

```swift
Text("Pipeline")
    .font(.system(size: 20, weight: .bold))
    .foregroundColor(.white)
```

### 字幕文字
> 来源: `@spoke/UI/LiveCaption/LiveCaptionView.swift:437-439`

```swift
Text(pendingText)
    .font(.system(size: CaptionDesign.fontSize, weight: .regular))  // 18pt
    .foregroundColor(CaptionDesign.textPrimary)
    .lineSpacing(4)
```

### 译文
> 来源: `@spoke/UI/LiveCaption/LiveCaptionView.swift:443-448`

```swift
Text(translation)
    .font(.system(size: CaptionDesign.translatedFontSize, weight: .regular))  // 16pt
    .foregroundColor(CaptionDesign.textSecondary)
    .lineSpacing(3)
```

### 卡片内容
> 来源: `@spoke/UI/MessagePanel/MessagePanelView.swift:801-802`

```swift
Text(displayText)
    .font(.system(size: 13))
    .foregroundColor(HUDTheme.textPrimary)
```

### 标签气泡
> 来源: `@spoke/UI/Components/TagBubbleView.swift:30-32`

```swift
Text(tag.name)
    .font(.system(size: 11, weight: .medium))
    .foregroundColor(tag.color.color)
```

### 时间戳
> 来源: `@spoke/UI/MessagePanel/MessagePanelView.swift:720-722`

```swift
Text(card.formattedTime)
    .font(.system(size: 10))
    .foregroundColor(HUDTheme.textPlaceholder)
```

---

## 3. 行间距规范

| 场景 | 行间距 | 示例 |
|------|--------|------|
| 字幕原文 | 4pt | `lineSpacing(4)` |
| 译文 | 3pt | `lineSpacing(3)` |
| 段落文字 | 6pt | `lineSpacing(6)` |

---

## 4. 设计约束

- **系统字体优先**：全部使用 `.system()` 字体
- **禁止自定义字体**：保持 macOS 原生一致性
- **字重阶梯**：`.regular` → `.medium` → `.bold`
- **等宽设计**：快捷键使用 `.design(.rounded)` 或 `.monospaced`

```swift
// 快捷键提示
Text("⌥T")
    .font(.system(size: 11, weight: .medium, design: .rounded))
```
