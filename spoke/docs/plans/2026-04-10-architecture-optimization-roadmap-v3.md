# 2026-04 架构优化路线图 v3

版本：v3  
日期：2026-04-10  
状态：Active Plan  
替代关系：**本文件替代旧 roadmap 的执行编排，但保留其 Conditional Go 解冻合同**

## 1. North Star

这轮计划不以“架构更好看”为成功标准，而以两个结果为北极星：

1. **团队在最常改的两条用户链路上改得更快**
   - 优先链路：`Quick Ask answer path`、`Recording -> Quick Ask` 共享热路径
2. **团队在前台交互面上改得更稳**
   - 重点看：依赖替换、preview/fixture、回归 smoke、浮窗交互一致性

如果阶段产物不能明显改善这两件事，这轮治理应停止，而不是继续扩 scope。

### Proxy Metrics

为避免“更快 / 更稳”退化成主观判断，本计划使用以下代理指标：

- P1 inventory 中 `ownership unknown = 0`
- UI 层 `net-new .shared = 0`
- 每个主试点至少 `1` 条 repo-owned smoke 证明
- 每个主试点都有明确 proof map，指向具体 preview / fixture / harness / smoke 载体
- Phase 3 后公开入口变更数 `= 0`
- Phase 4 复核模板中 5 条解冻条件必须逐项落 `status + owner + evidence path`

## 2. 当前问题定义

SpokenAnyWhere 当前不是“功能做不出来”，而是：

- 热点链路改动成本偏高
- 生命周期与 callback 清理责任分散
- 前台 UI 面的注入边界和回归方式不统一
- 规则仍落后于实现，导致后续重构自由度过高

当前判断继续维持：

- 运行性：`Go`
- 可持续演进：`Conditional Go`

## 3. 与现有路线关系

### 3.1 继承的事实真源

- `docs/architecture/current-state-audit.md`
- `docs/architecture/risks-and-recommendations.md`
- `docs/architecture/overview.md`
- `docs/roadmap/2026-03-conditional-go-architecture-roadmap.md`

### 3.2 关系声明

本文件：

- **替代** 旧 roadmap 的执行顺序
- **保留** 旧 roadmap 的解冻条件
- **补充** 更硬的 phase gate、crosswalk、timebox、kill criteria

### 3.3 Crosswalk

| 旧路线 | v3 对应阶段 | 说明 |
|---|---|---|
| Phase 0：事实基线与门禁合同 | Phase 0 | 原样保留，且设为硬前置 |
| Phase 1：生命周期与回调治理 | Phase 1 | 保留并增强，追加最小规则包 |
| Phase 2：UI 依赖收敛试点 | Phase 2 | 保留，但重选试点对象 |
| Phase 3：治理固化与复核 | Phase 4 | 扩展为规则固化、状态边界、Conditional Go 复核 |
| 旧路线未展开的 orchestrator 收敛 | Phase 3A / 3B | 新增为定向瘦身，不再混成一个大阶段 |

## 4. 主战场与范围

### Primary Battlefront

本轮唯一主战场是：

- `Quick Ask answer path`
- 与其共享的 `Recording -> Quick Ask` 编排热路径

原因：

- 这是近期最容易频繁调整、又最容易跨 UI / service / runtime boundary 漂移的链路
- 它能代表当前仓库最典型的 orchestrator、依赖注入、前台交互和后处理问题

### Secondary Validation Surface

本轮 secondary surface 是：

- 完整截图交互链：`ScreenshotWindow -> ScreenshotContentView -> ActionBar`

用途不是扩大主战场，而是验证 UI 注入规则是否能在另一条窗口型交互链路上落地。

### Deferred

以下对象只进 coverage matrix，不进本轮主实施面：

- `LiveCaptionView`
- `SelectionToolbarView`
- `SettingsView`
- `MessagePanelView` 作为已部分收口面的回归守门样本，不再作为主要突破口
- `QuickAskCapsuleView` 作为已部分收口面的回归守门样本，不再单独作为主试点

## 5. 分阶段路线

## Phase 0：事实基线与门禁合同

### Timebox

`1-2 天`

### 目标

建立最低必要合同，不让后续阶段继续建立在漂移事实之上。

### 主要工作

- 固化当前事实真源与历史边界
- 版本化质量门禁入口与失败分类
- 记录最小复现路径

### Artifact

- 事实真源 / 历史边界说明
- 门禁入口说明或统一脚本
- architecture 文档同步清单

### Verification

- 文档能明确区分“当前事实”和“历史记录”
- build/test/concurrency/shared/notification 检查入口可直接复制执行

### Gate

以下两项缺任一项，不进入 Phase 1：

- 当前事实真源
- 版本化质量门禁入口

历史边界说明可在 Phase 0 主体完成后并行补齐，但必须在 Phase 4 前收口。

### Kill Criteria

