# PRD: 质量与稳定性优化（允许必要重构）

## 1. Introduction / Overview

本 PRD 聚焦 `SpokenAnyWhere` 的工程质量与运行稳定性优化，目标是在不引入新功能范围膨胀的前提下，系统性降低故障率、并发风险与回归成本。

本轮明确不补 TODO 功能（如 Whisper Local、SelectionToolbar 搜索等），仅在质量与稳定性目标下进行必要的小到中等重构。

### 背景证据（调研）
- 录音与 Quick Ask 共享同一音频服务，存在回调覆盖风险（`Services/RecordingController.swift:200`，`Services/QuickAskService.swift:307`）。
- Swift 6 并发隔离存在编译告警风险点（`Services/ServiceContainer.swift:245`）。
- 启动阶段服务较多且包含后台预热，存在性能与稳定性平衡空间（`App/AppDelegate.swift:55`）。
- 代码中存在技术债清单，但本轮不纳入功能实现（`Core/Transcription/TranscriptionManager.swift:133` 等）。

---

## 2. Goals

- G1: 降低录音/转写链路故障率，避免错误风暴与不可恢复状态。
- G2: 解决关键并发隔离问题，形成 Swift 6 迁移可持续路径。
- G3: 扩大自动化测试覆盖面，减少“人工回归才能发现问题”的情况。
- G4: 建立质量门禁，确保后续重构可控演进。

---

## 3. User Stories

### US-001: 录音链路稳定性基线治理
**Description:** 作为用户，我希望录音链路在设备变化、权限边界、模式切换时稳定可恢复，这样我不会频繁遇到录音失败或异常中断。

**Verify Type:** `script`

**Acceptance Criteria:**
- [ ] 明确定义并实现录音启动失败、设备缺失、配置变更三类错误处理策略。
- [ ] 录音中设备变化时，系统能进入可恢复或可解释失败状态，不出现无限重试或日志风暴。
- [ ] Quick Ask 与普通录音互切时，不发生回调串线/状态污染。
- [ ] `swift build` 通过。
- [ ] 新增或更新自动化测试覆盖关键边界场景。

### US-002: 音频回调路由与会话边界重构
**Description:** 作为开发者，我希望将音频回调与会话生命周期解耦，以便不同入口（录音/Quick Ask）不会互相覆盖。

**Verify Type:** `script`

**Acceptance Criteria:**
- [ ] 建立清晰的回调路由层或会话作用域，避免共享闭包被覆盖。
- [ ] 录音会话结束时，相关 observer/timer/task 被可靠释放。
- [ ] 重构后接口职责更清晰（编排层 vs 服务层）。
- [ ] 增加至少 2 个回归测试覆盖“入口切换+并发触发”场景。
- [ ] `swift test` 通过。

### US-003: Swift 并发隔离与主线程安全治理
**Description:** 作为维护者，我希望并发隔离告警可控并有迁移路径，这样后续升级 Swift 6 不会集中爆雷。

**Verify Type:** `script`

**Acceptance Criteria:**
- [ ] 修复或显式治理当前关键并发隔离告警（如 `EnvironmentKey` 与 `@MainActor` 交叉问题）。
- [ ] 对核心共享状态对象补充并发访问约束说明（Actor/主线程/任务边界）。
- [ ] 在 CI/本地脚本中新增并发检查入口（如 `-strict-concurrency` 渐进检查）。
- [ ] 构建流程保持通过且不引入新高优先级并发告警。

### US-004: 测试体系扩展（场景覆盖优先）
**Description:** 作为产品负责人，我希望测试覆盖关键用户路径和边界路径，减少回归遗漏。

**Verify Type:** `script`

**Acceptance Criteria:**
- [ ] 为录音/Quick Ask/历史保存等关键链路补充场景测试（正常、失败、恢复、并发切换）。
- [ ] 测试避免依赖共享持久化状态，具备可重复执行与隔离性。
- [ ] 针对并发相关风险增加回归测试，验证不会随机失败。
- [ ] `swift test` 在本地可重复通过（多次执行）。

### US-005: CI 质量门禁与诊断分层
**Description:** 作为团队成员，我希望 CI 能快速反馈基础质量问题，并提供更强诊断通道捕获隐性并发/内存问题。

**Verify Type:** `script`

