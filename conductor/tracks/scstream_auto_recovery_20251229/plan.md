# Plan: SCStream 自动恢复机制

## Track Info
- **ID**: scstream_auto_recovery_20251229
- **Type**: Bug Fix
- **Status**: [?] Observation (3天无复现可关闭)
- **Est. Time**: 2h

## 备注
> ⚠️ **观察期**: 2025-12-29 ~ 2026-01-01
> 如果 3 天内没有再次出现 stream 中断问题，可以关闭此 track。
> 最后测试时间: 2025-12-29 00:50

## Checklist

### Task 1: AppAudioCaptureService 重试机制 (~45min) [x]
- [x] 添加重试相关属性
- [x] 实现 `isRecoverableError(_ error: Error) -> Bool`
- [x] 修改 `stream(_:didStopWithError:)`
- [x] 实现 `scheduleRetry()` + `attemptReconnect()`

### Task 2: LiveCaptionManager 状态同步 (~30min) [x]
- [x] 添加 `isRetrying` 计算属性
- [x] 监听 `onRetryStateChanged` 回调
- [x] 只在非重试状态下调用 `stop()`

### Task 3: LiveCaptionToolbar UI 更新 (~30min) [x]
- [x] 显示重连状态: "正在重连..." + ProgressView
- [x] help 提示根据状态变化

### Task 4: Bug 修复 [x]
- [x] 修复 -3808 错误 (stopCapture 前检查 isCapturing)
- [x] 修复资源泄露 (didStopWithError 中清理 stream)
- [x] 修复错误分类 (-3815/-3804 归为不可恢复)

### Task 5: 测试验证 [ ]
- [ ] 手动验证: 3 天观察期

## References
- `Core/LiveCaption/AppAudioCaptureService.swift`
- `Core/LiveCaption/LiveCaptionManager.swift`
- `UI/LiveCaption/LiveCaptionToolbar.swift`