超过 `2 天` 仍不能完成上述两项硬前置，则停止推进并重估 Phase 0 范围，不进入 Phase 1。

## Phase 1：生命周期与最小规则包

### Timebox

`2-3 天`

### 目标

先锁定 ownership，再锁定最小规则包，避免后续瘦身时自由发挥。

### 主要工作

- 对以下 P1 inventory 做 lifecycle / register / cleanup 审计：
  - `AppDelegate`
  - `RecordingController`
  - `QuickAskService`
  - `MessagePanelManager`
  - `LiveCaptionManager`
  - `ScreenshotManager`
- 产出最小规则包：
  - 新抽取协作者允许的依赖通道
  - 禁止新增的业务广播模式
  - 运行时状态与持久化状态的最小分界

### Artifact

- P1 生命周期 inventory
- ownership / cleanup 矩阵
- 最小依赖通道规则
- 最小状态边界规则

### Verification

- 每个 P1 inventory 项都有 owner、register point、cleanup point
- `AppDelegate` 与 5 个热点对象均可回答“谁注册、谁清理、在哪清理”
- 最小规则包能回答：
  - 新协作者能不能直接 `.shared`
  - 新业务事件能不能直接 `NotificationCenter`
  - 新状态能不能落到现有存储

### Gate

只有在 `AppDelegate` + 全部 P1 inventory 项完成审计，或明确标记 `deferred + reason + residual risk` 后，才进入 Phase 2 / 3。

### Kill Criteria

如果 Phase 1 结束时最小规则包仍无法约束新抽取对象，暂停后续瘦身，先重写规则而不是进入 Phase 3。

## Phase 2：前台交互面试点

### Timebox

`3-5 天`

### 目标

验证注入边界、preview/fixture、浮窗交互一致性，而不是只做“UI 依赖卫生”。

### 试点选择依据

| 面 | 角色 | 本轮定位 |
|---|---|---|
| `MessagePanelView` | 已部分收口 | 回归守门样本 |
| `QuickAskCapsuleView` | 已部分收口 | 回归守门样本 |
| `AnswerPanelView` | Quick Ask 主体验面 | 主试点 |
| `ScreenshotWindow -> ScreenshotContentView -> ActionBar` | 完整窗口链 | 主试点 |
| `LiveCaptionView` | 高频面 | deferred，进入 coverage matrix |
| `SelectionToolbarView` | 高频面 | deferred，进入 coverage matrix |
| `SettingsView` | 稳定入口 | deferred，进入 coverage matrix |

### 主要工作

- Quick Ask 试点从“胶囊入口”提升到完整 answer path：
  - `QuickAskCapsuleView` 只做回归守门
  - `AnswerPanelView` 进入主试点
- 截图试点按完整交互单元治理：
  - 不只改 action extension
  - 要覆盖 window/content/action 的依赖边界
- 新增前台交互 coverage matrix：
  - MessagePanel
  - Quick Ask answer path
  - Screenshot full interaction unit
  - LiveCaption
  - SelectionToolbar
  - Settings

### Artifact

- 试点选择依据表
- foreground interaction coverage matrix
- UI 注入边界规范
- preview / fixture / smoke 合同
- pilot proof map

### Verification

- 至少 `1 个回归守门样本 + 2 个主试点` 达成 contract
- 每个主试点都具备：
  - 可编译 preview 或 fixture
  - 至少 1 条 interaction smoke
  - open / close / focus / error / permission 一致性检查
- UI 层 `net-new .shared = 0`

### Pilot Proof Map

| Pilot | 证据形态 | 最低证明要求 |
|---|---|---|
| `AnswerPanelView` | preview + smoke | preview/fixture 可编译，且有 1 条 repo-owned smoke |
| `ScreenshotWindow -> ScreenshotContentView -> ActionBar` | fixture/harness + smoke | 有窗口链 harness 或 fixture，且有 1 条 repo-owned smoke |
| `MessagePanelView` | guardrail smoke only | 作为已收口样本，需有 guardrail smoke |
| `QuickAskCapsuleView` | guardrail smoke only | 作为已收口样本，需有 guardrail smoke |

### Gate

如果 `AnswerPanelView` 或完整截图交互单元任一未达标，不进入 Phase 3。

### Kill Criteria

如果试点只改善依赖写法，但没有改善 preview/fixture/smoke 稳定性，则停止后续规则固化，重新评估主战场。

## Phase 3A：RecordingController 定向瘦身

### Timebox

`2-4 天`

### 目标

先拆一条 orchestrator，保持 unit 可回滚。

### 顺序

1. pure decision / context assembly
2. runtime bridge
3. callback wiring
4. main file shrink

### 约束

- 公开入口不变
- 只允许沿现有命名家族抽取：
  - `*Plan`
  - `*Decision`
  - `*Assembler`
  - `*RuntimeHelpers`
  - `*LiveDependencies`
  - `*Protocol`

### Artifact

