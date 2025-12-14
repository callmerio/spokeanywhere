# 组件样式

> 📍 来源: `@spoke/UI/Components/`, `@spoke/UI/HUD/`

---

## 1. 毛玻璃背景

### VisualEffectBlur
> 来源: `@spoke/UI/MessagePanel/MessagePanelView.swift:162-167`

```swift
VisualEffectBlur(
    material: .popover,     // 或 .hudWindow
    cornerRadius: 16
)
```

### VisualEffectBackground
> 来源: `@spoke/UI/HUD/FloatingCapsuleView.swift:394-424`

```swift
VisualEffectBackground(
    material: .hudWindow,
    blendingMode: .behindWindow,
    cornerRadius: 16
)
```

---

## 2. 卡片样式

### MessageCardView 卡片
> 来源: `@spoke/UI/MessagePanel/MessagePanelView.swift:477-484`

```swift
VStack { /* 内容 */ }
    .padding(14)
    .background(Color.white.opacity(0.1))  // cardBackground
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
```

### 字幕卡片
> 来源: `@spoke/UI/LiveCaption/LiveCaptionView.swift:343-348`

```swift
VStack { /* 内容 */ }
    .frame(width: 672)  // maxWidth
    .background(cardBackground)  // 毛玻璃 + 深色叠加
    .clipShape(RoundedRectangle(cornerRadius: 20))
    .overlay(cardBorder)  // white/0.05 边框
    .shadow(color: .black.opacity(0.4), radius: 25, x: 0, y: 10)
```

---

## 3. 标签气泡

### TagBubbleView
> 来源: `@spoke/UI/Components/TagBubbleView.swift:29-52`

```swift
Text(tag.name)
    .font(.system(size: 11, weight: .medium))
    .foregroundColor(tag.color.color)
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(
        Capsule()
            .fill(tag.color.color.opacity(isHovered ? 0.25 : 0.15))
    )
    .overlay(
        Capsule()
            .stroke(tag.color.color.opacity(0.3), lineWidth: 1)
    )
```

### 激活状态
```swift
.fill(tag.color.color.opacity(isFilterActive ? 0.4 : 0.15))
.stroke(tag.color.color.opacity(isFilterActive ? 0.6 : 0.3), lineWidth: isFilterActive ? 1.5 : 1)
.scaleEffect(isFilterActive ? 1.05 : 1.0)
```

---

## 4. 按钮样式

### HoverCloseButton（圆形关闭按钮）
```swift
Image(systemName: "xmark")
    .font(.system(size: 10, weight: .medium))
    .foregroundColor(HUDTheme.textSecondary)
    .frame(width: 20, height: 20)
    .background(Color.white.opacity(isHovered ? 0.15 : 0.08))
    .clipShape(Circle())
```

### 工具栏按钮
> 来源: `@spoke/UI/SelectionToolbar/SelectionToolbarView.swift:16-28`

```swift
// ToolbarLayout
height: 40
buttonHeight: 32
buttonPaddingH: 3
buttonCornerRadius: 6
iconSize: 15
fontSize: 13
```

---

## 5. 分隔线

### ToolbarDivider
> 来源: `@spoke/UI/SelectionToolbar/SelectionToolbarView.swift:134-140`

```swift
Rectangle()
    .fill(Color.white.opacity(0.15))
    .frame(width: 1, height: 20)
    .padding(.horizontal, 4)
```

---

## 6. 阴影层级

### 工具栏阴影（三层）
> 来源: `@spoke/UI/SelectionToolbar/SelectionToolbarView.swift:59-61`

```swift
.shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 0.5)   // 贴边
.shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)    // 中层
.shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)   // 远层
```

### 字幕卡片阴影
```swift
.shadow(color: .black.opacity(0.4), radius: 25, x: 0, y: 10)
```

---

## 7. 渐变遮罩

### 顶部渐隐（字幕列表）
> 来源: `@spoke/UI/LiveCaption/LiveCaptionView.swift:460-468`

```swift
.mask(LinearGradient(
    gradient: Gradient(stops: [
        .init(color: .clear, location: 0),
        .init(color: .black, location: 0.1),
        .init(color: .black, location: 1.0)
    ]),
    startPoint: .top,
    endPoint: .bottom
))
```

### 底部渐隐（折叠卡片）
> 来源: `@spoke/UI/MessagePanel/MessagePanelView.swift:829-843`

```swift
.mask {
    VStack(spacing: 0) {
        Color.white
        LinearGradient(
            colors: [.white, .clear],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 24)
    }
}
```

---

## 8. 拖动指示器

> 来源: `@spoke/UI/LiveCaption/LiveCaptionView.swift:565-569`

```swift
RoundedRectangle(cornerRadius: 2)  // height/2
    .fill(Color.white.opacity(0.2))
    .frame(width: 32, height: 4)
    .padding(.bottom, 8)
```
