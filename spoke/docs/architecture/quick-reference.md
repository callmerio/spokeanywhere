# SpokenAnyWhere 快速导航索引

**版本**: 1.4
**更新时间**: 2026-04-07

本文档提供“功能 -> 入口文件 -> 主链路 -> 验证命令”的快速映射。

---

## 一、按功能查找

### 1.1 语音输入

| 功能 | 入口文件 | 关键类型 |
|------|---------|----------|
| 录音控制 | `Services/RecordingController.swift` | `RecordingController` |
| 音频采集 | `Core/Audio/AudioRecorderService.swift` | `AudioRecorderService` |
| 转录管理 | `Core/Transcription/TranscriptionManager.swift` | `TranscriptionManager` |
| Apple STT | `Core/Transcription/Providers/SFSpeechProvider.swift` | `SFSpeechProvider` |
| Speech Analyzer | `Core/Transcription/Providers/SpeechAnalyzerProvider.swift` | `SpeechAnalyzerProvider` |

主链路：

`HotKeyService -> VoiceHandler -> RecordingController -> AudioRecorderService -> TranscriptionManager`

### 1.2 Quick Ask

| 功能 | 入口文件 | 关键类型 |
|------|---------|----------|
| 会话编排 | `Services/QuickAskService.swift` | `QuickAskService` |
| 对话状态 | `Core/QuickAsk/QuickAskState.swift` | `QuickAskState` |
| LLM 管道 | `Core/LLM/LLMPipeline.swift` | `LLMPipeline` |
| Workflow 扩展 | `Core/Workflow/WorkflowExecutor.swift` | `WorkflowExecutor` |
| 对话 UI | `UI/QuickAsk/AnswerPanelView.swift` | `AnswerPanelView` |

主链路：

`HotKeyService -> QuickAskHandler -> QuickAskService -> LLMPipeline`

### 1.3 截图

| 功能 | 入口文件 | 关键类型 |
|------|---------|----------|
| 截图管理 | `Core/Screenshot/ScreenshotManager.swift` | `ScreenshotManager` |
| 区域捕获 | `Core/Attachment/ScreenCaptureService.swift` | `ScreenCaptureService` |
| 截图项 | `Core/Screenshot/ScreenshotItem.swift` | `ScreenshotItem` |
| 截图窗口 | `UI/Screenshot/ScreenshotWindow.swift` | `ScreenshotWindow` |
| 操作栏 | `UI/Screenshot/ActionBarView.swift` | `ActionBarView` |

主链路：

`HotKeyService -> ScreenshotHandler -> ScreenshotManager -> ScreenCaptureService`

### 1.4 实时字幕

| 功能 | 入口文件 | 关键类型 |
|------|---------|----------|
| 字幕管理 | `Core/LiveCaption/LiveCaptionManager.swift` | `LiveCaptionManager` |
| 实时转录 | `Core/LiveCaption/LiveCaptionTranscriber.swift` | `LiveCaptionTranscriber` |
| 系统音频 | `Core/LiveCaption/SystemAudioCaptureService.swift` | `SystemAudioCaptureService` |
| 应用音频 | `Core/LiveCaption/AppAudioCaptureService.swift` | `AppAudioCaptureService` |
| 字幕 UI | `UI/LiveCaption/LiveCaptionView.swift` | `LiveCaptionView` |

主链路：

`HotKeyService -> CaptionHandler -> LiveCaptionManager -> SystemAudioCaptureService -> LiveCaptionTranscriber`

### 1.5 Message Panel / Clipboard Pipeline

| 功能 | 入口文件 | 关键类型 |
|------|---------|----------|
| 面板管理 | `Services/MessagePanelManager.swift` | `MessagePanelManager` |
| 面板状态 | `Core/MessagePanel/MessagePanelState.swift` | `MessagePanelState` |
| 会话历史 | `Core/History/SessionHistoryService.swift` | `SessionHistoryService` |
| 摘要生成 | `Services/SummaryService.swift` | `SummaryService` |
| 剪贴板注入 | `Services/ClipboardPipelineService.swift` | `ClipboardPipelineService` |
| 剪贴板历史 | `Services/ClipboardHistoryService.swift` | `ClipboardHistoryService` |
| 主视图 | `UI/MessagePanel/MessagePanelView.swift` | `MessagePanelView` |

