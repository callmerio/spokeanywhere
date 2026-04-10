# SpokenAnyWhere 当前状态审计

**版本**: 1.3
**审计日期**: 2026-03-23
**补充复核**: 2026-04-07（当前能力基线 / 权限边界）
**审计范围**: 仓库结构、架构分层、文档一致性、测试与并发门禁、记忆落地状态、当前能力基线

---

## 一、执行摘要

SpokenAnyWhere 是一个原生 macOS 生产力应用，使用 SwiftUI + AppKit 混合架构，围绕语音输入、Quick Ask、实时字幕、截图标注、文本选择工具栏和词典能力组织代码。

本次审计确认：

- 当前仓库主代码位于 `App/`、`Core/`、`Services/`、`UI/`
- `Package.swift` 仍以 Swift Package Manager 作为构建入口
- 本地实测已于 **2026-03-23** 复算保持通过：
  - `swift test` -> `150 tests / 30 suites` 通过
  - `bash Tests/run-concurrency-check.sh` -> `0 warnings`
- `docs/architecture/` 已有较完整基础文档，但存在明显口径漂移
- `Memory` 项目上下文已初始化为 `.memory/`，`Memgraph` 服务已恢复，可写入实体、卡片与关系
- 自 **2026-04-10** 起，本文件是当前架构事实真源；历史边界与同步清单见 `./fact-source-boundary.md`

---

## 二、仓库快照

### 2.1 应用入口

- `App/SpokenlyApp.swift`: SwiftUI `@main` 入口
- `App/AppDelegate.swift`: App 生命周期、SwiftData 容器、菜单栏、启动编排

### 2.2 代码主干

四层结构仍然成立，但真实模块比旧文档更丰富：

```text
App
  -> 入口与启动编排
Services
  -> 全局协调、热键、工具栏、设置、历史、消息面板
Core
  -> 业务域与状态模型
UI
  -> SwiftUI/AppKit 视图与浮窗
```

### 2.3 当前真实模块

`Core/` 当前可见模块：

- `Attachment`
- `Audio`
- `Debug`
- `Dictionary`
- `History`
- `LLM`
- `LiveCaption`
- `MessagePanel`
- `QuickAsk`
- `Screenshot`
- `SelectionToolbar`
- `Tags`
- `Testing`
- `Transcription`
- `Translation`
- `Workflow`
- 横切文件：`DataModels.swift`、`RecordingState.swift`
- 占位目录：`Errors/`、`Metal/` 当前未见受跟踪源码文件

`UI/` 当前可见模块：

- `Components`
- `Dictionary`
- `HUD`
- `LiveCaption`
- `MessagePanel`
- `QuickAsk`
- `Screenshot`
- `SelectionToolbar`
- `Settings`
- `Theme`
- `Workflow`

### 2.4 当前事实真源与历史边界

- 当前事实真源：`./current-state-audit.md`
- Active Plan：`../plans/2026-04-10-architecture-optimization-roadmap-v3.md`
- Active Execution Checklist：`../../tasks/2026-04-10-architecture-optimization-roadmap-v3-execution.md`
- 历史边界与同步清单：`./fact-source-boundary.md`

当前执行期内：

- `v1` / `v2` 只保留在 `docs/plans/archive/2026-04-10/`
- `2026-03-conditional-go-architecture-roadmap.md` 只保留为解冻合同来源
- `m2-final-acceptance.md` 只保留为 2026-02-22 的历史验收证据

---

## 三、关键架构现状

### 3.1 启动与依赖

- `AppDelegate` 负责菜单栏、权限、历史清理、截图恢复、字典预热、资源监控等启动动作
- `RecordingController.shared.start()` 仍是启动时的重要级联入口
- `ServiceContainer` 已提供协议化访问与注入能力，但真实使用范围仍小于直接单例访问

### 3.2 主要链路

- 语音输入：`HotKeyService -> VoiceHandler -> RecordingController -> AudioRecorderService -> TranscriptionManager`
- Quick Ask：`HotKeyService -> QuickAskHandler -> QuickAskService -> LLMPipeline`
- 截图：`HotKeyService -> ScreenshotHandler -> ScreenshotManager -> ScreenCaptureService`
- 实时字幕：`HotKeyService -> CaptionHandler -> LiveCaptionManager -> SystemAudioCaptureService -> LiveCaptionTranscriber`
- 文本选择工具栏：`SelectionMonitorService -> SelectionToolbarManager -> SelectionActionService`
- Workflow：`WorkflowState/WorkflowPickerView -> WorkflowExecutor -> LLMPipeline`
- Message Panel：`MessagePanelManager/MessagePanelState -> SessionHistoryService/SummaryService`

### 3.3 依赖特征

当前仓库同时存在三种依赖通道：

- 直接单例调用：`*.shared`
- 事件总线：`NotificationCenter`
- 容器注入：`ServiceContainer`

这种并存模式让系统具备演进弹性，但也增加了调用链追踪与测试替换成本。

### 3.4 当前能力基线（2026-04-07 补充复核）

