# SpokenAnyWhere 风险评估与改进建议

**版本**: 1.0
**更新时间**: 2026-02-22
**结论**: **Conditional Go** (当前代码可运行，但需补齐质量门禁和架构收敛)

---

## 执行摘要

**当前状态**:
- ✅ **代码可运行性**: Go (主链路完整，0 warnings, 129/129 tests)
- ⚠️ **质量门禁**: Conditional Go (Build/Test/Sanitizer 完整，Concurrency gate 待补齐)
- ⚠️ **架构可维护性**: Conditional Go (存在高耦合与治理缺口)

**Full Go 触发条件**:
- 完成 QG-W1-1/W1-2 (并发门禁硬阻断)
- 启动 ARCH-W1 试点收敛 (控制增量恶化)

---

## 一、三维风险分析

### 1.1 App 启动与回调风险 (claude-2)

**详细文档**: `./app-layer-risk-assessment.md`

**P1 风险**:
- **RISK-APP-002**: RecordingController 级联初始化 (无缓解)
  - 现状: 启动时触发 10+ 单例级联初始化
  - 影响: 启动阻塞、故障传播、测试困难
  - 证据: `Services/RecordingController.swift:24-35`

- **RISK-APP-006**: 不完整的终止清理 (20+ 服务未停止)
  - 现状: `applicationWillTerminate` 仅停止 4 个服务
  - 影响: 资源泄漏、状态残留
  - 证据: `App/AppDelegate.swift:281-286`

- **RISK-APP-007**: 回调泄漏风险
  - 现状: 闭包捕获 self，未使用 weak/unowned
  - 影响: 内存泄漏、对象无法释放
  - 证据: 多处回调注册点

**关键发现**:
- 12 步启动序列，同步路径 ~220ms
- 25 个单例服务，RecordingController 聚合 9+ 依赖
- 4 条主链路 (录音/QuickAsk/截图/词典)

### 1.2 构建与门禁风险 (code)

**详细分析**: CCCC event `43f9a0ed44784aecbfa45f8c6d7f3612`

**P1 风险**:
- **P1-BUILD-001**: CI 主链缺 strict-concurrency 阻断
  - 现状: `test.yml` 仅执行 build/test，无并发门禁
  - 影响: PR 可在基础测试通过情况下引入并发告警
  - 证据: `.github/workflows/test.yml` 无 concurrency-gate job

- **P1-BUILD-002**: `run-concurrency-check.sh` 仅看退出码
  - 现状: 脚本只跑构建，warning 不会导致非零退出
  - 影响: 脚本"通过"不等价于"0 warnings"
  - 证据: `Tests/run-concurrency-check.sh` 无 warning 计数断言

**P2 风险**:
- 性能门禁为 Draft + 手动触发
- 验收文档口径滞后 (122/122 vs 129/129)

**P3 风险**:
- release 打包版本字段固定

**审计证据**:
- `/tmp/code-verify-strict.log` (0 warnings)
- `/tmp/code-verify-tests.log` (129/129 tests)
- `/tmp/code-verify-concurrency-check.log`

### 1.3 Core/Services/UI 架构风险 (codex-1)

**详细分析**: CCCC event `ce9b69815b2e49a98cd476ca0147f329`

**量化快照**:
- 全局单例密度: Core=32, Services=26, UI=7
- UI 直连业务密度: 168 处 `*.shared.*` 调用
- 事件总线密度: 54 处 NotificationCenter 调用
- DI 实际采用率: ServiceContainer 几乎未见真实消费

**P1-ARCH 风险**:
- **P1-ARCH-001**: 全局单例过密
  - 现状: Core/Services/UI 三层都存在大量 `shared` 入口
  - 影响: 初始化顺序隐式、测试替换困难、故障隔离能力弱
  - 证据: `Services/RecordingController.swift:24-35` 聚合 9+ 单例

- **P1-ARCH-002**: UI 层直连 Service/Core
  - 现状: 截图、消息面板、字幕、设置等 UI 广泛直接调用业务单例
  - 影响: UI 改动易触发业务副作用，预览/单测成本高
  - 证据: `UI/Screenshot/ActionBarView.swift:99,131,136`

- **P1-ARCH-003**: 依赖通道双轨并存
  - 现状: direct call + NotificationCenter + ServiceContainer 三通道混用
  - 影响: 调用链可观测性差，变更时易出现漏改/重复触发
  - 证据: 字典链路同时使用通知和直接调用

**P2-ARCH 风险**:
- RecordingController 职责过载
- Screenshot 域跨层边界虽有注入，但 UI 反向依赖仍重
- LiveCaption/Dictionary/Toolbar 多域共享状态交织

