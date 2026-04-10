# SpokenAnyWhere 前台交互 Coverage Matrix

**状态**: Active Reference
**更新时间**: 2026-04-10
**适用范围**: `UI-330`

---

## 一、目的

本文件只回答两件事：

1. 哪些前台交互面已经有 repo-owned guardrail / pilot proof
2. 哪些面只是进入 coverage matrix，暂不在本轮主实施面

当前定位沿用 v3：

- `MessagePanelView`、`QuickAskCapsuleView`：回归守门样本
- `AnswerPanelView`、`ScreenshotWindow -> ScreenshotContentView -> ActionBarView`：主试点
- `LiveCaptionView`、`SelectionToolbarView`、`SettingsView`：deferred，仅进入 coverage matrix

---

## 二、Coverage Matrix

| Surface | 当前定位 | 入口 / 关键视图 | 现有 proof | UI `.shared` 直连 | 当前结论 |
|---------|----------|-----------------|------------|-------------------|----------|
| MessagePanel | Guardrail Sample | `UI/MessagePanel/MessagePanelView.swift` | `Tests/UITests/SpokenAnyWhereUITests.swift:testMessagePanelAccessibilityIdentifierSmoke` | 目标视图未命中新增 `.shared` 扫描 | 已具备 repo-owned guardrail smoke |
| Quick Ask Capsule | Guardrail Sample | `UI/HUD/QuickAskCapsuleView.swift` | `Tests/UITests/SpokenAnyWhereUITests.swift:testQuickAskCapsuleAccessibilityIdentifierSmoke`；`Tests/QuickAskHUDWindowRuntimeTests.swift` | 目标视图未命中新增 `.shared` 扫描 | 已具备 repo-owned guardrail smoke，且有窗口 runtime 证明 |
| AnswerPanel | Primary Pilot | `UI/QuickAsk/AnswerPanelView.swift` | `Tests/AnswerPanelPilotTests.swift`、`Tests/AnswerPanelManagerTests.swift`、`Tests/QuickAskFollowUpRoutingTests.swift`、`docs/architecture/answer-panel-pilot-proof-map.md` | 当前目标视图未命中新增 `.shared` 扫描 | 已具备 fixture + interaction smoke + proof map，open/close/focus/error/permission 可追溯 |
| Screenshot Full Interaction Unit | Primary Pilot | `UI/Screenshot/ScreenshotWindow.swift`、`UI/Screenshot/ScreenshotContentView.swift`、`UI/Screenshot/ActionBarView.swift` | `Tests/ScreenshotWindowInteractionTests.swift`、`Tests/AppScreenshotRuntimeTests.swift`、`Tests/ScreenshotManagerPerformanceTests.swift`、`Tests/UITests/SpokenAnyWhereUITests.swift:testScreenshotAccessibilityIdentifierSmoke`、`docs/architecture/screenshot-pilot-proof-map.md` | 当前目标视图未命中新增 `.shared` 扫描 | 已具备窗口链 smoke + save/restore proof + Quick Ask dispatch proof |
| Live Caption | Deferred / Matrix Only | `UI/LiveCaption/LiveCaptionView.swift` | `Tests/UITests/SpokenAnyWhereUITests.swift:testLiveCaptionAccessibilityIdentifierSmoke` | 不在本轮主试点 | 仅记录 coverage，不扩 scope |
| Selection Toolbar | Deferred / Matrix Only | `UI/SelectionToolbar/SelectionToolbarView.swift` | `Tests/SelectionToolbarActionDispatchTests.swift`（动作层） | 不在本轮主试点 | 动作层有测试，前台面仍 deferred |
| Settings | Deferred / Matrix Only | `UI/Settings/SettingsView.swift` | `Tests/SettingsWindowRuntimeTests.swift` | 不在本轮主试点 | 有窗口 runtime proof，但不进入本轮主试点 |

---

## 三、Pilot Proof Map

| Pilot / Sample | 最低证明要求 | 当前 evidence |
|----------------|--------------|--------------|
| `MessagePanelView` | 至少 1 条 repo-owned guardrail smoke | `Tests/UITests/SpokenAnyWhereUITests.swift:testMessagePanelAccessibilityIdentifierSmoke` |
| `QuickAskCapsuleView` | 至少 1 条 repo-owned guardrail smoke | `Tests/UITests/SpokenAnyWhereUITests.swift:testQuickAskCapsuleAccessibilityIdentifierSmoke` |
| `AnswerPanelView` | preview / fixture 可编译 + interaction smoke + open/close/focus/error/permission proof | `Tests/AnswerPanelPilotTests.swift`、`Tests/AnswerPanelManagerTests.swift`、`docs/architecture/answer-panel-pilot-proof-map.md` |
| `ScreenshotWindow -> ScreenshotContentView -> ActionBarView` | fixture / harness + interaction smoke + save/restore/action dispatch/window interaction proof | `Tests/ScreenshotWindowInteractionTests.swift`、`Tests/AppScreenshotRuntimeTests.swift`、`Tests/ScreenshotManagerPerformanceTests.swift`、`docs/architecture/screenshot-pilot-proof-map.md` |

---

## 四、Guardrail 结论

### 4.1 MessagePanel / QuickAskCapsule

- 两个 guardrail sample 都已经有 repo-owned smoke
- 两个目标视图在本轮 focus scan 中都没有新增 UI `.shared` 直连
- 因此本轮不再把它们升级成主试点，只作为回归守门样本

### 4.2 Deferred 面

- `LiveCaptionView`、`SelectionToolbarView`、`SettingsView` 进入 coverage matrix，但不进入本轮主实施面
- 原因不是“不重要”，而是当前主战场必须留给 `AnswerPanel` 与截图完整交互链

---

## 五、给 UI-340 / UI-350 的直接输入

1. `UI-340` 需要把 `AnswerPanelView` 从“manager/state 证明”提升到“前台交互证明”
2. `UI-350` 需要把截图从“windowFactory + content smoke”提升到“完整交互链证明”
3. `UI-330` 本身不新增 UI `.shared`；它的职责是把 guardrail sample 和主试点边界钉死

---

## 六、相关文档

- `./quick-reference.md`
- `./minimal-rule-pack.md`
- `../plans/2026-04-10-architecture-optimization-roadmap-v3.md`
- `../../tasks/2026-04-10-architecture-optimization-roadmap-v3-execution.md`

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-04-10
