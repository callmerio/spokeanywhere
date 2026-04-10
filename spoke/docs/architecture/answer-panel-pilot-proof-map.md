# SpokenAnyWhere AnswerPanel 主试点 Proof Map

**状态**: Active Reference
**更新时间**: 2026-04-10
**适用范围**: `UI-340`

---

## 一、试点目标

本试点只证明 `AnswerPanelView` / `AnswerPanelManager` 这条前台链路在当前仓库里已经有可追溯的最小证据，重点覆盖：

- open
- close
- focus
- error
- permission / settings escape hatch

---

## 二、Fixture / Smoke / Proof

| 行为 | 证据类型 | 证据路径 | 说明 |
|------|----------|----------|------|
| open | repo-owned interaction smoke | `Tests/AnswerPanelPilotTests.swift` | `show(...)` 会创建带 `UITestIdentifiers.Window.answerPanel` 的窗口 |
| close | repo-owned interaction smoke | `Tests/AnswerPanelPilotTests.swift` | `hide(panelId:)` 会关闭窗口并移除 panel state |
| focus | repo-owned interaction smoke | `Tests/AnswerPanelPilotTests.swift`、`UI/QuickAsk/AnswerPanelManager.swift` | 新建窗口是 `AnswerPanelWindow`，`canBecomeKey/canBecomeMain = true`，`show(...)` 会 `makeKeyAndOrderFront(nil)` |
| error | state proof | `Tests/AnswerPanelManagerTests.swift` | `showError(...)` 会把 error 写入对应 panel state 并结束 loading |
| permission / settings escape hatch | code path proof | `UI/QuickAsk/AnswerPanelView.swift`、`UI/QuickAsk/AnswerPanelViewLiveDependencies.swift` | Cmd+, 通过 `openSettings()` / `dependencies.openSettings` 进入设置，不把权限问题硬塞进面板状态机 |

---

## 三、当前 Fixture 说明

当前最小 fixture 使用：

- `AnswerPanelManager.makeTesting(...)`
- `AnswerPanelManager.installTestingPanel(...)`
- `AnswerPanelManager.show(...)`

这意味着当前主试点先用 manager-owned fixture 证明窗口创建、状态切换和关闭路径，不强行引入新的 UI 测试框架。

---

## 四、边界说明

- 本轮不新增 `AnswerPanelView` 的 UI `.shared` 直连
- `permission` 在当前试点里不是“系统权限弹窗本身”，而是“面板遇到权限/配置问题时能否稳定退回设置入口”
- 更细的按钮交互、附件拖拽、推荐问题点击，留给后续更细粒度的前台交互回归

---

## 五、相关文档

- `./foreground-interaction-coverage-matrix.md`
- `./minimal-rule-pack.md`
- `../plans/2026-04-10-architecture-optimization-roadmap-v3.md`

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-04-10
