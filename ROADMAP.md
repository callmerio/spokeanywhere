# SpokenAnyWhere Roadmap (Execution Edition)

> 版本: v2026.02
> 更新时间: 2026-02-23
> 依据: `PROJECT.md`（M2 Convergence）、P0 修复验收日志、M2 独立复核日志

---

## 1. 当前基线（As-Is）

### 1.1 已完成并可复核

- M1 基线已完成（错误处理增强、核心链路回归验证）。
- P0 卡死止血补丁已落地并通过本地 + 独立复核三门验证。
  - 本地日志: `/tmp/p0-fix-build.log`、`/tmp/p0-fix-test.log`、`/tmp/p0-fix-concurrency.log`
  - 独立复核: `/tmp/m2-codex2-final-20260223-031128-build.log`、`/tmp/m2-codex2-final-20260223-031204-test.log`、`/tmp/m2-codex2-final-20260223-031216-concurrency.log`
- M2 并发收敛与 Sendable 修复已闭环，当前本地三门维持 0 warnings。
  - 复核日志: `/tmp/m2-codex2-m2-recheck-20260223-032255/build.log`、`/tmp/m2-codex2-m2-recheck-20260223-032255/test.log`、`/tmp/m2-codex2-m2-recheck-20260223-032255/concurrency.log`

### 1.2 当前可见风险

- 启动日志仍存在环境噪音（`CMIO` 插件状态错误、`CoreAudio -10877`），但当前样本未形成录音失败链路。
- 文档口径存在不一致（如部分文档仍保留 `122/122` 历史数据，而近期回归为 `129/129`）。
- `PROJECT.md` 明确当前阶段禁止新增 UI/API 功能，需持续控制范围蔓延。


### 1.3 Imported External Execution Records（Traceability Only）

- 2026-04-11 截图文字标注外部执行链已补录到 repo-native GSD 记录，用于解决 ship / merge 前的 traceability 缺口。
  - 来源：`docs/superpowers/specs/2026-04-11-screenshot-text-annotation-design.md`、`docs/superpowers/plans/2026-04-11-screenshot-text-annotation-implementation.md`、外部分支 `codex/screenshot-text-annotation`
  - 迁移记录：`plan/2026-04-13_03-04-12-screenshot-text-annotation-import.md`、`issues/2026-04-13_03-04-12-screenshot-text-annotation-import.csv`、`docs/memo/2026-04-13-screenshot-text-annotation-imported-execution.md`
  - 当前口径：外部分支实现 / review / fresh verification 已完成，但仍存在 ship cleanup blocker（`.serena/project.yml`）
  - 约束：该条目仅用于历史补录与可追溯，不代表当前 `PROJECT.md` / 本 roadmap 已解冻新增 feature scope

---

## 2. 约束与范围（To-Be Guardrails）

### 2.1 In Scope（当前窗口）

- 稳定性与可观测性加固（启动、录音、截图、字幕关键链路）。
- Swift 6 并发与质量门禁持续收敛（Build/Test/Concurrency/CI Sanitizer）。
- 文档与验收口径统一（可复现、可追溯、可审计）。

### 2.2 Out of Scope（冻结项）

- 新功能开发（新 UI 模块、新 API 接入、产品能力扩张）。
- 大规模视觉重构与跨平台扩展（iOS/iPadOS、插件系统等）。

---

## 3. 六周执行路线（2026-02-23 到 2026-03-29）

### Phase R0（2026-02-23 ~ 2026-02-24）基线封板与口径统一

**目标**
- 将当前“已通过验证”的工程状态固化为统一口径，避免后续评审歧义。

**工作包**
1. 更新 M2 验收与质量文档中的测试计数、门禁状态、CI-only 说明。
2. 清点并固化 P0 修复证据索引（日志路径、命令、结论）。
3. 将 roadmap 与 `PROJECT.md` 的 In-Scope/Out-of-Scope 完全对齐。

**阶段 DoD**
- `PROJECT.md`、`ROADMAP.md`、`docs/quality-playbook.md` 无相互冲突描述。
- 关键结论均能追溯到具体日志或命令。

---

### Phase R1（2026-02-24 ~ 2026-03-01）可观测性与启动诊断

**目标**
- 让“启动慢/启动异常/偶发错误”可稳定复现、可低成本判读。

