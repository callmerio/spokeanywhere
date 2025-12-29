# Code Review Report: 实时字幕滚动性能优化研究

**Review Scope**: `.brainstorm/research_summary.md` + 相关源码验证
**Reviewer**: CCW Critic (Qwen)
**Date**: 2025-12-29T17:42

---

## Summary: ⚠️ REQUEST CHANGES

研究分析大方向正确，但存在**关键遗漏**和**方案优先级问题**。

---

## Critical Issues 🚨

### 1. 方案 A "动画滚动" 可能导致新 bug

**问题**: `animator().setBoundsOrigin()` 动画期间，`scrollViewDidScroll` 会被连续触发。

**现有代码依赖**:
```swift
// AppKitScrollView.swift:239-280
@objc func scrollViewDidScroll(_ notification: Notification) {
    guard !isScrollingProgrammatically else { return }  // 只检查这个标志
    // ... 计算 isAtBottom ...
}
```

**风险**: 
- 动画期间 `isScrollingProgrammatically = true` 但 `defer` 立即重置为 `false`
- 动画滚动触发多次 `scrollViewDidScroll`，每次都会执行检测逻辑
- 可能误判 `isAtBottom` 状态 → 触发 `forceScrollToBottom()` 循环

**建议**: 需要新增 `isAnimatingScroll` 状态或延长 `isScrollingProgrammatically` 有效期

---

### 2. 遗漏关键瓶颈：`invalidateIntrinsicContentSize()`

**代码位置**: `AppKitScrollView.swift:118`
```swift
hostingView.invalidateIntrinsicContentSize()  // 🔴 每次 scrollToBottom 都调用
hostingView.layoutSubtreeIfNeeded()
```

**问题**:
- **Memory 条目 193** 明确记录这导致抖动
- 研究报告只提到"频繁调用可能阻塞"但未作为优化重点
- 这是**同步阻塞主线程**的操作，比动画问题更严重

**建议**: 移除或条件化 `invalidateIntrinsicContentSize()` 应作为**首选优化**

---

## Quality Issues ⚠️

### 3. 方案优先级错误

**现有优先级**:
1. 动画滚动
2. Layer-Backing
3. 减少布局频率
4. 简化触发机制

**建议优先级** (基于 ROI 和风险):
1. **移除 `invalidateIntrinsicContentSize()`** - 零风险，立即见效
2. **简化触发机制** - 移除 Timer，减少冲突
3. **Layer-Backing** - 低风险，可能有效
4. **动画滚动** - 高风险，需要额外状态管理

### 4. 遗漏 `updateNSView` 优化

**代码位置**: `AppKitScrollView.swift:88`
```swift
hostingView.rootView = content  // 每次 SwiftUI 更新都重设
```

**问题**: 这会触发完整的 SwiftUI diff + layout cycle

**外部研究已提到**: "updateNSView 频繁调用；避免重操作"

**建议**: 添加 `content` 变化检测，避免无意义的 rootView 重设

---

## Architecture Concerns 🏗️

### 5. 三重触发机制未简化

研究报告指出问题但未给出具体方案：
- Timer (2秒轮询)
- boundsDidChangeNotification
- frameDidChangeNotification

**分析**:
- Timer 是**遗留补救措施**，当其他机制失效时兜底
- boundsDidChange 用于用户滚动检测
- frameDidChange 用于内容高度变化检测

**建议**: Timer 可以安全移除，因为 frameDidChange 已覆盖其场景

---

## Positive Observations ✅

1. **Memory 历史充分** - 15+ 条相关记录，学习曲线陡峭问题不会重复
2. **外部研究全面** - 12 条外部信息，方案有理论支撑
3. **风险点识别准确** - 动画与手动滚动冲突、兼容性问题都有提及
4. **根因分析正确** - NSHostingView 异步滞后是核心问题

---

## Recommendations

### 立即执行 (低风险)

1. **移除 `invalidateIntrinsicContentSize()`** @ line 118
   ```diff
   - hostingView.invalidateIntrinsicContentSize()
   ```

2. **移除 2秒轮询 Timer** @ startPolling()
   - 已有 frameDidChange 兜底

### 第二阶段

3. **添加 Layer-Backing**
   ```swift
   scrollView.wantsLayer = true
   scrollView.contentView.wantsLayer = true
   ```

4. **优化 `updateNSView`**
   ```swift
   if hostingView.rootView != content {  // 需要 Equatable
       hostingView.rootView = content
   }
   ```

### 第三阶段 (需要充分测试)

5. **动画滚动** - 需要新增状态管理机制后再实施

---

## Verdict

🟡 **REQUEST CHANGES**

研究方向正确但执行优先级需调整。建议从**低风险高收益**的修改开始，逐步验证效果后再实施复杂方案。