本节用于回答“当前项目真实在提供什么能力、用户从哪里进入、哪些状态会留下来、哪些不该被权限平台误吞”。

- 语音输入
  - 用户入口：全局热键录音、HUD 完成/取消、后续写入历史
  - 主链路：`HotKeyService -> VoiceHandler -> RecordingController -> AudioRecorderService -> TranscriptionManager`
  - 权限依赖：`Microphone`、`Speech Recognition`；若启用边说边打字，还会触发 `Accessibility` 输入注入依赖
  - 持久化 / 恢复：录音结果进入 `HistoryItem`，音频文件落到 `~/Library/Application Support/Spoke/Audio/`；未完成录音不会跨重启自动恢复

- Quick Ask
  - 用户入口：全局热键、HUD、`AnswerPanel`
  - 主链路：`HotKeyService -> QuickAskHandler -> QuickAskService -> LLMPipeline`
  - 权限依赖：与录音相似，但语义是“问答会话”而不是“录音历史”
  - 持久化 / 恢复：运行期会话状态与 Message Panel / SessionHistory 协同，但不等于“未完成会话自动恢复”

- 截图家族
  - 用户入口：全局热键 `⌥A`、菜单栏“区域截图”、截图窗口内操作栏
  - 主链路：`HotKeyService -> ScreenshotHandler -> ScreenshotManager -> ScreenCaptureService`
  - 权限依赖：`Screen Recording`
  - 持久化 / 恢复：
    - `copy` / `temporary` 模式不持久化
    - `pin` 与 `mark` 产生的截图项由 `ScreenshotManager.saveAll()/restoreAll()` 独立保存并跨重启恢复
  - 边界提醒：`pinned screenshot` 是截图功能自己的用户资产，不应被归并为 Permission Experience 的 `blocked intent` 缓存

- OCR / 活动应用上下文
  - 用户入口：录音前置 `prefetch`、Selection Toolbar OCR 扩展、截图相关动作
  - 主链路：`ScreenOCRService` 作为录音 / 工具栏 / LLM 的上下文提供者
  - 权限依赖：`Screen Recording`
  - 持久化 / 恢复：默认是运行时上下文，不应作为权限平台的持久化内容缓存

- 文本选择工具栏
  - 用户入口：菜单栏开关、设置页、选中文本后的浮动工具栏
  - 主链路：`SelectionMonitorService -> SelectionToolbarManager -> SelectionActionService`
  - 权限依赖：`Accessibility`
  - 持久化 / 恢复：启用状态和配置走 `AppSettings` / 工具栏配置保存；被选中的文本内容不应进入权限平台持久化

- 实时字幕 / 系统音频
  - 用户入口：全局热键 `⌥S`、菜单栏“实时字幕”
  - 主链路：`HotKeyService -> CaptionHandler -> LiveCaptionManager -> SystemAudioCaptureService -> LiveCaptionTranscriber`
  - 权限依赖：系统音频路径依赖 `Screen Recording`
  - 持久化 / 恢复：语言、翻译、显示模式等配置由 `AppSettings` 持久化；运行中的字幕采集不会跨重启自动恢复

- Message Panel / Clipboard Pipeline
  - 用户入口：消息面板热键、剪贴板 Pipeline 热键、录音 / LLM / 剪贴板内容注入 Message Panel
  - 主链路：
    - `MessagePanelManager -> MessagePanelState -> SessionHistoryService / SummaryService`
    - `ClipboardPipelineService -> MessagePanelManager`
  - 权限依赖：无额外 TCC 权限，但会承载来自录音、LLM、剪贴板的内容
  - 持久化 / 恢复：剪贴板历史由 `ClipboardHistoryService` 静默持久化；Message Panel 会话历史与摘要具有独立持久化语义

- 设置 / 状态栏 / 持久化骨架
  - 用户入口：菜单栏、`SettingsView`
  - 持久化载体：
    - `SwiftData`：`HistoryItem`、`AppRule`、`AIProviderConfig`
    - `AppStorage`：快捷键、截图 / 工具栏 / 实时字幕 / 历史清理等设置
    - `UserDefaults(JSON)`：剪贴板历史
    - `Application Support`：录音文件、截图图片与 `screenshot_items.json`
    - `Keychain`：LLM 凭据
  - 边界提醒：权限平台如果要记忆“被权限拦住的动作”，必须与这些现有持久化资产分层，不要混装

---

## 四、质量基线

### 4.1 本地复算结果

复算日期：**2026-03-23**

```bash
swift test
bash Tests/run-concurrency-check.sh
```

结果：

- `swift test`: `150 tests / 30 suites` 全部通过
- `run-concurrency-check.sh`: `strict-concurrency build 通过 (0 warnings)`

### 4.2 结论边界

本地验证说明当前仓库在本机环境下可构建、可测试、并且满足严格并发检查。

但仓库快照中未发现版本化的 `.github/workflows/*` 文件，因此无法仅凭仓库内容证明“自动化 CI 门禁”已经在版本控制中稳定落地。

### 4.3 当前统一门禁入口

