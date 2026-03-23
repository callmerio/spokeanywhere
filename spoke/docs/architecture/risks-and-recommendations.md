# SpokenAnyWhere 风险评估与改进建议

**版本**: 1.2
**更新时间**: 2026-03-22
**结论**: **Conditional Go**

---

## 一、执行摘要

本次以当前仓库快照和 **2026-03-22** 的本地复算为基线，结论如下：

- ✅ **代码可运行性**: Go
  - `swift test` 通过，结果为 `150 tests / 30 suites`
  - `bash Tests/run-concurrency-check.sh` 通过，结果为 `0 warnings`
- ⚠️ **质量治理**: Conditional Go
  - 仓库中未发现版本化 `.github/workflows/*`，无法仅凭仓库内容证明自动化门禁已落地
- ⚠️ **架构可维护性**: Conditional Go
  - 单例密度高
  - UI 直连业务层较多
  - `NotificationCenter` / 直接调用 / `ServiceContainer` 三通道并存
- ⚠️ **文档一致性**: Conditional Go
  - 历史口径与当前现状之间存在偏差
  - 旧文档引用了当前不存在的路径

---

## 二、当前已验证事实

### 2.1 本地质量基线

复算命令：

```bash
swift test
bash Tests/run-concurrency-check.sh
```

结果：

- 测试：`150 tests / 30 suites` 通过
- 严格并发检查：`0 warnings`

### 2.2 当前仓库事实

- `Package.swift` 仍是唯一构建清单
- `docs/architecture/` 为架构文档主目录
- 当前仓库未发现：
  - `.github/workflows/test.yml`
  - `.github/workflows/perf-startup.yml`
  - `docs/style/INDEX.md`

这些缺失不代表项目无法构建，但意味着旧文档中有关自动化与导航的部分已经失真。

---

## 三、风险清单

### 3.1 文档漂移风险

**现状**:

- 历史验收文档仍保留 `122/122 tests` 口径
- 旧导航文档引用仓库不存在的路径
- `core-modules.md` 与 `ui-components.md` 未覆盖全部真实模块

**影响**:

- 新成员容易误判当前能力边界
- 容易把历史结论当成现状
- 排障与二次开发定位成本增加

### 3.2 单例密度风险

**现状**:

- `RecordingController` 聚合多个核心服务
- `AppDelegate` 启动阶段会触发多条单例初始化链
- 多数高频功能仍以 `*.shared` 作为主调用入口

**当前缓解进展**:

- `RecordingController` 已抽出 `RecordingTranscriptionDecision`，把转写后的结果决策从 orchestrator 主流程中分离。
- `AppDelegate` 已抽出 `AppLifecyclePlan`，将启动/关闭顺序固定为可测试 plan，而不是继续在方法里手写数组。
- `QuickAskService` 已抽出 `QuickAskPromptAssembler`，减少 prompt 组装与运行时编排耦合。
- `SelectionMonitorService` 已抽出 live/runtime helper，减少 debounce / AX bridge 的主文件噪音。
- `WorkflowExecutor` 已抽出 `WorkflowProfileResolver` 并新增表征测试，profile fallback 不再直接写在 executor 主体里。
- `QuickAskLiveDependencies` 与 `RecordingControllerLiveDependencies` 已完成一轮 live factory 收敛，当前主文件不再保留成组 `*.shared` / `NSApp.sendAction` 内联样板。

**影响**:

- 初始化顺序隐式
- 测试替换与依赖隔离困难
- 故障排查容易跨层扩散

### 3.3 UI 直连业务风险

**现状**:

- `MessagePanelView`
- `QuickAskCapsuleView`
- `LiveCaptionView`
- `ActionBarView`
- `ScreenshotContentView`

这些高频视图仍直接访问 Service/Core 单例。

**影响**:

- 预览与单测难以脱离真实环境
- UI 改动容易引入业务副作用
- 依赖边界不易收敛

### 3.4 依赖通道混用风险

**现状**:

仓库内同时存在：

- `*.shared` 直接调用
- `NotificationCenter` 事件总线
- `ServiceContainer` 协议化依赖

**影响**:

- 调用链可观测性差
- 新功能接入时容易继续扩散现有模式
- 无法一眼判断某条链路的标准依赖方式

### 3.5 自动化证据缺失风险

**现状**:

- 本地门禁已通过
- 但当前仓库快照缺少版本化 CI workflow 证据

**影响**:

- 团队无法仅凭仓库内容确认门禁是否稳定执行
- 新环境下是否持续校验 strict concurrency 仍不透明

---

## 四、建议动作

### 4.1 先修事实层

- 以 `current-state-audit.md` 作为当前事实基线
- 旧文档保留历史属性，不再承担“最新状态”职责
- 所有后续结论优先引用 2026-03-22 的复算结果

### 4.2 冻结新增坏味道

- UI 层不再新增新的 `*.shared` 直接依赖
- 新增跨层通信时先判断是否可走 `ServiceContainer` 或集中 façade
- 对新增通知链路，要求命名、payload 与消费方文档化

### 4.3 做两个低风险试点

- `MessagePanelView`
- `QuickAskCapsuleView`

在这两个高频视图优先试点 `@Environment(\.services)` 注入，验证替换成本和收益。

### 4.4 补齐自动化证据

如果团队目标是从“本地可验证”升级到“仓库级可证明”，建议把以下内容显式版本化：

- 测试命令
- strict concurrency 命令
- 失败阈值与日志位置

是否采用 GitHub Actions、其他 CI，或仅保留项目脚本，不在本次文档修订中强行假定。

---

## 五、Go / No-Go 判断

### 当前判断

**Go**：

- 当前代码可以构建和测试
- 当前并发检查通过
- 主链路功能仍完整

**Conditional Go**：

- 文档仍需与代码持续对齐
- 架构演进仍受单例与 UI 直连影响
- 自动化门禁缺少版本化证据

### Full Go 触发条件

- 持续保持 `swift test` 与 `run-concurrency-check.sh` 绿色
- 在版本控制中补齐自动化门禁证据
- 至少完成一轮 UI 依赖收敛试点并形成规则

---

## 六、相关文档

- `./current-state-audit.md`
- `./overview.md`
- `./core-modules.md`
- `./ui-components.md`
- `./quick-reference.md`
- `./app-layer-startup-sequence.md`
- `./app-layer-callback-chains.md`
- `./app-layer-risk-assessment.md`
- `../roadmap/2026-03-conditional-go-architecture-roadmap.md`
- `../m2-final-acceptance.md`（历史验收文档）

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-03-22
