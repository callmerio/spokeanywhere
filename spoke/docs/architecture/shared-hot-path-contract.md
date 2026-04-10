# SpokenAnyWhere Shared Hot Path Contract

**状态**: Active Reference
**更新时间**: 2026-04-10
**适用范围**: `ORCH-360` / `ORCH-370`

---

## 一、合同目的

Wave 3 的瘦身不能只看 `RecordingController` 和 `QuickAskService` 各自是否能编译。
以下共享热路径必须作为一份跨服务合同持续成立：

- `onQuickAskStart`
- `onQuickAskSend`
- 延迟录音失败路径
- cancel 中断路径
- HUD `hide(restorePolicy: false)` 到 `AnswerPanel` 接管
- send 后 `resetSessionState`

---

## 二、热路径合同

| 热路径 | 当前 owner | 现有实现锚点 | 本轮结论 |
|--------|------------|--------------|----------|
| `onQuickAskStart` | `RecordingController` | `wireRecordingFeatureHotKeyCallbacks(...)` -> `QuickAskService.startSession()` | 仍由 Recording 热键桥接 Quick Ask，会话入口未改 public API |
| `onQuickAskSend` | `RecordingController` | `wireRecordingFeatureHotKeyCallbacks(...)` -> `QuickAskService.sendViaShortcut()` | 二次热键发送仍从 Recording 热键桥接进入 Quick Ask |
| 延迟录音失败路径 | `QuickAskService` | `startSession()` -> `runQuickAskServiceAfterDelay(...)` -> `startQuickAskRecording()` catch | 延迟启动与失败 HUD 语义未变，只把 runtime bridge 留在 helper 层 |
| cancel 中断路径 | `QuickAskService` | `cancelSession()` -> `stopRecording()` -> `hudManager.hide()` -> `resetSessionState()` | 取消链保持原顺序，不在本轮改写 |
| HUD 到 AnswerPanel 接管 | `QuickAskService` | `sendQuestion()` -> `hudManager.hide(restorePolicy: false)` -> `answerPanelManager.show(...)` | handoff 顺序保持不变，AnswerPanel 主试点已补 smoke |
| send 后 `resetSessionState` | `QuickAskService` | `sendQuestion()` 末尾 | send 完成后仍回到统一 reset 路径 |

---

## 三、复核要点

1. 这 6 条路径都不能因为 helper / assembler 外提而改 public API
2. `RecordingController` 只负责桥接热键进入 Quick Ask，不吞掉会话语义
3. `QuickAskService` 只做自身会话与 AnswerPanel handoff，不回流大而全事件模型

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-04-10
