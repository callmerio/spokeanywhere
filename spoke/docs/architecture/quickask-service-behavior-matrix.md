# QuickAskService 行为矩阵

**状态**: Active Reference
**更新时间**: 2026-04-10
**适用范围**: `ORCH-370`

---

## 一、Concern Move List

本轮保持 `QuickAskService` 的 public API 不变：

- `startSession()`
- `sendQuestion()`
- `cancelSession()`
- `restartRecording()`
- `sendViaShortcut()`

继续外提的 concern：

| concern | 之前位置 | 现在位置 | 命名家族 |
|---------|----------|----------|----------|
| HUD / follow-up callback wiring | `QuickAskService.setupHUDCallbacks()` | `QuickAskRuntimeHelpers.swift` -> `wireQuickAskHUDCallbacks(...)` | `*RuntimeHelpers` |
| audio callback session wiring | `QuickAskService.registerAudioCallbacks()` / `unregisterAudioCallbacks()` | `QuickAskRuntimeHelpers.swift` -> `wireQuickAskAudioCallbacks(...)` / `clearQuickAskAudioCallbacks(...)` | `*RuntimeHelpers` |
| OCR + screenshot context 收集 | `QuickAskService.sendQuestion()` 内联 | `Core/QuickAsk/QuickAskContextAssembler.swift` | `*Assembler` |
| prompt assembly | 先前已从主文件抽离 | `Core/QuickAsk/QuickAskPromptAssembler.swift` | `*Assembler` |

---

## 二、行为矩阵

| 行为 | 关键实现锚点 | 当前 proof |
|------|--------------|-----------|
| start session | `startSession()` + `runQuickAskServiceAfterDelay(...)` | `swift test` 全量通过；`QuickAskHUDWindowRuntimeTests` 保持窗口 runtime 语义 |
| send | `sendQuestion()` + `QuickAskContextAssembler` + `QuickAskPromptAssembler` | `QuickAskContextAssemblerTests.swift`、`AnswerPanelPilotTests.swift` |
| cancel | `cancelSession()` | 既有 `swift test` 全量通过，行为未改写 |
| restart | `restartRecording()` | `QuickAskStateTests.swift` 覆盖状态切换 |
| follow-up | `handleFollowUp(...)` | `QuickAskFollowUpRoutingTests.swift` |
| shared handoff | `sendQuestion()` -> `answerPanelManager.show(...)` | `AnswerPanelPilotTests.swift`、`shared-hot-path-contract.md` |

---

## 三、当前结果

- `QuickAskService.swift` 从 `606` 行降到 `584` 行
- 上下文收集、prompt 组装、callback wiring 不再全部挤在一个主文件里
- `QuickAskPromptAssembler`、`QuickAskLiveDependencies`、`QuickAskHUDWindowRuntime` 与 `QuickAskRuntimeHelpers` 形成更稳定的分工

---

## 四、共享热路径

共享热路径合同见：

- `./shared-hot-path-contract.md`

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-04-10
