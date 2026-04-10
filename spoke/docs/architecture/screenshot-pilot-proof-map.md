# SpokenAnyWhere Screenshot 主试点 Proof Map

**状态**: Active Reference
**更新时间**: 2026-04-10
**适用范围**: `UI-350`

---

## 一、试点目标

本试点要证明的不是“截图管理器某个函数能跑”，而是：

- `ScreenshotWindow`
- `ScreenshotContentView`
- `ActionBarView`

这三个环节组成的窗口链，已经具备最小可追溯的交互证据。

---

## 二、最小行为与证据

| 行为 | 证据类型 | 证据路径 | 说明 |
|------|----------|----------|------|
| save / restore | runtime + persistence proof | `App/AppScreenshotRuntime.swift`、`Tests/AppScreenshotRuntimeTests.swift`、`Tests/ScreenshotManagerPerformanceTests.swift` | 现阶段先用 runtime restore hook + JSON round-trip/perf 证明 pinned 资产可保存与恢复 |
| action dispatch | repo-owned interaction smoke | `Tests/ScreenshotWindowInteractionTests.swift` | `p / a / q` 快捷键沿窗口链触发 Pin / Quick Ask / Close |
| window interaction | repo-owned interaction smoke | `Tests/ScreenshotWindowInteractionTests.swift`、`Tests/AppScreenshotRuntimeTests.swift` | 窗口实例存在、frame callback 绑定、生效的 collection behavior 切换 |
| keyboard shortcuts | repo-owned interaction smoke | `Tests/ScreenshotWindowInteractionTests.swift`、`UI/Screenshot/ScreenshotWindow.swift` | `p / a / q` 来自 `ScreenshotWindow.keyDown(with:)` |
| Quick Ask dispatch | repo-owned interaction smoke | `Tests/ScreenshotWindowInteractionTests.swift`、`UI/Screenshot/ScreenshotContentView+Actions.swift` | `triggerQuickAsk()` 走注入依赖而不是硬编码 `.live` |

---

## 三、当前试点边界

- 本轮主试点只要求证明窗口链最小行为
- 不要求在这一轮把 OCR、增强、所有右键菜单项都纳入 hard smoke
- `save / restore` 当前仍以 runtime hook + round-trip/perf 作为最小证明，不把它扩成重型 UI 自动化

---

## 四、关键修正

本轮为了让窗口链真正可测，做了一个边界修正：

- `ScreenshotContentView+Actions.swift` 不再直接回退到 `.live`
- 动作链统一改走 `ScreenshotContentView` 自身持有的注入 `dependencies`

这意味着：

- `ScreenshotWindow` 的快捷键可以真正驱动被注入的 `togglePin / startQuickAsk / closeWindow`
- 测试不再只是“窗口存在”，而是能验证完整交互链确实穿过去

---

## 五、相关文档

- `./foreground-interaction-coverage-matrix.md`
- `./minimal-rule-pack.md`
- `../plans/2026-04-10-architecture-optimization-roadmap-v3.md`

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-04-10
