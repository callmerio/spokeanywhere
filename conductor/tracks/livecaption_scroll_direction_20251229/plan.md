# Plan: 实时字幕滚动方向逻辑修复

## Overview
类型: Bug Fix (Chore)
预计耗时: 10min
风险等级: Low

## Task 1: 修复滚动方向判断

### 修改文件
- `spoke/UI/LiveCaption/AppKitScrollView.swift`

### 修改内容
第 253 行：
```swift
// Before (错误)
let userScrolledUp = scrollY < lastScrollY - 10

// After (正确)
let userScrolledUp = scrollY > lastScrollY + 10
```

### 验证
- [ ] 往上滑 → 日志不出现 "Content grew, triggering catch-up scroll"
- [ ] 往上滑 → isAtBottom 变为 false
- [ ] 内容增加 → 日志出现追赶滚动信息

## Task 2: 验证测试

### 测试场景
1. 启动实时字幕，等待内容产生
2. 往上滑一次 → 验证自动滚动停止
3. 继续等待新内容 → 验证不会强制拉回底部
4. 往下滑到底部 → 验证自动滚动恢复
5. 快速产生大量内容 → 验证追赶滚动正常

## Rollback Plan

如果出现问题，还原第 253 行为原始代码。
