# 2026-04 架构优化路线图 v2

版本：v2  
日期：2026-04-10  
状态：待 Review  
替代关系：**本文件替代旧 roadmap 的执行编排，但保留其 Conditional Go 解冻合同**

## 1. 背景

SpokenAnyWhere 当前的主要问题不是“功能缺口”，而是“系统演进成本偏高”。

现状已经比较明确：

- 项目可构建、可测试、可启动
- 架构结论仍是 **Conditional Go**
- 风险集中在：
  - 事实口径与门禁证据需要继续固化
  - 顶层生命周期与回调注册/释放规则仍不够统一
  - UI 高频面仍存在业务直连与注入边界不稳定的问题
  - `AppDelegate`、`RecordingController`、`QuickAskService` 等热点编排器仍较厚
  - 依赖通道仍是 `*.shared`、`NotificationCenter`、`ServiceContainer` 并存

本 v2 的目标是把这些问题压缩成一条 **渐进式收敛** 路线，不做一次性重写，但要求每一阶段都有清晰产物、验证方法和进入下一阶段的 gate。

## 2. 与现有路线的关系

### 2.1 继承关系

本文件继承以下文档的事实基线与解冻判断：

- `docs/architecture/current-state-audit.md`
- `docs/architecture/risks-and-recommendations.md`
- `docs/architecture/overview.md`
- `docs/roadmap/2026-03-conditional-go-architecture-roadmap.md`

### 2.2 本文件的作用

本文件：

- **替代** 旧 roadmap 的执行顺序
- **保留** 旧 roadmap 的核心解冻条件
- **补充** 计划级 gate、crosswalk 和阶段性验证合同

### 2.3 Crosswalk

| 旧路线 | v2 对应阶段 | 说明 |
|---|---|---|
| Phase 0：事实基线与门禁合同 | Phase 0 | 原样保留，作为所有后续阶段前置条件 |
| Phase 1：生命周期与回调治理 | Phase 1 | 前移并强化为结构重构前的必经阶段 |
| Phase 2：UI 依赖收敛试点 | Phase 2 | 保留为当前 blocker 的直接试点面 |
| Phase 3：治理固化与复核 | Phase 4 | 扩展为规则固化、事件迁移、状态边界与 Conditional Go 复核 |
| 旧路线未单独展开的 orchestrator 收敛 | Phase 3 | 新增为前两阶段之后的定向结构收敛 |

### 2.4 Deferred 项

以下内容仍不在本轮主线内：

- 全量去单例化
- 大规模目录重组
- 新用户功能开发
- 全面替换现有通知机制
- 重做现有数据格式或持久化介质

## 3. 目标与边界

### In Scope

- 固化事实基线与版本化质量门禁
- 统一生命周期、callback、observer、timer、task 的所有权与释放策略
- 在高频 UI 面上验证注入边界和 shared freeze 规则
- 对 `RecordingController`、`QuickAskService` 做有边界的瘦身
- 固化依赖通道决策矩阵、业务事件迁移规则与状态落点规则

### Out of Scope

- 任何破坏现有热键、窗口交互、数据格式的改动
- 同时并行大改 `LiveCaptionManager` 与 `ScreenshotManager`
- 先引入新抽象、再反向找落点的“架构先行”重写

## 4. 当前判断

当前仍应维持：

- 运行性：`Go`
- 可持续演进：`Conditional Go`

本路线图的成功标准不是“看起来更架构”，而是：

1. 先补齐解冻合同
2. 再消除当前 blocker
3. 最后才做更深的结构收敛

## 5. 分阶段路线

## Phase 0：事实基线与门禁合同

### 目标

恢复并明确旧 roadmap 的前置合同，避免后续所有治理再次漂移。

### 主要工作

- 固化 `current-state-audit.md` 为当前事实真源
- 明确历史验收/历史路线图的适用时间边界
- 版本化质量门禁入口：
  - `swift build`
  - `swift test`
  - `bash Tests/run-concurrency-check.sh`
  - shared/notification 扫描命令
- 记录失败分类、复现路径和最小执行说明

### Artifact

- 一份“事实真源与历史边界”说明
- 一份“质量门禁入口与失败分类”文档或脚本入口
- 对 `docs/architecture/*` 的同步清单

### Verification

- 相关文档能明确区分“当前事实”和“历史记录”
- 仓库内存在版本化门禁入口说明，不依赖口头约定
- 扫描命令可直接从文档复制执行

### Gate

如果事实真源、历史边界、版本化门禁入口三者缺任一项，不进入 Phase 1。

## Phase 1：生命周期与回调治理

### 目标

先解决“谁注册、谁清理、何时清理”的 ownership 问题，再做内部重构。

### 主要工作

- 为顶层服务建立生命周期 inventory，优先覆盖：
  - `AppDelegate`
  - `RecordingController`
  - `QuickAskService`
  - `MessagePanelManager`
  - `LiveCaptionManager`
  - `ScreenshotManager`
- 为 callback / observer / timer / task 建立统一字段：
  - owner
  - register point
  - cleanup point
  - shutdown dependency
  - failure mode
- 明确以下准则：
  - 新 callback 不允许只注册不定义释放路径
  - 新 observer 不允许依赖“对象 deinit 时也许会自动清理”作为主策略
  - 新 timer/task 必须有 owner 与 cancel point

### Artifact

- 生命周期与回调治理清单
- 顶层服务 ownership 矩阵
- 清理策略约定文档

### Verification

- 热点链路 inventory 至少覆盖 5 条主链
- 每条 inventory 至少包含 register/cleanup 对照
- 文档能回答每个热点对象“谁持有、谁清理、在哪清理”

### Gate