---

## 二、双轴改进 Backlog

### 2.1 质量门禁轴 (QG-W1/W2)

**详细计划**: CCCC event `dafbc49622fa4291a53835865259c331`

#### Week 1: 先补硬阻断

**QG-W1-1**: `run-concurrency-check.sh` 增 warning fail-fast
- **目标**: 脚本通过 ≡ 0 warnings
- **最小改动**: 统计 `warning:` 和 `unhandled files`，>0 即 `exit 1`
- **DoD**: 本地/CI 运行脚本时，warning 非 0 必失败
- **实施版本**: CCCC event `75e08d790e0a424eb3e9fb3639cbd879` (v2 patch)

**QG-W1-2**: `test.yml` 新增 `concurrency-gate` (阻断 PR)
- **目标**: PR 主链具备 strict-concurrency 硬门禁
- **最小改动**: 在 `test-gate` 后新增 job，执行 `./Tests/run-concurrency-check.sh`
- **DoD**: PR checks 出现 `Concurrency Gate`；warning 或脚本失败时阻断合并
- **实施版本**: CCCC event `75e08d790e0a424eb3e9fb3639cbd879` (v2 patch)

**QG-W1-3**: 文档口径同步
- **目标**: 消除"122/122 vs 129/129"与"质量门禁完整"偏差
- **最小改动**: 更新 `m2-final-acceptance.md` + overview/quick-reference 双轴结论
- **DoD**: 最终文档统一为 `Conditional Go`，并明确 Concurrency gate 待补齐→已补齐状态

#### Week 2: 治理与可持续

**QG-W2-1**: release 版本字段与 tag 对齐
- **目标**: 包内版本与发布 tag 一致
- **最小改动**: `release.yml` 生成 Info.plist 时注入 `${{ steps.version.outputs.version }}`
- **DoD**: 任一 tag 构建后，产物内版本与 release 名称一致

**QG-W2-2**: 性能门禁从 Draft 走向准常态
- **目标**: 把性能回归从"手动"升级为"可持续观测"
- **最小改动**: `perf-startup.yml` 增 nightly（先非阻断），保留 artifact
- **DoD**: 每夜有可追溯 perf report；回归可定位到具体指标

**QG-W2-3**: 并发门禁稳定性回归（两轮）
- **目标**: 证明新门禁无随机抖动
- **最小改动**: 在 clean 环境重复 2 轮完整链路并留档
- **DoD**: 两轮结果一致，门禁无 flaky 误报

**验收命令**:
```bash
cd spoke && ./Tests/run-concurrency-check.sh
cd spoke && swift test --parallel
cd spoke && swift build -Xswiftc -warn-concurrency -Xswiftc -strict-concurrency=complete
cd spoke && swift test --sanitize=thread --parallel && swift test --sanitize=address --parallel
```

### 2.2 架构演进轴 (ARCH-W1/W2)

**详细计划**: CCCC event `354086ddeac94a948cdcaeb69c78c2d0`

#### Week 1: 控增量 + 试点收敛

**ARCH-W1-1**: 新增"依赖通道冻结"规则
- **目标**: 禁止 UI 层新增直接 `*.shared` 依赖（允许存量，不允许新增）
- **最小产物**:
  1. `./risks-and-recommendations.md` 增加规则与例外流程
  2. 轻量检查脚本（仅 diff 范围）在 CI 非阻断提示
- **DoD**: 新 PR 若引入 UI 新增 `.shared`，检查会提示具体文件/行

**ARCH-W1-2**: 截图域 façade 试点
- **目标**: 把 `UI/Screenshot` 高频操作改经单一 façade，不再由视图直接调 3+ 个单例
- **试点范围**: `ActionBarView` + `ScreenshotContentView(+Actions)`
- **DoD**: 这两个文件中的直接 `ScreenshotManager/QuickAskService/ImageEnhancementService.shared` 调用显著减少

**ARCH-W1-3**: 通知总线 typed wrapper 试点
- **目标**: 将 `.requestAddToDictionary` 的 userInfo 字典改为强类型 payload 封装
- **试点范围**: `DictionaryService` 通知发布 + `AddToDictionaryHandler` 监听处理
- **DoD**: 该链路不再出现裸字符串键散落多处

#### Week 2: 拆重编排器 + 扩大容器落地

**ARCH-W2-1**: 拆分 `RecordingController`
- **目标**: 把 `processTranscription` 中的 LLM/MessagePanel/History 分发提取为独立协作者
- **DoD**: `RecordingController` 体量下降，职责聚焦为会话编排；现有行为与测试保持通过