- Recording 抽取顺序说明
- concern move list
- 命名 crosswalk
- shared hot path contract

### Verification

- 公开入口清单不变
- 必须移出的 concern 列表已脱离主文件：
  - pure decision
  - context assembly
  - runtime bridge
  - callback wiring
- 每一步都能单独 build/test/回滚

### Shared Hot Path Contract

以下共享热路径必须单列验证，不能只拆成 Recording / Quick Ask 各自通过：

- `onQuickAskStart`
- `onQuickAskSend`
- 延迟录音失败路径
- cancel 中断路径
- HUD `hide(restorePolicy: false)` 到 `AnswerPanel` 接管
- send 后 `resetSessionState`

### Gate

若任一步需要引入新的“大而全抽象层”或无法单步回滚，则停止 3A。

## Phase 3B：QuickAskService 定向瘦身

### Timebox

`2-4 天`

### 目标

在 3A 经验基础上，再拆 Quick Ask 主编排器。

### 顺序

1. prompt / context assembly
2. runtime bridge
3. callback wiring
4. main file shrink

### 约束

- 公开入口不变
- 复用已有 `QuickAskPromptAssembler` 语义，不新增重叠命名
- 不在本阶段新增新的事件通道模型

### Artifact

- Quick Ask 抽取顺序说明
- concern move list
- 行为矩阵

### Verification

- 覆盖最小行为矩阵：
  - start session
  - send
  - cancel
  - restart
  - follow-up
- 覆盖 shared hot path contract
- 每一步都能单独 build/test/回滚

### Gate

若 Quick Ask 抽取需要先重写事件模型或状态模型，暂停 3B，回退到 Phase 4 规则重审。

## Phase 4：规则固化 + 状态 crosswalk + Conditional Go 复核

### Timebox

`2-3 天`

### 目标

把经 Phase 1-3 验证过的规则固化下来，并对照旧 roadmap 做正式复核。

### 主要工作

- 输出依赖通道决策矩阵：
  - direct call
  - `NotificationCenter`
  - `ServiceContainer`
- 输出状态落点 crosswalk：
  - `UserContent`
  - `Settings`
  - `Secrets`
  - `CapabilityCache`
  - `SystemRuntime`
  - 对应映射到：
    - `SwiftData`
    - `Application Support`
    - `AppStorage / UserDefaults`
    - `Keychain`
    - runtime-only objects
- 点名首批业务事件迁移清单，不写模糊的“首批”

### Artifact

- 依赖通道决策矩阵
- 状态落点 crosswalk
- 首批事件迁移 allowlist / target list
- Conditional Go 复核记录

### Verification

- 文档能回答新增依赖/事件/状态该走哪条路径
- UI 层 `net-new .shared = 0`
- 新增 `NotificationCenter` 使用必须落在 allowlist
- 复核记录逐项对照旧 roadmap 解冻条件：
  - 已满足
  - 未满足
  - deferred

### Conditional Go Review Template

| 解冻条件 | Status | Owner | Evidence Path |
|---|---|---|---|
| 版本化质量门禁入口已落地 |  |  |  |
| 顶层生命周期与关键回调清理已显式治理 |  |  |  |
| 两个以上高频前台面完成试点并有回归证据 |  |  |  |
| 依赖通道决策矩阵已进入文档与 review 流程 |  |  |  |
| `swift test` 与 strict concurrency 继续保持绿色 |  |  |  |

### Gate

若不能逐项给出旧解冻条件的状态，就不算完成。

### Kill Criteria

若 Phase 4 只能写规则文档，不能约束差量行为，则本阶段降级为“记录现状”，不宣称治理完成。

## 6. 统一验证命令

```bash
swift build
swift test
bash Tests/run-concurrency-check.sh
rg -n "\\.shared\\." App Core Services UI
rg -n "NotificationCenter\\.default\\.(addObserver|post)" App Core Services UI
```

## 7. 最小行为矩阵

本轮至少覆盖以下行为回归：

| 链路 | 最小行为 |
|---|---|
| Recording | start / stop / post-process |
| Quick Ask | start / send / cancel / restart / follow-up / shared handoff |
| Screenshot | save / restore / action dispatch / window interaction / `Cmd+C/T` / `P/M/A/Q` / hover show-hide debounce / pin-unpin / Quick Ask dispatch / Live Text fallback |
| UI frontmost behavior | open / close / focus / error / permission |

## 8. 终局验收口径

最终必须能明确回答：

1. 当前事实真源是什么
2. 门禁如何在仓库内被证明
3. 谁负责热点对象的注册与清理
4. 哪些前台交互面已验证、哪些只是回归守门、哪些 deferred
5. `RecordingController` 与 `QuickAskService` 是否按可回滚 unit 完成瘦身
6. 新增依赖、事件、新状态的标准路径是什么
7. 当前是否仍维持 `Conditional Go`，剩余 blocker 是什么
