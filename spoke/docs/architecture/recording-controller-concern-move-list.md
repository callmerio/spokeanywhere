# RecordingController Concern Move List

**状态**: Active Reference
**更新时间**: 2026-04-10
**适用范围**: `ORCH-360`

---

## 一、这次移动了什么

本轮没有改 `RecordingController` 的 public API：

- `start()`
- `stop()`
- `debugToggleRecording()`

只把仍粘在主文件里的两类 concern 继续外提：

1. callback wiring
2. session context assembly

---

## 二、Concern Move List

| concern | 之前位置 | 现在位置 | 命名家族 |
|---------|----------|----------|----------|
| HUD callback wiring | `RecordingController.setupHUDCallbacks()` | `RecordingControllerRuntimeHelpers.swift` -> `wireRecordingHUDCallbacks(...)` | `*RuntimeHelpers` |
| Quick Ask / MessagePanel / LiveCaption / Clipboard hotkey wiring | `RecordingController.setupQuickAskCallbacks()` / `setupMessagePanelCallbacks()` | `RecordingControllerRuntimeHelpers.swift` -> `wireRecordingFeatureHotKeyCallbacks(...)` | `*RuntimeHelpers` |
| Recording start/stop hotkey wiring | `RecordingController.setupHotKeyCallbacks()` | `RecordingControllerRuntimeHelpers.swift` -> `wireRecordingCaptureHotKeyCallbacks(...)` | `*RuntimeHelpers` |
| Audio callback session wiring | `RecordingController.setupAudioCallbacks()` | `RecordingControllerRuntimeHelpers.swift` -> `wireRecordingAudioCallbacks(...)` | `*RuntimeHelpers` |
| 当前录音会话上下文抓取 | `RecordingController.captureCurrentSession()` 内联组装 | `RecordingSessionContextAssembler.capture(...)` | `*Assembler` |

---

## 三、Naming Crosswalk

| 旧锚点 | 新锚点 | 说明 |
|--------|--------|------|
| `CapturedRecordingSession` | `RecordingCapturedSession` | 从主文件私有嵌套类型转为独立上下文载体 |
| `setupHUDCallbacks()` | `wireRecordingHUDCallbacks(...)` | wiring 从 orchestrator 主文件移出 |
| `setupQuickAskCallbacks()` + `setupMessagePanelCallbacks()` | `wireRecordingFeatureHotKeyCallbacks(...)` | feature hotkey bridge 合并到 helper 层 |
| `setupHotKeyCallbacks()` | `wireRecordingCaptureHotKeyCallbacks(...)` | recording start/stop wiring 外提 |
| `setupAudioCallbacks()` | `wireRecordingAudioCallbacks(...)` | callback session wiring 外提 |
| `captureCurrentSession()` 内联组装 | `RecordingSessionContextAssembler.capture(...)` | context assembly 外提 |

---

## 四、当前结果

- `RecordingController.swift` 从 `564` 行降到 `528` 行
- callback wiring 不再整块堆在主文件开头
- context assembly 不再和 orchestrator 状态混写在一起
- `RecordingTranscriptionDecision`、`RecordingControllerLiveDependencies`、`RuntimeBridgeHelpers` 这些既有抽取继续保留

---

## 五、共享热路径

共享热路径合同见：

- `./shared-hot-path-contract.md`

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-04-10
