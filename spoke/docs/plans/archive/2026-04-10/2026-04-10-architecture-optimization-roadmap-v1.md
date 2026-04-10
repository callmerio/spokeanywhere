# 2026-04 架构优化路线图 v1

版本：v1  
日期：2026-04-10  
状态：待 Review

## 1. 背景

当前 SpokenAnyWhere 在“可运行性”上没有明显阻断，构建、测试和 strict concurrency 基线都已具备；但从“可持续演进”角度看，系统仍然停留在 **Conditional Go** 区间。

现有主要问题不是“功能缺失”，而是“链路编排与依赖治理成本偏高”：

- `AppDelegate`、`RecordingController`、`QuickAskService`、`LiveCaptionManager`、`ScreenshotManager` 仍承担较重编排职责
- 依赖通道并存：`*.shared`、`NotificationCenter`、`ServiceContainer`
- 初始化和回调注册点仍然较分散，生命周期与释放策略不够统一
- 状态与持久化落点分散，虽然已有文档说明，但缺少统一的治理规则

本路线图目标不是“大重写”，而是在不破坏现有行为的前提下，走一条 **渐进式收敛** 路线，把架构从“能跑”推进到“更容易维护、替换、扩展和验证”。

## 2. 目标

### In Scope

- 统一依赖治理规则，冻结新增坏味道
- 收敛启动编排与核心 orchestrator 的职责
- 在录音链与 Quick Ask 链上做首批结构性收敛
- 为跨模块事件建立更明确的标准通道
- 明确状态和持久化边界，减少后续演进时的语义混装

### Out of Scope

- 一次性全面去单例化
- 大规模目录重构
- 新用户功能开发
- 对现有热键、窗口、数据格式做破坏式变更

## 3. 当前判断

### 已确认事实

- 项目当前主干可运行，`./dev.sh` 可成功构建、签名并拉起开发版应用
- 架构文档已有明确结论：当前状态仍属于 **Conditional Go**
- 仓库热点编排器体量较大：
  - `App/AppDelegate.swift`
  - `Services/ServiceContainer.swift`
  - `Services/RecordingController.swift`
  - `Services/QuickAskService.swift`
  - `Core/LiveCaption/LiveCaptionManager.swift`
  - `Core/Screenshot/ScreenshotManager.swift`
- 当前业务事件与依赖入口并未统一，既有 `NotificationCenter`，也有 `ServiceContainer`，也有直接 `.shared`

### 问题主轴

1. 顶层启动链过厚，应用启动、窗口装配、后台维护与权限/服务激活混杂
2. `RecordingController` 与 `QuickAskService` 内部仍混合了 session lifecycle、回调桥接、上下文采集、后处理与 UI 协调
3. `ServiceContainer` 已承担 DI 入口职责，但仍夹带较多 singleton 门面语义
4. 事件广播仍缺少统一模型，导致调用链可追踪性偏弱
5. 状态落点虽然多层并存，但尚未形成“新增状态必须先定语义归属”的规则

## 4. 分阶段路线

## Phase 1：依赖治理基线与热点 inventory

### 目标

先停止继续发散，而不是先大改。

### 工作内容

- 新增一份依赖治理规范文档，明确：
  - 哪些类型允许保留 singleton
  - 哪些业务服务必须通过 `ServiceContainer` 暴露
  - 哪些通知属于遗留或系统桥接，哪些新事件不允许再走裸 `NotificationCenter`
- 为以下热点链路建立统一 inventory：
  - 启动链：`AppDelegate`
  - 录音链：`RecordingController`
  - Quick Ask 链：`QuickAskService`
  - 实时字幕链：`LiveCaptionManager`
  - 截图链：`ScreenshotManager`
- 每条 inventory 至少包含：
  - 入口
  - 主要依赖
  - 回调/observer/timer/task 注册点
  - 状态持有者
  - 持久化触点
  - 测试 seam

### Phase Exit

- 团队对“推荐依赖入口”和“禁止新增模式”达成一致
- 后续重构不再以印象操作，而是有 inventory 可对照

## Phase 2：启动编排收敛

### 目标

把 `AppDelegate` 从“做所有事情的人”收敛成“执行启动计划的 runner”。

### 工作内容

- 在现有 `AppLifecyclePlan` 基础上补齐 step metadata：
  - `id`
  - `dependsOn`
  - `criticality`
  - `failurePolicy`
- 将启动行为按语义拆组：
  - `bootstrap`
  - `capability registration`
  - `ui/window wiring`
  - `background maintenance`
- `AppDelegate` 只负责：
  - 构造依赖
  - 执行 plan
  - 记录启动日志
  - 处理系统生命周期回调