主链路：

`ClipboardPipelineService -> MessagePanelManager -> MessagePanelState`

### 1.6 文本选择工具栏

| 功能 | 入口文件 | 关键类型 |
|------|---------|----------|
| 选择监控 | `Services/SelectionMonitorService.swift` | `SelectionMonitorService` |
| 工具栏管理 | `Services/SelectionToolbarManager.swift` | `SelectionToolbarManager` |
| 动作执行 | `Services/SelectionActionService.swift` | `SelectionActionService` |
| 状态管理 | `Core/SelectionToolbar/SelectionToolbarState.swift` | `SelectionToolbarState` |
| 工具栏 UI | `UI/SelectionToolbar/SelectionToolbarView.swift` | `SelectionToolbarView` |

主链路：

`SelectionMonitorService -> SelectionToolbarManager -> SelectionActionService`

### 1.7 词典与生词

| 功能 | 入口文件 | 关键类型 |
|------|---------|----------|
| 统一词典 | `Core/Dictionary/UnifiedDictionaryService.swift` | `UnifiedDictionaryService` |
| 本地词典 | `Core/Dictionary/Providers/LocalDictionaryService.swift` | `LocalDictionaryService` |
| 远程词典 | `Core/Dictionary/Providers/RemoteProvider.swift` | `RemoteProvider` |
| 词典注入 | `Core/Dictionary/DictionaryInjector.swift` | `DictionaryInjector` |
| 生词服务 | `Services/VocabularyService.swift` | `VocabularyService` |
| 词典面板 | `UI/Dictionary/DictionaryPanelView.swift` | `DictionaryPanelView` |

### 1.8 Workflow 与翻译

| 功能 | 入口文件 | 关键类型 |
|------|---------|----------|
| Workflow 状态 | `Core/Workflow/WorkflowState.swift` | `WorkflowState` |
| Workflow 执行 | `Core/Workflow/WorkflowExecutor.swift` | `WorkflowExecutor` |
| Workflow 选择器 | `UI/Workflow/WorkflowPickerView.swift` | `WorkflowPickerView` |
| 翻译服务 | `Core/Translation/TranslationService.swift` | `TranslationService` |

### 1.9 设置 / 状态栏 / 历史

| 功能 | 入口文件 | 关键类型 |
|------|---------|----------|
| 状态栏与菜单 | `App/AppDelegate.swift` | `AppDelegate` |
| 设置主界面 | `UI/Settings/SettingsView.swift` | `SettingsView` |
| 应用设置 | `Services/AppSettings.swift` | `AppSettings` |
| 历史记录管理 | `Services/HistoryManager.swift` | `HistoryManager` |
| SwiftData 模型 | `Core/DataModels.swift` | `HistoryItem` / `AppRule` / `AIProviderConfig` |

补充事实：

- 菜单栏当前直接暴露了“实时字幕 / 选择工具栏 / 区域截图 / 查词 / 设置”这些用户入口。
- `SettingsView` 当前包含 `常规 / 截图 / 划词工具栏 / 听写模型 / AI 处理 / 词典 / 语音合成 / 快捷键 / 历史记录` 九个标签页。

---

## 二、按入口查找

### 2.1 应用入口

- `App/SpokenlyApp.swift`
- `App/AppDelegate.swift`

### 2.2 热键入口

- `Services/HotKeyService.swift`
- `Services/HotKey/HotKeyRegistry.swift`
- `Services/HotKey/Handlers/*.swift`

### 2.3 设置入口

- `UI/Settings/SettingsView.swift`
- `Services/AppSettings.swift`
- `Core/LLM/LLMSettings.swift`
- `Services/TTSSettings.swift`

### 2.4 状态栏 / 菜单栏入口

- `App/AppDelegate.swift`
- `Services/MessagePanelManager.swift`
- `UI/Dictionary/DictionaryPanelView.swift`

### 2.5 面板与浮窗入口

