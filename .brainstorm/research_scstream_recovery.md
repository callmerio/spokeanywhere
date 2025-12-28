# Research Summary: SCStream 自动恢复机制

## 问题描述
实时字幕运行一段时间后自动停止
- 错误码: `-3821` (SCStreamErrorDomain)
- 错误信息: "系统已停止流播放"
- 服务: AppAudioCaptureService

## 📁 Code Context (4 items)
1. `Core/LiveCaption/AppAudioCaptureService.swift:287-295` - SCStreamDelegate didStopWithError 处理
2. `Core/LiveCaption/SystemAudioCaptureService.swift:248-250` - 同样的错误处理模式
3. `Core/LiveCaption/LiveCaptionManager.swift:228,326,439,468` - AppAudioCaptureService 使用点
4. `Core/LiveCaption/AppAudioCaptureService.swift:36-45` - 回调: onPCMBuffer/onError/onSelectionComplete

## 📜 Memory Context
- `docs/memo/cards.md:C011` - ScreenCaptureKit 系统音频捕获基础知识
- `docs/memo/memory.csv:87-88` - 实时字幕开发记录，提到 ScreenCaptureKit 输出格式处理
- **无直接相关的 stream recovery 记录**

## 🌐 External Research (12 items) 🔴

### 错误码解析
1. **Apple Developer (SCStreamError)** - `-3821` 对应 `userStopped` 或 `systemStoppedStream`，表示系统主动停止流
2. **Apple Developer (Error Codes)** - 完整错误码列表:
   - `-3801` userDeclined
   - `-3802` failedToStart
   - `-3804` failedApplicationConnectionInvalid
   - `-3805` failedApplicationConnectionInterrupted
   - `-3821` 可能是 systemStoppedStream

### Stream 停止原因
3. **StackOverflow** - 长时间音频捕获可能触发 EXC_BAD_ACCESS，是框架级bug
4. **Apple Forums** - Wake from sleep 后 stream 会停止/冻结
5. **Apple Forums** - 多个 SCStream 同时运行会导致全部停止
6. **Apple Forums** - macOS Sonoma/Sequoia 特定版本问题

### 恢复策略
7. **Apple Developer (Best Practice)** - `stream(_:didStopWithError:)` 是错误处理入口
8. **Apple Developer** - `userStopped` 应视为用户主动停止，非错误
9. **Apple Developer** - `systemStoppedStream` 需要尝试重新初始化
10. **Apple Developer** - 恢复流程: 1)停止旧流 2)重新创建 SCContentFilter/SCStream 3)startCapture()
11. **GitHub** - 建议实现 exponential backoff 重试机制
12. **Apple Developer** - 目标应用关闭后会触发 `lostConnectionToApp` 或 `noCaptureSource`

## 💡 Key Takeaways

### 根因分析
- 错误码 `-3821` 是 `systemStoppedStream`，表示系统主动终止了音频流
- 可能原因:
  1. **目标应用关闭** - 用户关闭了被捕获的应用
  2. **系统资源回收** - 长时间运行后系统回收资源
  3. **Wake from sleep** - 电脑休眠唤醒后流失效
  4. **框架 bug** - macOS Sonoma 已知问题

### 当前代码问题
- `AppAudioCaptureService.stream(_:didStopWithError:)` 只是记录错误并清理状态
- **没有任何自动恢复逻辑**
- 用户只能看到字幕消失，不知道发生了什么

### 解决方案
1. **实现自动恢复机制**:
   - 区分可恢复/不可恢复错误
   - systemStoppedStream/connectionInterrupted → 自动重试
   - userStopped → 不重试
   
2. **用户通知**:
   - 显示错误提示 "音频捕获已中断"
   - 提供 "重新选择应用" 按钮
   
3. **重试策略**:
   - 使用 exponential backoff (1s → 2s → 4s)
   - 最多重试 3 次
   - 重试失败后提示用户手动操作

4. **LiveCaptionManager 集成**:
   - 监听 AppAudioCaptureService.onError
   - 触发恢复流程或 UI 提示
