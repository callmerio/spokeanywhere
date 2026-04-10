# SpokenAnyWhere P1 生命周期 Inventory

**状态**: Active Reference
**更新时间**: 2026-04-10
**适用范围**: `LIFE-310`

---

## 一、目标与口径

本文件只回答三件事：

1. 谁负责注册 / 启动
2. 谁负责清理 / 停止
3. 这些动作具体落在哪个方法

当前 inventory 覆盖的 P1 对象：

- `AppDelegate`
- `RecordingController`
- `QuickAskService`
- `MessagePanelManager`
- `LiveCaptionManager`
- `ScreenshotManager`

结论口径：

- `ownership unknown = 0`
- 对没有显式 cleanup 的点，不写“未知”，改写成 `deferred + reason + residual risk`

---

## 二、P1 生命周期 Inventory

| 对象 | owner | register / start point | cleanup / stop point | 应用退出表现 | 结论 |
|------|-------|------------------------|----------------------|--------------|------|
| `AppDelegate` | `AppDelegate` | `applicationDidFinishLaunching()` -> `runStartupPipeline()` -> `buildStartupSteps()` / `startupAction()` | `applicationWillTerminate()` -> `buildShutdownSteps()` / `shutdownAction()`；观察者通过 `removeAllObservers()` 清理 | 显式停止 `RecordingController`、`QuickAskService`、`MessagePanelManager`、`LiveCaptionManager`、`ScreenshotManager`、`TrackpadSwipeService`、`SelectionToolbarManager`、`ResourceMonitor`，并移除 3 个通知观察者 | owner 明确；shutdown 清单已覆盖当前 P1 热点对象 |
| `RecordingController` | `RecordingController` | `AppDelegate.startRecordingController()` -> `start()`；`init()` 期间创建 audio callback session，并配置 HUD / Quick Ask / Message Panel 回调 | `stop()` -> `hotKeyService.unregister()` + `clear hotkey callbacks` + `stopRecordingSession()` + `removeCallbackSession()`；`resetRecordingSessionState()` 负责 timer 清理 | 应用退出时由 `AppDelegate.shutdownAction(.stopRecordingController)` 显式调用 | owner 明确；callback session 与 hotkey closures 已进入对称 cleanup |
| `QuickAskService` | `QuickAskService` | `init()` -> `setupHUDCallbacks()`；`startSession()` 启动 timer；`registerAudioCallbacks()` 按需创建 callback session | `sendQuestion()` / `cancelSession()` / `restartRecording()` 最终都会走 `stopRecording()` / `unregisterAudioCallbacks()` / `stopRecordingTimer()` / `resetSessionState()`；`stop()` 追加 HUD shutdown 与 follow-up callback 清理 | 应用退出时由 `AppDelegate.shutdownAction(.stopQuickAskService)` 显式调用 | owner 明确；会话级 cleanup 与 app-exit cleanup 现在都可回答 |
| `MessagePanelManager` | `MessagePanelManager` | `init()` 中配置 `hoverState` 回调；`show()` 首次调用 `createPanelIfNeeded()` 创建面板 | `hide()` 做窗口隐藏；`stop()` 追加 hoverState inert 化、窗口关闭与 panel 释放 | 应用退出时由 `AppDelegate.shutdownAction(.stopMessagePanelManager)` 显式调用 | owner 明确；app-exit cleanup 已显式治理 |
| `LiveCaptionManager` | `LiveCaptionManager` | `start()` 决定 capture 模式；`startWithAppPicker()` / `startWithGlobalCapture()` / `startWithLegacyTranscriber()` 分别注册 capture / transcriber / provider 回调 | `stop()` 停止 provider / transcriber / capture，取消 `translationTask` 与 `volatileTranslationTask`，重置状态并 `saveSegments()` | 应用退出时由 `AppDelegate.shutdownAction(.stopLiveCaptionManager)` 显式调用 | owner 明确；主 stop 路径与 app-exit cleanup 已显式治理 |
| `ScreenshotManager` | `ScreenshotManager` | `AppDelegate.setupScreenshotService()` 注入 `hotKeyService.onScreenshotTrigger` 与 `windowFactory`；启动时异步 `restoreAll()`；交互期 `captureRegion()` 建立 selection callbacks | `close(_:)` 负责单窗口回收；`stop()` 追加 selection window dismiss、窗口集合关闭、`saveAll()` 与 `windowFactory` 释放 | 应用退出时由 `AppDelegate.shutdownAction(.stopScreenshotManager)` 显式调用 | owner 明确；窗口链与 runtime factory 已纳入统一 cleanup |

---

## 三、Ownership / Cleanup 矩阵

