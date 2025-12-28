# Spec: 实时字幕滚动方向逻辑修复

## Overview

修复实时字幕 `AppKitScrollView` 中滚动方向判断逻辑错误的问题。

当前行为：用户往**上**滑反而触发强制滚动到底部，导致无法查看历史内容。
期望行为：用户往**上**滑停止自动滚动，往**下**滑恢复自动滚动。

## Problem Analysis

### 根因
`AppKitScrollView.swift:253` 中的滚动方向判断逻辑写反了：

```swift
let userScrolledUp = scrollY < lastScrollY - 10  // ❌ 错误
```

在 **FlippedView** (isFlipped = true) 中：
- 坐标系 Y 轴从上往下增大
- 用户往**上**滑 → scrollY **增大**（露出顶部内容）
- 用户往**下**滑 → scrollY **减小**（露出底部内容）

所以 `scrollY < lastScrollY` 实际检测的是用户往**下**滚动，而不是往上。

### 影响范围
- `scrollViewDidScroll` 中的 `userScrolledUp` 判断
- 导致内容增加时错误触发 `forceScrollToBottom()`

## Requirements

### R1: 修复滚动方向判断
- 将 `scrollY < lastScrollY - 10` 改为 `scrollY > lastScrollY + 10`
- 正确识别用户往上滑动的行为

### R2: 保持现有功能不变
- Overscroll 检测仍然正常工作
- 内容增加追赶滚动仍然正常工作
- isAtBottom 状态管理不变

## Acceptance Criteria

- [ ] 用户往上滑 → 自动滚动停止，可以查看历史内容
- [ ] 用户往下滑到底部 → 自动滚动恢复
- [ ] 内容快速增加时 → 自动追赶滚动（之前在底部的情况下）
- [ ] 日志验证：`📐 Content grew, triggering catch-up scroll` 只在内容增加时触发，不在用户往上滑时触发

## Out of Scope

- Overscroll 触觉反馈逻辑
- 展开模式滚动逻辑
- 翻译完成后滚动触发逻辑
