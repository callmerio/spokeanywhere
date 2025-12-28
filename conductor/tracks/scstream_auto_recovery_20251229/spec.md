# Spec: SCStream 自动恢复机制

## Overview
实时字幕运行一段时间后 SCStream 被系统停止 (错误码 -3821 `systemStoppedStream`)，当前代码无恢复机制，用户只能看到字幕消失。

## 问题复现
1. 启动实时字幕，选择应用音频捕获模式
2. 选择一个应用进行音频捕获
3. 运行一段时间后 (或关闭目标应用)
4. 日志显示: `❌ Stream stopped with error: 系统已停止流播放 [code: -3821]`
5. 字幕停止更新，用户无感知

## Requirements

### R1: 错误分类
区分可恢复和不可恢复错误:
- **可恢复**: `systemStoppedStream`, `failedApplicationConnectionInterrupted`, `internalError`
- **不可恢复**: `userStopped`, `userDeclined`, `missingEntitlements`

### R2: 自动重试机制
- 可恢复错误触发自动重试
- 使用 exponential backoff: 1s → 2s → 4s
- 最多重试 3 次
- 重试成功后重置计数器

### R3: 用户通知
- 重试中: 工具栏显示 "正在重连..."
- 重试失败: 显示 "音频捕获已断开" + "重新选择" 按钮
- 重试成功: 恢复正常显示

### R4: 手动恢复入口
- LiveCaption 工具栏提供 "重新选择应用" 按钮 (已有)
- 确保断开后按钮可用

## Acceptance Criteria
- [ ] 目标应用关闭后，自动触发重试
- [ ] 重试过程中 UI 有反馈
- [ ] 3次重试失败后显示错误提示
- [ ] 点击"重新选择"可重新选择应用
- [ ] 不影响手动停止字幕的正常流程

## Out of Scope
- 系统音频模式 (SystemAudioCaptureService) 暂不处理
- 网络相关错误恢复
