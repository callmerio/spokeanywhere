# 执行任务清单：Architecture Optimization Roadmap v3

Active Plan: [v3](../docs/plans/2026-04-10-architecture-optimization-roadmap-v3.md)  
Archived Drafts:
- [v1](../docs/plans/archive/2026-04-10/2026-04-10-architecture-optimization-roadmap-v1.md)
- [v2](../docs/plans/archive/2026-04-10/2026-04-10-architecture-optimization-roadmap-v2.md)

## 执行顺序

```text
Wave 0
  AG-300 -> QG-300

Wave 1
  LIFE-310 -> RULE-320

Wave 2
  UI-330 -> UI-340
         -> UI-350

Wave 3
  ORCH-360 -> ORCH-370

Wave 4
  GOV-380 -> TEST-390
```

## Task List

### Wave 0：前置合同

- `AG-300` 统一事实真源与历史边界
  - 状态：已完成
  - 输出：事实真源/历史边界说明、architecture 同步清单
  - Evidence：`docs/architecture/fact-source-boundary.md`、`docs/architecture/current-state-audit.md`
  - Gate：当前事实真源明确，历史文档边界可追溯
  - Refs：`docs/plans/2026-04-10-architecture-optimization-roadmap-v3.md:105`

- `QG-300` 版本化质量门禁入口
  - 状态：已完成
  - 输出：统一门禁入口说明或脚本、失败分类、最小复现路径
  - Evidence：`scripts/verify/run-architecture-quality-gate.sh`、`docs/architecture/quality-gate.md`、`verify/quality-gate/20260409T192434Z/summary.md`
  - Gate：`swift build`、`swift test`、strict concurrency、shared/notification 扫描均可仓库内复现
  - Refs：`docs/plans/2026-04-10-architecture-optimization-roadmap-v3.md:115`

### Wave 1：生命周期与规则

- `LIFE-310` P1 生命周期 inventory 与 cleanup ownership
  - 状态：已完成
  - 范围：`AppDelegate`、`RecordingController`、`QuickAskService`、`MessagePanelManager`、`LiveCaptionManager`、`ScreenshotManager`
  - 输出：inventory、ownership/cleanup 矩阵
  - Evidence：`docs/architecture/p1-lifecycle-inventory.md`
  - Gate：P1 inventory 项全部可回答“谁注册、谁清理、在哪清理”
  - Refs：`docs/plans/2026-04-10-architecture-optimization-roadmap-v3.md:145`

- `RULE-320` 最小规则包
  - 状态：已完成
  - 输出：依赖通道最小规则、广播禁区、运行时状态/持久化状态最小分界
  - Evidence：`docs/architecture/minimal-rule-pack.md`、`docs/architecture/quick-reference.md`
  - Gate：能回答新协作者能否 `.shared`、新业务事件能否直接 `NotificationCenter`、新状态能否落现有存储
  - Refs：`docs/plans/2026-04-10-architecture-optimization-roadmap-v3.md:164`

### Wave 2：前台交互面试点

- `UI-330` coverage matrix + guardrail samples
  - 状态：已完成
  - 范围：`MessagePanelView`、`QuickAskCapsuleView` 作为回归守门样本
  - 输出：foreground interaction coverage matrix、guardrail smoke、pilot proof map
  - Evidence：`docs/architecture/foreground-interaction-coverage-matrix.md`、`Tests/UITests/SpokenAnyWhereUITests.swift`
  - Gate：已收口样本具备 repo-owned smoke，且不新增 UI `.shared`
  - Refs：`docs/plans/2026-04-10-architecture-optimization-roadmap-v3.md:203`

- `UI-340` Quick Ask answer path 主试点
  - 状态：已完成
  - 范围：`AnswerPanelView`
  - 输出：preview/fixture、interaction smoke、proof map
  - Evidence：`Tests/AnswerPanelPilotTests.swift`、`docs/architecture/answer-panel-pilot-proof-map.md`、`verify/quality-gate/20260409T194809Z/summary.md`
  - Gate：`open/close/focus/error/permission` 一致性可证明
  - Refs：`docs/plans/2026-04-10-architecture-optimization-roadmap-v3.md:217`

- `UI-350` Screenshot 完整交互链主试点
  - 状态：已完成
  - 范围：`ScreenshotWindow -> ScreenshotContentView -> ActionBar`
  - 输出：fixture/harness、interaction smoke、proof map
  - Evidence：`Tests/ScreenshotWindowInteractionTests.swift`、`docs/architecture/screenshot-pilot-proof-map.md`、`verify/quality-gate/20260409T195619Z/summary.md`
  - Gate：覆盖窗口链与截图主交互，不只是 action 层
  - Refs：`docs/plans/2026-04-10-architecture-optimization-roadmap-v3.md:220`

### Wave 3：Orchestrator 定向瘦身

- `ORCH-360` RecordingController 定向瘦身
  - 状态：已完成
  - 顺序：pure decision/context assembly -> runtime bridge -> callback wiring -> main file shrink
  - 输出：concern move list、命名 crosswalk、shared hot path contract
  - Evidence：`docs/architecture/recording-controller-concern-move-list.md`、`docs/architecture/shared-hot-path-contract.md`、`verify/quality-gate/20260409T200520Z/summary.md`
  - Gate：公开入口不变，每一步能单独 build/test/回滚
  - Refs：`docs/plans/2026-04-10-architecture-optimization-roadmap-v3.md:265`

- `ORCH-370` QuickAskService 定向瘦身
  - 状态：已完成
  - 顺序：prompt/context assembly -> runtime bridge -> callback wiring -> main file shrink
  - 输出：concern move list、行为矩阵
  - Evidence：`docs/architecture/quickask-service-behavior-matrix.md`、`docs/architecture/shared-hot-path-contract.md`、`verify/quality-gate/20260409T200520Z/summary.md`
  - Gate：覆盖 start/send/cancel/restart/follow-up 和 shared handoff
  - Refs：`docs/plans/2026-04-10-architecture-optimization-roadmap-v3.md:325`

### Wave 4：规则固化与复核

- `GOV-380` 依赖通道矩阵 + 状态 crosswalk + allowlist
  - 状态：已完成
  - 输出：依赖通道决策矩阵、状态落点 crosswalk、首批事件迁移 allowlist
  - Evidence：`docs/architecture/dependency-channel-decision-matrix.md`、`docs/architecture/quick-reference.md`
  - Gate：新增依赖/事件/状态都有标准路径，差量行为可约束
  - Refs：`docs/plans/2026-04-10-architecture-optimization-roadmap-v3.md:369`

- `TEST-390` Conditional Go 复核
  - 状态：已完成
  - 输出：复核记录，逐项对照旧 roadmap 5 条解冻条件
  - Evidence：`docs/architecture/conditional-go-review-2026-04-10.md`、`verify/quality-gate/20260409T201754Z/summary.md`
  - Gate：每项都有 `status + owner + evidence path`
  - Refs：`docs/plans/2026-04-10-architecture-optimization-roadmap-v3.md:416`

## 统一验证命令

```bash
swift build
swift test
bash Tests/run-concurrency-check.sh
rg -n "\\.shared\\." App Core Services UI
rg -n "NotificationCenter\\.default\\.(addObserver|post)" App Core Services UI
```