**ARCH-W2-2**: ServiceContainer 真正落地
- **目标**: 在两个高频视图用 `@Environment(\.services)` 替代直接单例访问
- **建议试点**: `UI/MessagePanel/MessagePanelView.swift`、`UI/HUD/QuickAskCapsuleView.swift`
- **DoD**: 这两处能通过注入 mock 服务完成基础行为测试

**ARCH-W2-3**: 双通道收敛清单 + 决策表
- **目标**: 输出"哪些场景走 direct call，哪些走事件总线，哪些走容器"的决策矩阵
- **DoD**: `./quick-reference.md` 增"依赖通道决策表"，并附 5-10 个已收敛实例

**验收命令**:
```bash
cd spoke && swift build -Xswiftc -warn-concurrency -Xswiftc -strict-concurrency=complete
cd spoke && swift test --parallel
cd spoke && rg -n "\.shared\." UI | wc -l  # 跟踪 UI 直连密度趋势
cd spoke && rg -n "NotificationCenter\.default\.(addObserver|post)" {UI,Core,Services}  # 跟踪事件总线密度趋势
```

---

## 三、实施路径建议

### 3.1 排程耦合

**Week 1 前半**: 先落 QG-W1-1/W1-2 (并发门禁硬阻断)，把质量底座先锁住
**Week 1 后半**: 并行推进 ARCH-W1-1/2/3 两处试点，优先截图 façade 与 typed notification
**Week 2**: 按提案推进 ARCH-W2-*，同时跟进 QG-W2-* (release 版本对齐 + perf 夜跑 + 门禁稳定性复验)

这样能保证"架构收敛"与"门禁兜底"同步推进，避免边改边漏检。

### 3.2 安全落地策略

**QG-W1-1/W1-2 实施**:
1. 单独提交这 2 个文件，便于回滚
2. 合并前本地先跑: `cd spoke && ./Tests/run-concurrency-check.sh`、`cd spoke && swift test --parallel`
3. 若 CI 首轮出现环境噪声，再临时降级为告警模式并保留日志

**ARCH-W1 试点**:
1. 每个试点独立 PR，包含前后对比数据
2. 保持现有测试通过
3. 记录改造成本与收益，为 W2 扩大范围提供依据

---

## 四、决策点

### 选项 A: 立即实施 (推荐)

**理由**:
- QG-W1-1/W1-2 仅触及门禁脚本与 CI 编排，不涉及业务运行时路径
- 正好对应 Conditional Go 的两个 P1 缺口
- 风险可控，可快速回滚

**执行版本**:
- **V2 Patch**: CCCC event `75e08d790e0a424eb3e9fb3639cbd879`
- 已吸收 codex-3 复核意见：避免双重 tee + 保留构建失败统一摘要

**预期结果**:
- Conditional Go → Full Go (质量门禁轴)
- 为 ARCH-W1 架构收敛提供稳定底座

### 选项 B: 后续任务

**理由**:
- 先完成架构文档，再单独 PR 实施门禁补齐
- 给团队更多时间评审 patch

**风险**:
- 延迟 Full Go 达成
- 架构收敛期间可能引入新的并发告警

---

## 五、Go/No-Go 判据

### 当前结论: **Conditional Go**

**Go 条件** (已满足):
- ✅ 当前代码可运行
- ✅ 主链路完整 (启动/录音/截图/字典/字幕)
- ✅ 0 warnings, 129/129 tests

**Conditional 条件** (待收敛):
- ⚠️ 质量门禁需补齐 (QG-W1-1/W1-2)
- ⚠️ 架构演进需收敛 (ARCH-W1 控增量)

**Full Go 触发条件**:
- 完成 QG-W1-1/W1-2 (并发门禁硬阻断)
- 启动 ARCH-W1-1 (依赖通道冻结规则)

---

## 六、相关文档

- [项目架构全景](./overview.md) - 架构分层与技术决策
- [快速导航索引](./quick-reference.md) - 功能 → 实现位置映射
- [App 层启动序列](./app-layer-startup-sequence.md) - 12 步启动流程 (claude-2)
- [App 层回调链](./app-layer-callback-chains.md) - 4 条主链路 (claude-2)
- [App 层风险评估](./app-layer-risk-assessment.md) - 9 个风险点 (claude-2)
- [性能基准测试](../performance-benchmarking.md) - 性能测试方案
- [M2 并发告警收敛](../m2-final-acceptance.md) - Swift 6 合规

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-02-22
**审阅**: codex-1 (架构轴), code (门禁轴), claude-2 (App 层)
