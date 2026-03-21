# 2026-03 Conditional Go 收敛路线图

版本：v1  
日期：2026-03-19  
状态：待执行

## 1. 背景

本路线图基于以下文档整理：

- `docs/architecture/current-state-audit.md`
- `docs/architecture/risks-and-recommendations.md`
- `docs/architecture/app-layer-risk-assessment.md`

当前结论已经明确：

1. 代码可运行，且本地已复算 `swift test` 与 strict concurrency 通过。
2. 项目仍属于 **Conditional Go**，主要短板不在“能不能跑”，而在“能不能稳定演进”。
3. 风险集中在四个方向：
   - 文档漂移
   - 单例密度与生命周期治理
   - UI 直连业务层
   - 自动化门禁缺少版本化证据

本路线图的目标，不是继续泛化“建议”，而是把这些结论压缩成一组可执行、可验收、可排期的 issue。

## 2. 目标

### In Scope

- 固化当前事实基线，避免文档再次漂移
- 让质量门禁从“本地知道怎么跑”升级为“仓库内有版本化入口”
- 治理 App / Services 的生命周期与回调清理风险
- 在截图、Message Panel、Quick Ask 三个高频面上试点依赖收敛
- 建立依赖通道决策矩阵，并对 UI 新增 `*.shared` 做冻结治理

### Out of Scope

- 新产品功能开发
- 全面去单例化
- 大规模 UI 重构
- 替代现有 `R2-3 Option D` 的 XCTest UI 正式化路线

## 3. 与现有路线的关系

### 3.1 与质量稳定性 PRD 的关系

`tasks/prd-quality-stability-optimization.md` 更偏“质量与稳定性收敛”主线；本路线图则是其后续的“架构治理与 Conditional Go 收敛”分支。

### 3.2 与 UI 自动化路线的关系

`docs/roadmap/r2-3-option-d-xcuitest-plan.md` 关注 UI 自动化正式化。本路线图优先解决当前架构与门禁治理问题，为后续 UI 自动化阻断项提供更稳定底座。

## 4. 分期路线

## Phase 0：事实基线与门禁合同（建议 2-3 天）

### AG-010 统一事实基线与历史口径边界

- 固化 `current-state-audit.md` 作为当前事实真源
- 明确历史验收文档与当前状态的边界
- 建立架构文档更新时的同步清单

### QG-010 版本化质量门禁入口

- 将 `swift test` 与 `bash Tests/run-concurrency-check.sh` 升级为仓库内可引用的统一质量门禁入口
- 不预设 CI 平台，但必须把入口、失败分类和本地复现路径版本化

**Phase Exit**:

- 团队对“当前事实真源”达成一致
- 仓库内存在版本化的质量门禁入口说明或脚本

## Phase 1：生命周期与回调治理（建议 1 周）

### APP-010 启动级联与服务生命周期协议

- 为顶层服务建立显式生命周期协议或等效约定
- 收敛 `AppDelegate` 对启动/终止清理的分散管理

### APP-020 回调注册与清理治理

- 审计音频、热键、通知等回调注册点
- 为 callback / observer / timer / task 建立释放策略

**Phase Exit**:

- 顶层服务的启动与清理边界可审计
- 关键回调链路不再依赖“隐式不泄漏”的假设

## Phase 2：UI 依赖收敛试点（建议 1-2 周）

### ARCH-010 截图域 façade 试点

- 优先收敛 `ActionBarView` 与 `ScreenshotContentView+Actions`
- 将高频动作改走单一 façade，而不是让视图直接调用多个单例

### ARCH-020 MessagePanel 注入试点

- 在 `MessagePanelView` 上试点 `@Environment(\.services)` 或等效注入边界
- 优先替换高频读写与管理器调用

### ARCH-030 QuickAskCapsule 注入试点

- 在 `QuickAskCapsuleView` 上试点可注入的附件/Workflow/发送协作者
- 先做最小可行切口，不追求一次性改完所有直连

**Phase Exit**:

- 三个试点文件中新增直连单例被遏制
- 至少两个高频视图具备 mock / preview 级注入能力

## Phase 3：治理固化与复核（建议 3-5 天）

### GOV-010 依赖通道决策矩阵与 shared freeze

- 明确哪些场景走 direct call、哪些走 `NotificationCenter`、哪些走 `ServiceContainer`
- 对 UI 层新增 `*.shared` 依赖建立 diff-scope 提示或 review 规则

### TEST-010 架构回归与 Conditional Go 复核

- 复跑质量门禁
- 复核文档、依赖策略、试点结果
- 判断是否从“Conditional Go”向更强结论推进

**Phase Exit**:

- 决策矩阵落地
- 新增 shared 直连有治理规则
- 本轮 issue 结果能支撑一次正式复核

## 5. Issue 清单概览

| ID | Priority | Phase | 标题 | 说明 |
|----|----------|-------|------|------|
| AG-010 | P1 | 0 | 统一事实基线与历史口径边界 | 让 audit 成为现状真源 |
| QG-010 | P0 | 0 | 版本化质量门禁入口 | 让门禁从“会跑”变成“仓库内可证明” |
| APP-010 | P1 | 1 | 启动级联与服务生命周期协议 | 收敛服务启停与清理边界 |
| APP-020 | P1 | 1 | 回调注册与清理治理 | 收敛 callback / observer / timer / task |
| ARCH-010 | P1 | 2.1 | 截图域 façade 试点 | 收敛截图域高频 UI 直连 |
| ARCH-020 | P1 | 2.2 | MessagePanel 注入试点 | 在高频面试点服务注入 |
| ARCH-030 | P1 | 2.3 | QuickAskCapsule 注入试点 | 在输入面试点协作者注入 |
| GOV-010 | P1 | 3 | 依赖通道决策矩阵与 shared freeze | 固化架构规则 |
| TEST-010 | P1 | 3.1 | 架构回归与 Conditional Go 复核 | 形成闭环验收 |

## 6. 排序原则

1. 先做 `AG-010` / `QG-010`，因为没有事实基线与门禁合同，后续 issue 容易口径漂移。
2. 再做 `APP-010` / `APP-020`，因为生命周期与回调治理是 App 层 P1 风险。
3. 然后进入三个试点 issue，控制改动面，验证收益。
4. 最后做治理固化与复核，避免先下规则、后补事实。

## 7. 交付物

- 路线图文档：本文
- issue 快照：`issues/2026-03-19_20-55-00-conditional-go-architecture.csv`
- 事实基线：`docs/architecture/current-state-audit.md`
- 风险依据：`docs/architecture/risks-and-recommendations.md`

## 8. 解冻条件

满足以下条件后，才适合讨论是否把结论从 `Conditional Go` 进一步前推：

1. 版本化质量门禁入口已落地
2. 顶层生命周期与关键回调清理已显式治理
3. 两个以上高频视图完成注入试点并通过回归
4. 依赖通道决策矩阵已写入文档并进入 review 流程
5. 重新复跑 `swift test` 与 strict concurrency 检查仍保持绿色

---

相关路线：

- `./r2-3-option-d-xcuitest-plan.md`
- `../../tasks/prd-quality-stability-optimization.md`
