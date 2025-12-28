# Research Summary: LiveCaption Scroll Direction Bug

## 📁 Code Context (5 items)

1. `spoke/UI/LiveCaption/AppKitScrollView.swift:253` - `userScrolledUp` 判断逻辑
2. `spoke/UI/LiveCaption/AppKitScrollView.swift:275` - Overscroll (Pull-up) 检测逻辑
3. `spoke/UI/LiveCaption/AppKitScrollView.swift:337-339` - FlippedView 定义
4. `spoke/UI/LiveCaption/LiveCaptionView.swift:25` - `isAtBottom` 状态
5. `docs/memo/memory.csv:206` - 之前修复滚动错位的记录

## 📜 Memory Context

- `memory.csv:206` (2025-12-18): 区分「用户向上滚动」vs「内容增加导致脱离底部」
- `memory.csv:193` (2025-12-14): 滚动抖动修复，isScrollingProgrammatically 防抖
- `memory.csv:201` (2025-12-15): Overscroll 检测 + Haptic 反馈

## 🌐 External Research (12 items)

1. [StackOverflow - NSScrollView flipped coordinates](https://stackoverflow.com) - In flipped view, scrollY increases when scrolling DOWN
2. [Medium - SwiftUI NSScrollView](https://medium.com) - Use Coordinator pattern for scroll event handling
3. [Apple Developer - NSView.isFlipped](https://developer.apple.com) - isFlipped property affects coordinate system
4. [StackOverflow - NSViewBoundsDidChangeNotification](https://stackoverflow.com) - Use boundsDidChangeNotification for scroll detection
5. [Medium - Chat auto-scroll](https://medium.com) - Stop auto-scroll when user scrolls up, resume when at bottom
6. [GitHub - Terminal log viewer](https://github.com) - Pause auto-scroll on user scroll, resume at bottom
7. [SwiftBySwamit - ScrollViewReader](https://swiftbysundell.com) - SwiftUI programmatic scrolling
8. [YouTube - SwiftUI chat scroll](https://youtube.com) - Auto-scroll implementation pattern
9. [StackOverflow - Debounce scroll events](https://stackoverflow.com) - Performance optimization for scroll handlers
10. [ChristianTietze - NSScrollView monitoring](https://christiantietze.de) - Best practices for scroll position tracking
11. [Apple Developer - NSClipView](https://developer.apple.com) - documentVisibleRect for scroll position
12. [Medium - Natural Scrolling macOS](https://medium.com) - System settings don't affect coordinate system

## 💡 Key Takeaways

### 问题根因确认

**当前代码 (AppKitScrollView.swift:253)**:
```swift
let userScrolledUp = scrollY < lastScrollY - 10  // ❌ 错误！
```

**在 FlippedView 中**:
- 用户往**上**滑 → scrollY **增大** (不是减小！)
- 用户往**下**滑 → scrollY **减小**

**所以当前逻辑是反的**：
- `scrollY < lastScrollY - 10` 实际检测的是用户往**下**滑
- 但代码把它当作 `userScrolledUp` 来判断

**修复方案**:
```swift
let userScrolledUp = scrollY > lastScrollY + 10  // ✅ 正确：scrollY 增大 = 用户往上滑
```

### 期望行为
1. 用户往**上**滑 → `isAtBottom = false` → 停止自动滚动
2. 用户往**下**滑到底部 → `isAtBottom = true` → 恢复自动滚动
3. 内容增加导致脱离底部 → 保持 `isAtBottom = true` → 追赶滚动