- 把非关键步骤转成 best-effort 语义，避免未来继续在 `applicationDidFinishLaunching` 里堆逻辑

### Phase Exit

- 启动步骤可枚举、可排序、可分级
- `AppDelegate` 主体职责明显缩窄

## Phase 3：双主链路瘦身试点

### 目标

优先治理收益最高的两条链：录音链与 Quick Ask 链。

### RecordingController

建议拆为以下协作者：

- `RecordingSessionCoordinator`
- `RecordingInputBridge`
- `RecordingResultPipeline`
- `RecordingShortcutBindings`

主类继续保留原公开入口，不改外部行为：

- `start()`
- `stop()`
- `debugToggleRecording()`

### QuickAskService

建议拆为以下协作者：

- `QuickAskSessionCoordinator`
- `QuickAskContextCollector`
- `QuickAskPromptBuilder`
- `QuickAskAudioBridge`

主类继续保留原公开入口，不改外部行为：

- `startSession()`
- `sendQuestion()`
- `cancelSession()`
- `restartRecording()`
- `sendViaShortcut()`

### 约束

- runtime helper、timer、主线程桥接、observer 注册不回流 orchestrator 主文件
- 只做“主类变薄 + 协作者外提”，不做行为改写

### Phase Exit

- `RecordingController` 与 `QuickAskService` 体量和复杂度下降
- 公开 API 与用户体验保持不变

## Phase 4：事件模型统一

### 目标

不一刀切删除通知，而是先把业务事件纳入统一模型。

### 工作内容

- 新增轻量事件层：
  - `AppEvent`
  - `AppEventBusProtocol`
  - `DefaultAppEventBus`
- 规则：
  - 系统通知可以保留
  - 业务广播优先迁移到 typed event facade
- 首批迁移目标：
  - Quick Ask cancel/request
  - translation updated
  - tag deleted
  - transcription model changed
  - toolbar settings open

### Phase Exit

- 新业务事件有标准通道
- observer 生命周期可以被显式治理和测试

## Phase 5：状态与持久化边界固化

### 目标

让“状态该放哪”先有规则，再有实现。

### 建议语义分层

- `UserContent`
- `Settings`
- `Secrets`
- `CapabilityCache`
- `SystemRuntime`

### 工作内容

- 为新增状态建立落点决策表
- 明确以下边界：
  - `ScreenshotManager.saveAll()/restoreAll()` 只处理截图资产
  - `QuickAskState`、录音中间态、selected text 不做跨重启恢复
  - 新的 permission/blocked-intent 缓存不得复用历史/截图/会话存储

### Phase Exit

- 后续新状态不再“随手找地方存”
- 持久化语义和运行时语义边界更清晰

## 5. 接口与结构约束

### 保持不变的外部入口

- `RecordingController`
- `QuickAskService`
- `AppDelegate`
- `ServiceContainer`

### 计划新增的结构骨架

- `AppStartupStep`
- 扩展后的 `AppLifecyclePlan`
- `AppEvent`
- `AppEventBusProtocol`
- `DefaultAppEventBus`
- `RecordingSessionCoordinator`
- `RecordingInputBridge`
- `RecordingResultPipeline`
- `QuickAskSessionCoordinator`
- `QuickAskContextCollector`
- `QuickAskAudioBridge`

## 6. 验证与验收

### 测试与验证

- `swift build`
- `swift test`
- `bash Tests/run-concurrency-check.sh`
- `rg -n "\\.shared\\." App Core Services UI`
- `rg -n "NotificationCenter\\.default\\.(addObserver|post)" App Core Services UI`

### 验收标准

- 启动链从“方法堆叠”变为“显式 step plan”
- 录音链与 Quick Ask 链完成首轮协作者拆分，公开 API 不变
- 新事件不再继续扩散裸 `NotificationCenter`
- 新状态有统一归类规则

## 7. 与现有文档关系

本文件不替代历史路线图，而是作为当前会话产出的新版本计划，用于进一步 review 与收敛：

- 参考：`docs/roadmap/2026-03-conditional-go-architecture-roadmap.md`
- 参考：`docs/architecture/current-state-audit.md`
- 参考：`docs/architecture/risks-and-recommendations.md`
- 参考：`docs/architecture/overview.md`

## 8. Review 关注点

本次评审建议重点检查：

1. 是否仍有阶段顺序不合理或遗漏关键前置条件
2. 是否存在“目标太大但缺少切口”的阶段
3. 是否有新增结构命名过度抽象、脱离当前仓库模式
4. 是否缺少 rollout / 回归 / 文档同步方面的验收约束
5. 是否与已有 `Conditional Go` 路线图存在冲突、重复或优先级倒挂