**工作包**
1. 启动步骤日志改为运行时开关（默认静默，按需开启）。
2. 标准化日志判读规则（区分环境噪音 vs 功能性故障）。
3. 固化 freeze/hang 证据采集脚本与事故包目录结构。

**阶段 DoD**
- 具备“一条命令收集 + 一页规则判读”的可执行手册。
- 启动问题可在单次复现中输出结构化证据（步骤耗时 + 错误分类）。

---

### Phase R2（2026-03-02 ~ 2026-03-08）P0 路径稳态化

**目标**
- 将”已止血”升级为”可长期运行的稳态方案”。

**工作包**
1. ✅ R2-1: 音频链路背压验证（已完成，见 `docs/roadmap/r2-1-audio-backpressure-interpretation.md`）
2. ✅ R2-2: 截图/图像增强链路主线程占用验证（**Full GO** - 运行时证据已验证）
   - 状态: `R2-2: Full GO — code-level fixes + runtime screenshot interaction evidence validated (2026-02-23)`
   - 文档: `docs/roadmap/r2-2-screenshot-mainthread-interpretation.md`
   - Commit: b0ba0c1f7186db77e29cb056ce390edca8d0c16c
   - 验证证据: PID 66224, 截图时间 11:10:22, 指标正常 (capture_latency: 3613ms, save_all_write_p95: 0.8ms)
   - 同行评审: codex-1, codex-2, claude-2, reporter 一致通过
3. ⏳ R2-3: 建立回归脚本：典型录音 + OCR + LLM 联动场景压测。

**阶段 DoD**
- 连续多轮压测无卡死、无新增高优先级并发告警。
- 关键链路（录音、截图、字幕）均有可复现回归日志。
- R2-2 转正为 Full GO（待用户交互补证）。

---

### Phase R3（2026-03-09 ~ 2026-03-22）质量门禁硬化与架构治理

**目标**
- 从“本地通过”提升为“团队与 CI 持续通过”。

**工作包**
1. 固化并发门禁与 CI 失败回传机制（失败即阻断合并）。
2. 针对高风险模块开展小步治理（主线程边界、共享状态、生命周期清理）。
3. 周期性复验 Sanitizer CI（Thread/Address）并建立问题回溯清单。

**阶段 DoD**
- PR 主链具备稳定门禁：Build/Test/Concurrency 全绿。
- CI Sanitizer 失败可在 1 个工作日内定位到责任模块。

---

### Phase R4（2026-03-23 ~ 2026-03-29）发布准备与功能解冻评审

**目标**
- 在不牺牲稳定性的前提下，为下一阶段功能开发建立准入条件。

**工作包**
1. 形成发布前检查清单（版本、门禁、回滚、事故响应）。
2. 复核近 4 周稳定性趋势（是否仍有 P0/P1 事故）。
3. 召开“功能解冻评审”，决定是否进入下一轮产品功能迭代。

**阶段 DoD**
- 发布检查清单可执行、可复核、可回滚。
- 用户确认是否解冻功能路线（进入新一轮 feature roadmap）。

---

## 4. 功能解冻门槛（必须全部满足）

1. 最近两周内无 P0 级事故。
2. 本地三门连续稳定：`swift build`、`swift test --parallel`、`./Tests/run-concurrency-check.sh`。
3. CI Sanitizer（Thread/Address）在主分支连续通过。
4. 关键文档口径一致且可追溯（`PROJECT.md`、`ROADMAP.md`、`docs/quality-playbook.md`）。

---

## 5. 验证命令（统一口径）

**当前测试基线**: 129 tests in 22 suites (2026-02-23)
**历史快照**: M2 执行期间为 122 tests in 21 suites（历史证据文档中的计数准确反映当时状态）

```bash
cd spoke
swift build
swift test --parallel
./Tests/run-concurrency-check.sh
```

CI 专属（本地受 dyld policy 限制）：

```bash
cd spoke
swift test --sanitize=thread --parallel
swift test --sanitize=address --parallel
```

---

## 6. 远期 Backlog（冻结，待解冻后评审）

- 转录增强（中英混合识别、Whisper 本地模型、Whisper API）。
- 词典能力扩展（查词、生词本、词形还原）。
- 体验增强（菜单栏能力、快捷键自定义、主题系统）。
- 平台扩展（多语言、iOS/iPadOS、企业能力）。

> 注：以上仅保留为候选方向，不纳入当前执行窗口。