- `UI/HUD/QuickAskCapsuleView.swift`
- `UI/QuickAsk/AnswerPanelManager.swift`
- `Services/MessagePanelManager.swift`
- `Core/Screenshot/ScreenshotManager.swift`
- `Core/LiveCaption/LiveCaptionManager.swift`

---

## 三、按数据模型查找

### 3.1 SwiftData 持久化模型

| 模型 | 文件 | 用途 |
|------|------|------|
| `HistoryItem` | `Core/DataModels.swift` | 历史记录 |
| `AppRule` | `Core/DataModels.swift` | 应用规则 |
| `AIProviderConfig` | `Core/DataModels.swift` | AI 提供商配置 |

### 3.2 核心状态模型

| 模型 | 文件 | 用途 |
|------|------|------|
| `RecordingState` | `Core/RecordingState.swift` | 录音状态与错误 |
| `QuickAskState` | `Core/QuickAsk/QuickAskState.swift` | Quick Ask 会话状态 |
| `MessagePanelState` | `Core/MessagePanel/MessagePanelState.swift` | Pipeline 卡片流 |
| `SelectionToolbarState` | `Core/SelectionToolbar/SelectionToolbarState.swift` | 选区工具栏状态 |
| `ScreenshotItem` | `Core/Screenshot/ScreenshotItem.swift` | 截图项 |
| `DictionaryEntry` | `Core/Dictionary/Models/DictionaryEntry.swift` | 词典条目 |
| `CardTag` | `Core/Tags/CardTag.swift` | 标签模型 |

### 3.3 其他持久化载体

| 载体 | 文件 / 位置 | 用途 |
|------|-------------|------|
| `AppStorage` / `UserDefaults` | `Services/AppSettings.swift` | 快捷键、显示模式、历史清理、截图 / 工具栏 / 实时字幕设置 |
| 剪贴板历史 JSON | `Services/ClipboardHistoryService.swift` | 静默保存剪贴板历史作为上下文 |
| 截图项 JSON | `Core/Screenshot/ScreenshotManager.swift` | 保存并恢复 pinned screenshots |
| 截图图片文件 | `~/Library/Application Support/Spoke/Screenshots/` | screenshot image assets |
| 录音音频文件 | `~/Library/Application Support/Spoke/Audio/` | 历史录音文件 |
| Keychain | `Core/LLM/KeychainService.swift` | LLM / provider 凭据 |

---

## 四、验证命令

### 4.1 当前有效命令

```bash
scripts/verify/run-architecture-quality-gate.sh
swift build
swift test
bash Tests/run-concurrency-check.sh
rg -n "\.shared\." App Core Services UI
rg -n "NotificationCenter\.default\.(addObserver|post)" App Core Services UI
```

### 4.2 2026-03-23 复算结果

- `swift test`：`150 tests / 30 suites` 通过
- `run-concurrency-check.sh`：`0 warnings`

### 4.3 当前补充事实

- `Services/ServiceContainerLiveDependencies.swift` 已承接 `ServiceContainerDependencies.live` 的默认装配，`ServiceContainer.swift` 不再内联整段 live defaults。
- `QuickAskLiveDependencies.swift`、`RecordingControllerLiveDependencies.swift`、`SelectionMonitorLiveDependencies.swift` 与 `WorkflowExecutorLiveDependencies.swift` 已完成多轮收敛。
- `Services/RuntimeBridgeHelpers.swift` 现为 Recording / Quick Ask / Selection 系列 runtime helper 的共享主线程与定时器桥接入口。
- `Services/MessagePanelRuntimeHelpers.swift`、`UI/Screenshot/ScreenshotContentRuntimeHelpers.swift`、`Core/Attachment/AttachmentRuntimeHelpers.swift`、`Core/Audio/AudioRecorderRuntimeHelpers.swift` 与 `Core/LiveCaption/LiveCaptionManagerRuntimeHelpers.swift` 已覆盖 round 19-24 的生产路径桥接收敛。
- `UI/MessagePanel/MessagePanelView.swift`、`UI/LiveCaption/LiveCaptionView.swift` 与 `UI/HUD/QuickAskCapsuleView.swift` 的 preview/shared 入口已收口，后续不应再把 preview 视图直接绑到 `.shared`。
- `ScreenshotManager.saveAll()/restoreAll()` 只负责 `pinned screenshots` 的功能资产持久化；后续若建设权限平台，不应把它和 `blocked intent` 状态混为一类。