如果 `RecordingController` 和 `QuickAskService` 仍没有可审计的 register/cleanup 对照，不进入 Phase 2/3。

## Phase 2：UI 依赖收敛试点

### 目标

直接命中当前 Conditional Go blocker，用低风险试点验证注入边界与 shared freeze 规则。

### 试点范围

- `UI/MessagePanel/MessagePanelView.swift`
- `UI/HUD/QuickAskCapsuleView.swift`
- 截图域一个高频面：
  - `UI/Screenshot/ActionBarView.swift`
  - 或 `UI/Screenshot/ScreenshotContentView+Actions.swift`

### 主要工作

- 把高频视图依赖收口到：
  - `@Environment(\\.services)`
  - 或显式 façade / 协作者注入
- 冻结 UI 层新增 `*.shared`
- 为 preview / mock / review 提供更稳定的依赖入口

### Artifact

- 试点变更清单
- UI 注入边界规范
- shared freeze review 规则

### Verification

- 试点视图至少 2 个完成注入收敛
- 变更后不新增新的 UI 直连单例入口
- 相关 preview / 测试路径可使用显式依赖而不是硬绑真实环境

### Gate

如果少于 2 个高频视图完成试点，不进入 Phase 3。

## Phase 3：Orchestrator 定向瘦身

### 目标

在规则和试点都稳定后，再对最关键的两条主链做结构收敛。

### 作用范围

- `Services/RecordingController.swift`
- `Services/QuickAskService.swift`

### 主要工作

- 保留公开 API 与用户行为不变
- 沿现有仓库命名模式继续抽取：
  - `*Plan`
  - `*Decision`
  - `*Assembler`
  - `*RuntimeHelpers`
  - `*LiveDependencies`
  - `*Protocol`
- 仅当现有命名家族装不下时，才允许引入新的协作者命名
- 不预先承诺一串新类型名，避免计划层先发明架构层

### 约束

- 先抽 pure decision、context assembly、runtime bridge、callback wiring
- 不把 UI、持久化、timer、主线程桥接继续留在 orchestrator 主干
- 不在本阶段扩大到 `LiveCaptionManager` 和 `ScreenshotManager`

### Artifact

- `RecordingController` 收敛说明
- `QuickAskService` 收敛说明
- 抽取后的命名映射表

### Verification

- 公开 API 保持不变
- orchestrator 主文件职责比变更前更窄，且 diff 能指向明确抽取物
- 新抽取对象命名符合仓库现有模式

### Gate

如果需要靠新增“大而全抽象层”才能推进，则暂停本阶段，回退到规则重审，而不是硬做。

## Phase 4：依赖通道规则固化 + 有界事件迁移 + 状态边界

### 目标

把前面阶段验证过的规则固化下来，并据此完成一次 Conditional Go 复核。

### 主要工作

- 建立依赖通道决策矩阵：
  - direct call 适用场景
  - `NotificationCenter` 保留场景
  - `ServiceContainer` 适用场景
- 对首批业务事件做有界迁移，不追求一次性清零
- 固化状态落点规则，至少区分：
  - `UserContent`
  - `Settings`
  - `Secrets`
  - `CapabilityCache`
  - `SystemRuntime`
- 明确：
  - `ScreenshotManager.saveAll()/restoreAll()` 只处理截图资产
  - `QuickAskState`、录音中间态、selected text 不跨重启恢复
  - permission/blocked-intent 缓存不能混入现有历史/截图/会话存储

### Artifact

- 依赖通道决策矩阵
- 首批业务事件迁移清单
- 状态落点决策表
- Conditional Go 复核记录

### Verification

- 仓库文档能回答“新增依赖该走哪条通道”
- 首批事件迁移后，业务广播不再继续扩散裸模式
- 状态规则能覆盖新状态设计决策
- 复核记录能对照旧 roadmap 的解冻条件逐项说明

### Gate

若无法对旧 roadmap 的解冻条件逐项给出“已满足 / 未满足 / deferred”，则本阶段不算完成。

## 6. 统一验证命令

```bash
swift build
swift test
bash Tests/run-concurrency-check.sh
rg -n "\\.shared\\." App Core Services UI
rg -n "NotificationCenter\\.default\\.(addObserver|post)" App Core Services UI
```

## 7. 终局验收口径

本路线图完成后，至少需要能回答以下问题：

1. 当前事实真源是什么，哪些文档只是历史文档
2. 质量门禁如何在仓库内被证明，而不是只靠口头命令
3. 谁负责热点服务的注册与清理
4. 两个以上高频 UI 面是否已验证注入边界
5. `RecordingController` 与 `QuickAskService` 是否在不改外部行为的前提下变薄
6. 新增依赖、事件、新状态该走哪条标准路径
7. 当前是否仍应维持 `Conditional Go`，若是，剩余 blocker 是什么

## 8. 命名与抽取约束

本计划不预设一串必须落地的新类型名，而采用约束式命名策略：

- 优先复用现有语义家族：
  - `*Plan`
  - `*Decision`
  - `*Assembler`
  - `*RuntimeHelpers`
  - `*LiveDependencies`
  - `*Protocol`
  - `*Manager`
  - `*Service`
- 如果已有语义家族能表达，就不引入新抽象词
- 若确需新增命名家族，必须在实现前先解释为何现有命名装不下

## 9. 本轮 Review 关注点

下一轮 review 重点看四件事：

1. Phase 0 是否已经足够具体，可以作为后续阶段前置 gate
2. 生命周期治理是否真的被前移，而不是换个说法继续后置
3. UI 试点是否已经重新接回 Conditional Go blocker 主线
4. phase artifact / verification / gate 是否已经达到“可执行合同”级别