**Acceptance Criteria:**
- [ ] 默认 CI 流程包含构建 + 测试 + 基础静态质量检查。
- [ ] 增加“增强诊断通道”（可作为 nightly 或手动触发），用于 sanitizer 检查。
- [ ] 输出统一的失败分类（编译失败/测试失败/并发告警/诊断失败）。
- [ ] 文档化本地复现命令与排障路径。

---

## 4. Functional Requirements

- FR-1: 系统必须在录音链路中显式处理设备缺失、配置变化、权限不足三类错误。
- FR-2: 系统必须为录音与 Quick Ask 提供独立可控的回调作用域，避免互相覆盖。
- FR-3: 系统必须在会话结束后清理 observer/timer/task，避免状态泄漏。
- FR-4: 系统必须治理关键并发隔离告警，并建立渐进的并发检查策略。
- FR-5: 系统必须新增并发/边界场景自动化测试，覆盖关键用户路径。
- FR-6: CI 必须提供基础质量门禁，并提供可选增强诊断通道（sanitizer）。
- FR-7: 本轮不引入新的产品功能范围，不实现现有 TODO 功能项。

---

## 5. Non-Goals (Out of Scope)

- 不实现 Whisper Local 等未完成功能。
- 不新增 SelectionToolbar 的联网搜索功能。
- 不进行大规模 UI 改版。
- 不引入与“稳定性/质量”无关的产品特性扩展。

---

## 6. Technical Considerations

- 现有可复用模式：`ServiceContainer` 协议注入与可替换依赖（`Services/ServiceContainer.swift:105`）。
- 音频编排重点：`RecordingController` 与 `QuickAskService` 共享 `AudioRecorderService`，需重构回调边界。
- 并发治理重点：`Services/ServiceContainer.swift:245` 的 Actor 隔离问题应优先修复。
- 持久化与测试：保持测试隔离策略，避免共享本地数据导致不稳定（参考 `VocabularyService` 近期改进模式）。
- 启动性能：`AppDelegate` 多阶段初始化可按风险分级进行同步/异步拆分（`App/AppDelegate.swift:55`）。

---

## 7. Design Considerations

- 本轮以工程稳定性为主，不追求视觉交互变更。
- 若需要暴露诊断信息，优先采用低侵入方式（日志级别、调试面板开关），避免影响主路径交互。
- 若新增设置项（如诊断开关），需保持默认对普通用户无感。

---

## 8. Milestones

### Milestone 1（稳定性基线 + 风险收敛）
- 音频链路错误处理基线完善。
- 回调覆盖风险治理（最小可行重构）。
- 关键并发隔离告警治理。
- 核心回归测试补齐并稳定通过。

### Milestone 2（结构优化 + 质量门禁增强）
- 编排层职责进一步清晰化（允许中等重构）。
- CI 增加增强诊断通道（nightly/手动触发 sanitizer）。
- 文档化质量门禁与故障定位流程。

---

## 9. Success Metrics

- M1: 录音链路相关高优先级错误日志频率显著下降（目标：下降 50%+）。
- M2: `swift test` 稳定通过率达到 100%，且多次重复执行无随机失败。
- M3: 新增并发/边界场景测试覆盖关键链路（至少 8-12 个高价值场景）。
- M4: 关键并发隔离告警清零或进入可控白名单并有明确迁移计划。
- M5: CI 能在一次运行中明确给出失败归因并可复现。

---

## 10. Open Questions

1. Sanitizer 策略采用“nightly 必跑”还是“手动触发 + 发布前必跑”？
2. 对较大重构的单次 PR 规模是否设置上限（建议按子模块拆分）？
3. 是否需要引入统一的运行时诊断开关（Debug Profile）用于现场问题复现？

---

## External Research References

1. Apple Swift Testing: https://developer.apple.com/xcode/swift-testing/
2. Apple Audio Route Changes: https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/HandlingAudioHardwareRouteChanges/HandlingAudioHardwareRouteChanges.html
3. Apple Diagnosing memory/thread/crash issues: https://developer.apple.com/documentation/xcode/diagnosing-memory-thread-and-crash-issues-early
4. Swift.org Concurrency Checking: https://www.swift.org/documentation/concurrency/
5. Swift.org Concurrency Adoption Guidelines: https://www.swift.org/documentation/server/guides/libraries/concurrency-adoption-guidelines.html