### 4.4 统一质量门禁入口

- Provider-neutral 入口：`scripts/verify/run-architecture-quality-gate.sh`
- 默认日志目录：`verify/quality-gate/<timestamp>/`
- 当前扫描策略：
  - `swift build` / `swift test` / strict concurrency 为硬失败项
  - `.shared` 与 `NotificationCenter` 扫描默认保留为 repo-owned 报告，不在 Wave 0 直接当作 hard fail

### 4.5 最小规则快答

- `.shared`：默认只允许落在 `*LiveDependencies.swift`、组合根和测试/预览工厂
- `NotificationCenter`：默认只允许跨窗口 / 跨 feature / app-scope 广播
- 新状态落点：只有设置、用户资产、secret、capability cache 才能进现有持久化载体
- 详细规则：`./minimal-rule-pack.md`

### 4.6 当前仓库缺失项

以下路径在本次仓库快照中不存在，不应继续作为导航入口引用：

- `.github/workflows/test.yml`
- `.github/workflows/perf-startup.yml`
- `docs/style/INDEX.md`

---

## 五、文档索引

| 文档 | 路径 | 说明 |
|------|------|------|
| 事实真源与历史边界 | `./fact-source-boundary.md` | 当前 / 历史 / archived 边界与架构同步清单 |
| P1 生命周期 Inventory | `./p1-lifecycle-inventory.md` | 六个热点对象的 owner / register / cleanup 矩阵 |
| 最小规则包 | `./minimal-rule-pack.md` | `.shared` / `NotificationCenter` / 状态落点的最小约束 |
| 前台交互 Coverage Matrix | `./foreground-interaction-coverage-matrix.md` | guardrail sample / 主试点 / proof map |
| AnswerPanel 主试点 Proof Map | `./answer-panel-pilot-proof-map.md` | open / close / focus / error / permission 证据链 |
| Screenshot 主试点 Proof Map | `./screenshot-pilot-proof-map.md` | save / restore / action dispatch / window chain / Quick Ask dispatch 证据链 |
| RecordingController Move List | `./recording-controller-concern-move-list.md` | Recording orchestrator concern move list 与 naming crosswalk |
| QuickAsk 行为矩阵 | `./quickask-service-behavior-matrix.md` | Quick Ask 主链行为矩阵与 concern move list |
| Shared Hot Path Contract | `./shared-hot-path-contract.md` | Recording / Quick Ask 共享热路径合同 |
| 依赖通道决策矩阵 | `./dependency-channel-decision-matrix.md` | dependency channel、state crosswalk、NotificationCenter allowlist |
| Conditional Go 复核 | `./conditional-go-review-2026-04-10.md` | 5 条解冻条件复核与最终结论 |
| 新贡献者指南 | `./new-contributor-guide.md` | 新人上手必读：项目定位、阅读顺序、常见任务 |
| 当前状态审计 | `./current-state-audit.md` | 当前事实基线与文档偏差 |
| 项目架构全景 | `./overview.md` | 架构首页 |
| 能力关系图 | `./capability-graph.md` | 功能域、内容域、持久化层与入口面的关系图 |
| 核心模块详解 | `./core-modules.md` | Core/ 深度分析 |
| UI 组件体系 | `./ui-components.md` | UI/ 组件说明 |
| 风险与改进建议 | `./risks-and-recommendations.md` | 治理建议 |
| 统一质量门禁说明 | `./quality-gate.md` | 统一门禁入口、失败分类、日志与复现路径 |
| 启动序列分析 | `./app-layer-startup-sequence.md` | AppDelegate 启动时序与依赖链 |
| 回调链分析 | `./app-layer-callback-chains.md` | 跨服务回调追踪 |
| 风险评估 | `./app-layer-risk-assessment.md` | App 层风险评估 |
| M2 并发告警收敛 | `../m2-final-acceptance.md` | 2026-02-22 历史验收文档 |

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-04-10
