# SpokenAnyWhere 当前状态审计

**版本**: 1.2
**审计日期**: 2026-03-23
**审计范围**: 仓库结构、架构分层、文档一致性、测试与并发门禁、记忆落地状态

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

从“可持续演进”角度看，项目当前仍更适合标记为 **Conditional Go**：

- 运行时主干仍以单例为基础，但高频 orchestrator / live factory 已完成多轮收敛
- UI 对业务层的直接依赖仍然存在，尤其集中在少数高频视图层
- 依赖通道并存，缺少统一治理
- 自动化门禁的版本化证据缺失
- 文档与实际代码之间存在持续漂移

本轮新增的结构收敛：

- `SelectionMonitorService` 已拆出 `SelectionMonitorLiveDependencies` 与 `SelectionMonitorRuntimeHelpers`，将 debounce / AX bridge / live wiring 从主文件热路径中分离。
- `WorkflowExecutor` 已拆出 `WorkflowExecutorLiveDependencies` 与 `WorkflowProfileResolver`，并新增 `WorkflowProfileResolverTests` 作为 profile fallback 的表征测试。
- `QuickAskLiveDependencies` 与 `RecordingControllerLiveDependencies` 已完成 live factory 收敛，主文件不再保留成组 `*.shared` 与 responder-chain 内联样板。
- `ServiceContainerLiveDependencies` 已承接 `ServiceContainerDependencies.live` 的默认装配，容器主文件不再内联整段默认 wiring。
- `Services/RuntimeBridgeHelpers.swift` 已成为 Recording / Quick Ask / Selection 系列 runtime helper 的共享主线程、定时器与轮询桥接入口。
- `Services/MessagePanelRuntimeHelpers.swift`、`UI/Screenshot/ScreenshotContentRuntimeHelpers.swift`、`Core/Attachment/AttachmentRuntimeHelpers.swift`、`Core/Audio/AudioRecorderRuntimeHelpers.swift` 与 `Core/LiveCaption/LiveCaptionManagerRuntimeHelpers.swift` 已把 MessagePanel / Screenshot / Attachment / Audio / LiveCaptionManager 的生产路径桥接样板继续从主文件中剥离。
- `MessagePanelView`、`LiveCaptionView` 与 `QuickAskCapsuleView` 的 preview/shared 入口已在 round 18 改为 preview factory 或显式依赖，不再把视图本体直接系在 `.shared` 上。
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

1. `overview.md`：先看项目入口、分层和主链路
2. `core-modules.md`：了解真实 Core 模块边界
3. `ui-components.md`：了解 UI 场景与业务依赖
4. `quick-reference.md`：作为定位与排障索引
5. `risks-and-recommendations.md`：查看治理建议与下一步
6. `../m2-final-acceptance.md`：仅作为 2026-02-22 的历史验收证据
7. `../roadmap/2026-03-conditional-go-architecture-roadmap.md`：基于本次审计拆出的执行路线

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-03-23
