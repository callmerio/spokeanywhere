# 布局常量

> 📍 来源: 项目全局布局定义

---

## 1. 圆角规范

| 尺寸 | 值 | 用途 | 示例来源 |
|------|-----|------|----------|
| **XL** | 20pt | 字幕卡片 | `CaptionDesign.cornerRadius` |
| **L** | 16pt | 面板、HUD | `FloatingCapsuleView` |
| **M** | 14pt | 消息卡片 | `MessageCardView` |
| **S** | 10pt | 工具栏 | `ToolbarLayout.cornerRadius` |
| **XS** | 6pt | 按钮、圆角矩形 | `ToolbarLayout.buttonCornerRadius` |
| **Pill** | `height/2` | 胶囊形状 | 标签气泡 |

---

## 2. 间距规范

### 内边距 (Padding)

| 场景 | 值 | 示例 |
|------|-----|------|
| 面板整体 | 12pt | `MessagePanelView.padding(12)` |
| 字幕卡片 | 24pt | `CaptionDesign.padding` |
| 卡片内容 | 14pt | `MessageCardView.padding(14)` |
| 标签气泡 | H:8 / V:4 | `TagBubbleView` |
| 工具栏 | H:8pt | `SelectionToolbarView` |

### 组件间距 (Spacing)

| 场景 | 值 | 示例 |
|------|-----|------|
| 卡片列表 | 12-16pt | `LazyVStack(spacing: 12)` |
| 头部元素 | 8-12pt | `HStack(spacing: 12)` |
| 工具栏按钮 | 2pt | `ToolbarLayout.spacing` |
| 标签列表 | 6pt | `FlowLayout(spacing: 6)` |
| 行内元素 | 4-8pt | `HStack(spacing: 8)` |

---

## 3. 尺寸规范

### 面板宽度

| 组件 | 宽度 | 来源 |
|------|------|------|
| MessagePanel | 由 `MessagePanelState.panelWidth` 定义 | MessagePanelView |
| 字幕卡片 | 672pt | `CaptionDesign.maxWidth` |
| 添加标签弹窗 | 220pt | `AddTagPopover` |

### 固定高度

| 组件 | 高度 | 来源 |
|------|------|------|
| 工具栏 | 40pt | `ToolbarLayout.height` |
| 控制栏 | 44pt | `FloatingCapsuleView.controlBar` |
| 字幕折叠 | 250pt | `collapsedContentHeight * 2.5` |
| 字幕展开 | 400pt | `expandedContent.frame(height:)` |

### 图标尺寸

| 场景 | 尺寸 | 示例 |
|------|------|------|
| 工具栏图标 | 15pt | `ToolbarLayout.iconSize` |
| 应用图标 | 24pt | `appIcon.frame(width: 24)` |
| 关闭按钮 | 20pt | `HoverCloseButton.frame` |
| 操作按钮 | 10pt | `cardActionButton.font(.size: 10)` |

---

## 4. 字幕设计常量 (CaptionDesign)

> 来源: `@spoke/UI/LiveCaption/LiveCaptionView.swift:248-296`

```swift
private enum CaptionDesign {
    // 尺寸
    static let maxWidth: CGFloat = 672          // 最大宽度
    static let collapsedContentHeight: CGFloat = 100  // 折叠高度
    static let cornerRadius: CGFloat = 20       // 圆角
    static let padding: CGFloat = 24            // 内边距
    
    // 字体
    static let fontSize: CGFloat = 18           // 原文字号
    static let translatedFontSize: CGFloat = 16 // 译文字号
    static let lineSpacing: CGFloat = 4         // 行间距
    
    // 特效
    static let blurRadius: CGFloat = 20         // 模糊半径
    static let shadowRadius: CGFloat = 25       // 阴影半径
    
    // 拖动指示器
    static let dragIndicatorWidth: CGFloat = 32
    static let dragIndicatorHeight: CGFloat = 4
    
    // 滚动
    static let scrollBottomThreshold: CGFloat = 50
    static let scrollCatchUpThreshold: CGFloat = 5
    static let scrollExtraOffset: CGFloat = 8
}
```

---

## 5. 工具栏布局常量 (ToolbarLayout)

> 来源: `@spoke/UI/SelectionToolbar/SelectionToolbarView.swift:16-28`

```swift
private enum ToolbarLayout {
    static let height: CGFloat = 40
    static let buttonHeight: CGFloat = 32
    static let buttonPaddingH: CGFloat = 3
    static let logoButtonPaddingH: CGFloat = 10
    static let buttonCornerRadius: CGFloat = 6
    static let cornerRadius: CGFloat = 10
    static let iconSize: CGFloat = 15
    static let fontSize: CGFloat = 13
    static let spacing: CGFloat = 2
    static let separatorWidth: CGFloat = 1
    static let separatorHeight: CGFloat = 20
}
```

---

## 6. 布局模式

### FlowLayout（流式布局）
> 来源: `@spoke/UI/Components/TagBubbleView.swift:213-292`

用于标签列表自动换行：

```swift
FlowLayout(spacing: 6) {
    ForEach(tags) { tag in
        TagBubbleView(tag: tag)
    }
}
```

### LazyVStack（懒加载列表）

用于卡片列表，支持分页：

```swift
LazyVStack(spacing: 12) {
    ForEach(cards) { card in
        CardView(card: card)
    }
}
```

---

## 7. 对齐规范

| 场景 | 对齐方式 |
|------|----------|
| 面板内容 | `.top` |
| 卡片标题 | `.leading` |
| 时间戳 | 右侧 `Spacer()` 后 |
| 工具栏 | `HStack` 居中 |
| 字幕文字 | `.leading` |
