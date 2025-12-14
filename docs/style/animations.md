# 动画系统

> 📍 来源: 项目全局 SwiftUI 视图

---

## 1. 标准动画曲线

| 类型 | 代码 | 时长 | 用途 |
|------|------|------|------|
| **Hover** | `.easeInOut(duration: 0.15)` | 150ms | 悬浮状态切换 |
| **状态切换** | `.easeInOut(duration: 0.2)` | 200ms | 面板显示/隐藏 |
| **内容变化** | `.easeOut(duration: 0.2)` | 200ms | 文字淡入 |
| **弹性展开** | `.spring(response: 0.3)` | ~300ms | 卡片展开/折叠 |
| **持续旋转** | `.linear(duration: 1.5).repeatForever` | 1.5s | 加载指示器 |

---

## 2. Hover 动画

### 标准 Hover
> 来源: `@spoke/UI/Components/TagBubbleView.swift:48-52`

```swift
.onHover { hovering in
    withAnimation(.easeInOut(duration: 0.15)) {
        isHovered = hovering
    }
}
```

### 面板 Hover
> 来源: `@spoke/UI/LiveCaption/LiveCaptionView.swift:349-353`

```swift
.onHover { hovering in
    withAnimation(.easeInOut(duration: 0.15)) {
        isHovering = hovering
    }
}
```

---

## 3. 过渡动画 (Transition)

### 卡片插入/移除
> 来源: `@spoke/UI/MessagePanel/MessagePanelView.swift:294-297`

```swift
.transition(.asymmetric(
    insertion: .scale(scale: 0.9).combined(with: .opacity).combined(with: .offset(y: -10)),
    removal: .scale(scale: 0.9).combined(with: .opacity)
))
```

### 标签筛选气泡
> 来源: `@spoke/UI/MessagePanel/MessagePanelView.swift:235-239`

```swift
.transition(.asymmetric(
    insertion: .scale(scale: 0.5).combined(with: .opacity),
    removal: .scale(scale: 0.8).combined(with: .opacity)
))
```

### 淡入淡出
```swift
.transition(.opacity)
```

---

## 4. 弹性动画 (Spring)

### 卡片展开/折叠
> 来源: `@spoke/UI/LiveCaption/LiveCaptionView.swift:577-579`

```swift
withAnimation(.spring(response: 0.3)) {
    isExpanded.toggle()
}
```

### 成功对勾
> 来源: `@spoke/UI/HUD/FloatingCapsuleView.swift:512-514`

```swift
withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
    checkmarkScale = 1
}
```

---

## 5. 持续动画

### 跑马灯边框
> 来源: `@spoke/UI/HUD/FloatingCapsuleView.swift:599-603`

```swift
.onAppear {
    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
        rotation = 360
    }
}
```

### 思考指示器（彩色点旋转）
> 来源: `@spoke/UI/HUD/FloatingCapsuleView.swift:524-528`

```swift
withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
    rotation = 360
}
```

### 三点跳动
> 来源: `@spoke/UI/HUD/FloatingCapsuleView.swift:543-548`

```swift
.animation(
    .easeInOut(duration: 0.6)
    .repeatForever()
    .delay(Double(index) * 0.2),
    value: isAnimating
)
```

---

## 6. 波形动画

### 音频波形更新
> 来源: `@spoke/UI/HUD/FloatingCapsuleView.swift:339-342`

```swift
withAnimation(.linear(duration: 0.05)) {
    self.levels = newLevels
}
```

---

## 7. 流式文字动画

### 译文渐入
> 来源: `@spoke/UI/LiveCaption/LiveCaptionView.swift:448`

```swift
.animation(.easeOut(duration: 0.2), value: pendingTranslation)
```

### 新条目灰→白
> 来源: `@spoke/UI/LiveCaption/LiveCaptionView.swift:423`

```swift
.opacity(isNew ? 0.7 : 1.0)
.animation(.easeOut(duration: 0.3), value: isNew)
```

---

## 8. 禁用动画

### 避免布局动画

```swift
// 方案1：animation(nil)
.animation(nil, value: someValue)

// 方案2：ZStack 分离布局层和渲染层
ZStack {
    // 布局层（无动画）
    Text(content).hidden()
    // 渲染层（有动画）
    Text(content).opacity(opacity)
}
.animation(nil, value: content)
```

---

## 9. 动画设计约束

- **避免阻塞动画**：UI 卡顿时移除动画
- **Hover 动画必须轻量**：≤ 150ms
- **状态切换必须有反馈**：≥ 200ms
- **持续动画不可阻塞**：使用 `.repeatForever`
- **流式内容禁用布局动画**：避免"文字下落"效果