- Provider-neutral 入口：`scripts/verify/run-architecture-quality-gate.sh`
- 门禁说明：`./quality-gate.md`
- 默认日志目录：`verify/quality-gate/<timestamp>/`
- 当前策略：
  - `swift build` / `swift test` / strict concurrency 为 hard fail
  - `.shared` / `NotificationCenter` 扫描先保留为 report-only 证据，待 `GOV-380` 固化 allowlist 后再升级为硬约束

---

## 五、文档偏差清单

本次审计识别出以下偏差：

- 部分历史文档仍保留 `122/122 tests` 的旧口径
- `quick-reference.md` 引用了当前仓库不存在的 `.github/workflows/test.yml` 与 `.github/workflows/perf-startup.yml`
- `ui-components.md` 与 `core-modules.md` 未覆盖 `Workflow`、`MessagePanel`、`Translation`、`History`、`Tags` 等真实模块
- `docs/style/INDEX.md` 当前不存在，旧文档中的设计系统链接无效
- 历史验收文档与当前现状之间缺少“时间口径”说明，易被误读为最新状态

---

## 六、当前判断

从“代码可运行性”角度看，项目当前为 **Go**：

- 启动主干存在
- 测试通过
- 严格并发检查通过

从“可持续演进”角度看，项目当前可以标记为 **Go**：

- 运行时主干仍以单例为基础，但高频 orchestrator / live factory 已完成多轮收敛
- UI 试点已经有 preview/fixture、interaction smoke 与 proof map
- 依赖通道治理、最小规则包和统一质量门禁都已落地
- app-scope 常驻对象的 shutdown contract 已进入统一 lifecycle 路径

本轮新增的结构收敛：

- `SelectionMonitorService` 已拆出 `SelectionMonitorLiveDependencies` 与 `SelectionMonitorRuntimeHelpers`，将 debounce / AX bridge / live wiring 从主文件热路径中分离。
- `WorkflowExecutor` 已拆出 `WorkflowExecutorLiveDependencies` 与 `WorkflowProfileResolver`，并新增 `WorkflowProfileResolverTests` 作为 profile fallback 的表征测试。
- `QuickAskLiveDependencies` 与 `RecordingControllerLiveDependencies` 已完成 live factory 收敛，主文件不再保留成组 `*.shared` 与 responder-chain 内联样板。
- `ServiceContainerLiveDependencies` 已承接 `ServiceContainerDependencies.live` 的默认装配，容器主文件不再内联整段默认 wiring。
- `Services/RuntimeBridgeHelpers.swift` 已成为 Recording / Quick Ask / Selection 系列 runtime helper 的共享主线程、定时器与轮询桥接入口。
- `Services/MessagePanelRuntimeHelpers.swift`、`UI/Screenshot/ScreenshotContentRuntimeHelpers.swift`、`Core/Attachment/AttachmentRuntimeHelpers.swift`、`Core/Audio/AudioRecorderRuntimeHelpers.swift` 与 `Core/LiveCaption/LiveCaptionManagerRuntimeHelpers.swift` 已把 MessagePanel / Screenshot / Attachment / Audio / LiveCaptionManager 的生产路径桥接样板继续从主文件中剥离。
- `MessagePanelView`、`LiveCaptionView` 与 `QuickAskCapsuleView` 的 preview/shared 入口已在 round 18 改为 preview factory 或显式依赖，不再把视图本体直接系在 `.shared` 上。
- `QuickAskService`、`MessagePanelManager`、`LiveCaptionManager`、`ScreenshotManager` 已进入 `AppLifecyclePlan.shutdown(...)`，`RecordingController` 的 callback session / hotkey callback 也补齐了对称 cleanup。
- 若按最新测试口径计，当前本地基线已提升到 `150 tests / 30 suites`。

---

## 七、记忆落地状态

记忆侧当前状态：

- `.memory/` 已初始化
- 本地文本化记忆容器已可用
- 当前会话下 `memory search` 仍提示 `Memgraph 服务不可用`
- 因此图数据库写入不应视为当前稳定基线

因此当前应以仓库内本地产物为准：

- `.memory/` 继续承担项目审计导入稿、时间线快照与代码图谱文件
- 图数据库实体/关系写入仅作为可选增强，不再写成“当前已稳定恢复”的事实

---

## 八、建议阅读顺序

1. `fact-source-boundary.md`：先确认当前 / 历史 / archived 边界
2. `quality-gate.md`：确认统一门禁入口、失败分类与日志路径
3. `overview.md`：再看项目入口、分层和主链路
4. `core-modules.md`：了解真实 Core 模块边界
5. `capability-graph.md`：看功能域、内容域、持久化层和入口面的关系
6. `ui-components.md`：了解 UI 场景与业务依赖
7. `quick-reference.md`：作为定位与排障索引
8. `risks-and-recommendations.md`：查看治理建议与下一步
9. `../m2-final-acceptance.md`：仅作为 2026-02-22 的历史验收证据
10. `../roadmap/2026-03-conditional-go-architecture-roadmap.md`：仅作为 Conditional Go 解冻合同来源

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-04-10
