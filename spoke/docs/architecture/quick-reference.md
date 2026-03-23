# SpokenAnyWhere 快速导航索引

**版本**: 1.3
**更新时间**: 2026-03-23

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

### 1.5 Message Panel / Pipeline

| 功能 | 入口文件 | 关键类型 |
|------|---------|----------|
| 面板管理 | `Services/MessagePanelManager.swift` | `MessagePanelManager` |
| 面板状态 | `Core/MessagePanel/MessagePanelState.swift` | `MessagePanelState` |
| 会话历史 | `Core/History/SessionHistoryService.swift` | `SessionHistoryService` |
| 摘要生成 | `Services/SummaryService.swift` | `SummaryService` |
| 主视图 | `UI/MessagePanel/MessagePanelView.swift` | `MessagePanelView` |

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

---

## 四、验证命令

### 4.1 当前有效命令

```bash
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
### 4.4 当前仓库缺失项

以下路径在本次仓库快照中不存在，不应继续作为导航入口引用：

- `.github/workflows/test.yml`
- `.github/workflows/perf-startup.yml`
- `docs/style/INDEX.md`

---

## 五、文档索引

| 文档 | 路径 | 说明 |
|------|------|------|
| 当前状态审计 | `./current-state-audit.md` | 当前事实基线与文档偏差 |
| 项目架构全景 | `./overview.md` | 架构首页 |
| 核心模块详解 | `./core-modules.md` | Core/ 深度分析 |
| UI 组件体系 | `./ui-components.md` | UI/ 组件说明 |
| 风险与改进建议 | `./risks-and-recommendations.md` | 治理建议 |
| M2 并发告警收敛 | `../m2-final-acceptance.md` | 2026-02-22 历史验收文档 |

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-03-23
