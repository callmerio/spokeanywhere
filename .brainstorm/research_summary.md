# Research Summary for: 实时字幕滚动性能优化

## 📁 Code Context (5 items)

1. `spoke/UI/LiveCaption/AppKitScrollView.swift` - NSScrollView 桥接实现
   - scrollToBottom() 使用 `scroll(to:)` 无动画直接跳转
   - 多个 `DispatchQueue.main.async` 延迟调用可能累积
   - `layoutSubtreeIfNeeded()` 频繁调用可能阻塞主线程
   - 2秒轮询定时器 + boundsDidChangeNotification + frameDidChangeNotification 三重机制

2. `spoke/UI/LiveCaption/CaptionDesign.swift:45-51` - 滚动常量
   - scrollBottomThreshold: 50pt
   - scrollCatchUpThreshold: 5pt (追赶滚动阈值)
   - scrollExtraOffset: 8pt

3. `spoke/UI/LiveCaption/LiveCaptionView.swift:197` - AppKitScrollView 使用
   - isAtBottom + scrollTrigger 双状态控制

4. 动画相关
   - `withAnimation(.easeInOut(duration: 0.15))` - LiveCaptionView:125
   - `withAnimation(.easeInOut(duration: 0.2))` - 多处
   - **NSScrollView 滚动无动画！** scrollView.contentView.scroll(to:) 是瞬时跳转

5. 布局更新
   - `invalidateIntrinsicContentSize()` - scrollToBottom:118
   - `layoutSubtreeIfNeeded()` - 多处
   - `hostingView.rootView = content` - updateNSView:88 每次更新都重设

## 📜 Memory Context (重要历史)

- **条目 267 (2025-12-29)**: 刚修复滚动方向判断 lastMaxScrollY 追踪
- **条目 241**: 一口气输出太多导致错位 - 双重延迟触发
- **条目 206**: 翻译完成后最后一行看不见 - 异步布局滞后
- **条目 201**: 长时间运行后翻译被截断 - Overscroll 校正机制
- **条目 193**: 滚动抖动 - invalidateIntrinsicContentSize 递归触发
- **条目 155**: 无限循环风险 - isScrollingProgrammatically 防抖
- **根因共识**: NSHostingView 布局更新是异步的，scrollToBottom 基于旧高度计算

## 🌐 External Research (12 items)

1. **[SwiftUI Scrolling Performance](https://fatbobman.com)** - List 优于 ScrollView；LazyVStack 只渲染可见项
2. **[NSScrollView Layer-Backing](https://jwilling.com)** - wantsLayer=true 启用 GPU 缓存；NSClipView 用 CAScrollLayer 优化
3. **[NSScrollView Animator](https://stackoverflow.com)** - scroll(to:) 不可动画；用 animator().setBoundsOrigin() + NSAnimationContext
4. **[CADisplayLink](https://apple.com)** - 同步显示刷新率；60fps 流畅动画
5. **[NSHostingView Sizing](https://apple.com)** - sizingOptions 减少 Auto Layout 计算；macOS 13+
6. **[Layer-Backed Performance](https://stackoverflow.com)** - 避免对大量小视图设 wantsLayer；用 layer.contents 替代 NSImageView
7. **[Animated Scroll Swift](https://github.com)** - NSAnimationContext.runAnimationGroup + animator().setBoundsOrigin
8. **[NSViewRepresentable Layout Lag](https://stackoverflow.com)** - updateNSView 频繁调用；避免重操作
9. **[CAScrollLayer](https://apple.com)** - 专为滚动优化；只渲染可见区域
10. **[Minimize Layer Hierarchies](https://apple.com)** - macOS 10.8+ 推荐；NSViewLayerContentsRedrawOnSetNeedsDisplay
11. **[SwiftUI WWDC 2024](https://medium.com)** - iOS 18 LazyVStack diffing 优化
12. **[Instruments Profiling](https://apple.com)** - Long Platform View Updates 检测 NSHostingView 性能

## 💡 Key Takeaways

### 🔴 问题根因分析

1. **无动画滚动** - `scroll(to:)` 是瞬时跳转，没有平滑过渡
2. **布局更新阻塞** - `layoutSubtreeIfNeeded()` + `invalidateIntrinsicContentSize()` 在主线程同步执行
3. **多重机制冲突** - Timer + boundsDidChange + frameDidChange 三重触发可能相互干扰
4. **NSHostingView 异步滞后** - SwiftUI 内容更新 → 布局计算 → 尺寸变化 有延迟

### 🟢 优化方向

1. **动画滚动** - 用 `NSAnimationContext` + `animator().setBoundsOrigin()` 替代 `scroll(to:)`
2. **Layer-Backing** - 启用 `wantsLayer = true` 提升 GPU 渲染效率
3. **减少布局频率** - 合并/节流布局更新请求
4. **简化触发机制** - 统一滚动触发逻辑，避免多重机制冲突

### ⚠️ 风险点

- 动画滚动可能与用户手动滚动冲突
- wantsLayer 对小视图可能有负面影响
- 需要兼容现有的滚动方向检测逻辑
