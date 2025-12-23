# Research Summary: 截图 Pin 窗口单击拖拽优化

## 📁 Code Context (4 items)

1. `spoke/UI/Screenshot/ScreenshotWindow.swift:117-128` - 窗口配置
   - 使用 `styleMask: [.borderless, .nonactivatingPanel]`
   - `isMovableByWindowBackground = !item.isLocked`
   - `canBecomeKey = true`, `canBecomeMain = false`

2. `spoke/UI/Screenshot/ScreenshotContentView.swift:514-519` - 现有拖拽实现
   - 已使用 `window?.performDrag(with: event)` 处理拖拽
   - 在 `mouseDown` 中触发
   - **问题**: 没有实现 `acceptsFirstMouse`，导致第一次点击只激活窗口

3. `spoke/UI/Screenshot/ScreenshotContentView.swift:500-512` - mouseDown 逻辑
   - 检查 ActionBar 点击区域
   - 检查 Live Text 活跃选择
   - 未锁定时调用 `performDrag`

4. `spoke/UI/Screenshot/ScreenshotWindow.swift:148-149` - isMovableByWindowBackground
   - 已设置 `isMovableByWindowBackground = !item.isLocked`
   - 但这个属性在 `nonactivatingPanel` 模式下不足以实现单击拖拽

## 📜 Memory Context

- 无直接相关记录
- 2025-12-19 有截图光晕标记系统的记录，提到 Window 级别 trackingArea

## 🌐 External Research (12 items)

1. **[Stack Overflow - acceptsFirstMouse doesn't work](https://stackoverflow.com/questions/54249563)**
   - `acceptsFirstMouse` 必须在 NSView 子类中重写
   - 返回 `true` 允许非活跃窗口响应第一次点击

2. **[Stack Overflow - NSPanel not receiving mousedragged event](https://stackoverflow.com/questions/15431559)**
   - `NSNonactivatingPanelMask` 窗口在失去焦点后不接收 `mouseDragged`
   - 解决方案: 重写 `acceptsFirstMouse` 返回 `true`

3. **[Stack Overflow - Allow click and dragging view to drag window](https://stackoverflow.com/questions/4563893)**
   - 使用 `performDrag(with:)` 是正确的拖拽方式
   - 配合 `acceptsFirstMouse` 可实现单击拖拽

4. **[Stack Overflow - Move NSWindow by dragging NSView](https://stackoverflow.com/questions/30963700)**
   - `mouseDown` 中调用 `window?.performDrag(with: event)` 是最佳实践
   - 无需额外的 `mouseDragged` 处理

5. **[Apple Developer - performDrag(with:)](https://developer.apple.com/documentation/appkit/nswindow/performdrag)**
   - 从 macOS 10.11 起可用
   - 启动窗口拖拽，类似拖拽标题栏

6. **[Stack Overflow - acceptsFirstMouse click through](https://stackoverflow.com/questions/48878171)**
   - 子类化 NSImageView 并重写 `acceptsFirstMouse` 可完美工作
   - NSImageView 继承自 NSView，方法相同

7. **[CleanClip Developer - SwiftUI NSWindow inactive firstmouse](https://cleanclip.cc/developer/swiftui-nswindow-inactive-firstmouse)**
   - 非活跃窗口默认不响应首次点击
   - 需要显式实现 click-through 行为

8. **[Stack Overflow - SwiftUI acceptsFirstMouse](https://stackoverflow.com/questions/59130116)**
   - 提供了 SwiftUI 中实现 `acceptsFirstMouse` 的方案
   - 使用 NSViewRepresentable 桥接

9. **[Cindori - Make a floating panel in SwiftUI](https://cindori.com/developer/floating-panel)**
   - NSPanel 的浮动面板最佳实践
   - `nonactivatingPanel` + `isFloatingPanel` 组合

10. **[Stack Overflow - Show window without stealing focus](https://stackoverflow.com/questions/46023769)**
    - NSPanel 配置: `styleMask: .nonactivatingPanel`
    - 需要额外处理鼠标事件穿透

11. **[Apple HIG - Drag and drop](https://developer.apple.com/design/human-interface-guidelines/patterns/drag-and-drop/)**
    - 拖拽应该流畅无延迟
    - 用户期望直接交互

12. **[Apple Stack Exchange - macOS windows requiring explicit click](https://apple.stackexchange.com/questions/269622)**
    - 这是 macOS 默认行为，需要应用显式选择退出
    - 对于工具窗口，单击直接交互是更好的 UX

## 💡 Key Takeaways

### 根因分析
- 当前 `ScreenshotContentView` 没有实现 `acceptsFirstMouse(for:)` 方法
- macOS 默认行为：非活跃窗口首次点击只激活窗口，不传递事件
- `nonactivatingPanel` 样式使窗口不抢焦点，但不自动支持 click-through

### 解决方案
```swift
// 在 ScreenshotContentView 中添加:
override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    return true  // 允许非活跃窗口响应首次点击
}
```

### 注意事项
1. **Live Text 兼容性**: 需要确保 `acceptsFirstMouse` 不影响 Live Text 的文本选择功能
2. **ActionBar 交互**: ActionBar 按钮也应该支持首次点击
3. **Locked 状态**: 锁定状态下可能仍需要此行为（用于显示 ActionBar）

### 风险评估
- **低风险**: `acceptsFirstMouse` 是标准 AppKit API
- **测试重点**: Live Text 选择、ActionBar 按钮、拖拽行为