| 资源 / 协调点 | owner | register point | cleanup point | 状态 | residual risk |
|---------------|-------|----------------|---------------|------|---------------|
| `shortcutObserver` / `toolbarSettingsObserver` / `settingsWindowObserver` | `AppDelegate` | `installObserver(...)` | `removeAllObservers()` -> `removeObserver(...)` | 已显式治理 | 仅覆盖 AppDelegate 自己的通知观察者 |
| `RecordingController.recordingTimer` | `RecordingController` | `startRecordingSession()` -> `makeRecordingDurationTimer(...)` | `resetRecordingSessionState()` | 已显式治理 | 无 |
| `RecordingController.recordingCallbackSessionID` | `RecordingController` | `init()` -> `audioService.createCallbackSession()` | `stop()` -> `removeCallbackSession(...)` + recreate clean session | 已显式治理 | 无 |
| `HotKeyService.onRecordingStart / onRecordingStop` | `RecordingController` | `start()` -> `wireRecordingCaptureHotKeyCallbacks(...)` | `stop()` -> `clearRecordingCaptureHotKeyCallbacks(...)` | 已显式治理 | 无 |
| `QuickAskService.recordingTimer` | `QuickAskService` | `startRecordingTimer()` | `stopRecordingTimer()` | 已显式治理 | 无 |
| `QuickAskService.quickAskCallbackSessionID` | `QuickAskService` | `registerAudioCallbacks()` | `unregisterAudioCallbacks()` | 已显式治理 | 无 |
| `QuickAskHUDManager.cancelObserver` | `QuickAskHUDManager` | `setupCancelObserver()` | `shutdown()` -> `removeObserver(...)` | 已显式治理 | 无 |
| `MessagePanel hoverState callbacks` | `MessagePanelManager` | `init()` -> `hoverState.configure(...)` | `stop()` -> `hoverState.configure(no-op deps)` | 已显式治理 | 无 |
| `LiveCaption translationTask` | `LiveCaptionManager` | 翻译更新路径中创建 | `stop()` -> `translationTask?.cancel()` | 已显式治理 | 无 |
| `LiveCaption volatileTranslationTask` | `LiveCaptionManager` | `translateVolatileText()` | `stop()` + 新文本 / finalize 路径取消 | 已显式治理 | 无 |
| `ScreenshotManager.activeSelectionWindow` | `ScreenshotManager` | `showRegionSelectionUI(...)` | `onComplete` / `onCancel` 置空；toggle 时 `dismiss()` | 已显式治理 | 无 |
| `ScreenshotManager.windowFactory` | `AppDelegate` / `ScreenshotManager` | `AppDelegate.setupScreenshotService()` | `stop()` -> `windowFactory = nil` | 已显式治理 | 无 |

---

## 四、重复 Start / Stop、窗口关闭、应用退出

### 4.1 重复 start / stop

- `RecordingController`
  - `start()` 会重新设置 hotkey callbacks 并调用 `register()`
  - `stop()` 会 `unregister()` 并停止当前录音会话
  - 结论：热键注册/注销有明确入口，但 callback session 不是对称释放

- `QuickAskService`
  - `startSession()` 每次都会重启 timer，并延迟启动录音
  - `restartRecording()` 会主动 `cancelRecording()` + `unregisterAudioCallbacks()` 后重建录音会话
  - `stop()` 会把 app-exit cleanup 收口到 HUD、callback session 与 follow-up callback
  - 结论：会话级重入与 app-exit cleanup 都已显式治理

- `LiveCaptionManager`
  - `start()` 有 `guard !isActive`
  - `toggle()` 与 `stop()` 组合成唯一显式停机路径
  - 结论：重复启停受 `isActive` 保护，但仍需补齐 volatile task cleanup

### 4.2 窗口关闭

- `MessagePanelManager.hide()` 只隐藏窗口，不销毁 panel
- `ScreenshotManager.close(_:)` 会关闭窗口、删除 item、写回持久化
- `QuickAskHUDManager.hide()` 只 orderOut，不移除 cancel observer

### 4.3 应用退出

- 当前 `AppDelegate` 的 shutdown plan 明确执行：
  - `RecordingController.stop()`
  - `QuickAskService.stop()`
  - `MessagePanelManager.stop()`
  - `LiveCaptionManager.stop()`
  - `ScreenshotManager.stop()`
  - `TrackpadSwipeService.stop()`
  - `SelectionToolbarManager.stop()`
  - `ResourceMonitor.stop()`
  - `removeAllObservers()`

当前结论已更新为：P1 热点对象的 app-exit cleanup contract 已进入统一 shutdown plan；后续工作更多是持续约束新增对象也走同一路径，而不是继续补这批既有热点。

---

## 五、给 RULE-320 的直接输入

从本 inventory 可以直接抽出三条约束：

1. 新 callback / observer / timer / task 必须同时写 `owner + register point + cleanup point`
2. app-scope 常驻对象如果不进 `AppLifecyclePlan.shutdown(...)`，必须明确写“为什么允许常驻”；当前 P1 热点对象已全部纳入
3. UI / manager 层如果只 hide 不 destroy，必须明确状态由谁持久化、何时回收

---

## 六、相关文档

- `./app-layer-startup-sequence.md`
- `./app-layer-callback-chains.md`
- `./app-layer-risk-assessment.md`
- `../plans/2026-04-10-architecture-optimization-roadmap-v3.md`
- `../../tasks/2026-04-10-architecture-optimization-roadmap-v3-execution.md`

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-04-10
