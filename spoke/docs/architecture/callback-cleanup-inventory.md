# SpokenAnyWhere 回调与 Observer 清理清单

**版本**: 1.0
**更新时间**: 2026-03-19
**定位**: APP-020 回调注册、所有权与清理路径清单

---

## 一、目的

本文档用于把高风险 callback / observer / monitor 的注册点、所有者和清理时机明确写清楚，避免在生命周期调整后出现残留回调、重复触发或 zombie observer。

---

## 二、AppDelegate

### 2.1 NotificationCenter observers

| 注册点 | 作用 | 持有者 | 清理时机 |
|------|------|------|------|
| `openToolbarSettingsObserver` | 接收 `.openToolbarSettings`，打开设置并聚焦工具栏 | `AppDelegate` | `applicationWillTerminate(_:)` |
| `shortcutObserver` | 接收 `AppSettings.shortcutDidChangeNotification`，更新菜单栏快捷键显示 | `AppDelegate` | `applicationWillTerminate(_:)` |
| `settingsWindowObserver` | 接收 `NSWindow.willCloseNotification`，在设置窗口关闭后恢复状态 | `AppDelegate` | 窗口关闭时立即移除；若仍残留则在 `applicationWillTerminate(_:)` 清理 |

### 2.2 清理原则

- `AppDelegate` 持有的 NotificationCenter token 必须保存到属性
- 所有 token 必须在终止路径中显式移除
- 窗口级 observer 允许就近移除，但终止路径仍要兜底

---

## 三、RecordingController

### 3.1 Owned callbacks

| 回调类型 | 注册点 | 作用 | 清理时机 |
|------|------|------|------|
| `hudManager.onComplete` / `onCancel` | `setupHUDCallbacks()` | 响应 HUD 操作 | `stop()` / `deinit` |
| `hotKeyService.onRecordingStart` / `onRecordingStop` | `setupHotKeyCallbacks()` | 响应录音热键 | `stop()` / `deinit` |
| `hotKeyService.onQuickAskStart` / `onQuickAskSend` / `onOpenSettings` | `setupQuickAskCallbacks()` | 响应 Quick Ask / 设置热键 | `stop()` / `deinit` |
| `hotKeyService.onMessagePanelToggle` / `onLiveCaptionToggle` / `onClipboardPipelineTrigger` | `setupMessagePanelCallbacks()` | 响应面板、字幕与剪贴板热键 | `stop()` / `deinit` |
| `recordingCallbackSessionID` 对应 audio callbacks | `setupAudioCallbacks()` | 录音时的音频级别、partial/final result、错误回调 | `stop()` / `deinit` |

### 3.2 清理原则

- `RecordingController` 拥有的运行期回调不应依赖单例自然释放
- `stop()` 是正常清理路径
- `deinit` 是兜底清理路径
- audio callback session 必须显式 `removeCallbackSession`

---

## 四、其他高风险点

### 4.1 SelectionToolbarManager

- `selectionMonitor.onSelectionChanged`：由 `SelectionToolbarManager` 注册
- `clickOutsideMonitor`：由 `setupClickOutsideMonitor()` 注册，`removeClickOutsideMonitor()` 移除

### 4.2 MessagePanelHoverState

- `localMonitor` / `globalMonitor`：在 `deinit` 中通过 `NSEvent.removeMonitor` 清理

---

## 五、APP-020 完成标准

满足以下条件时，可认为本轮 callback cleanup 已达到最小目标：

1. `AppDelegate` 的 NotificationCenter observers 都有可追踪 token 和显式清理路径
2. `RecordingController` 拥有 `deinit` 兜底清理
3. 本文档中明确写出 `AppDelegate` 与 `RecordingController` 的 callback 所有权
4. `python3 scripts/autoresearch/verify_issue_metric.py --issue APP-020` 指标降到 `0`

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-03-19
