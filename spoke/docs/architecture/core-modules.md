# SpokenAnyWhere 核心模块详解

**版本**: 1.1
**更新时间**: 2026-03-19

---

## 一、模块总览

Core 层当前不再只包含语音、截图、词典等主线模块，已经扩展出 Workflow、MessagePanel、Translation、History、Tags 等多个业务域。

### 1.1 业务域模块

| 模块 | 目录 | 入口实现 | 关键职责 |
|------|------|----------|----------|
| Attachment | `Core/Attachment/` | `AttachmentManager.swift` | 附件接收、屏幕捕获、文件与图片接入 |
| Audio | `Core/Audio/` | `AudioRecorderService.swift` | 音频录制、回调路由、恢复策略 |
| Debug | `Core/Debug/` | `CrashLogger.swift` | 崩溃记录、性能追踪、资源监控 |
| Dictionary | `Core/Dictionary/` | `UnifiedDictionaryService.swift` | 本地/远程词典聚合、注入与解析 |
| History | `Core/History/` | `SessionHistoryService.swift` | 会话级历史检索与展示 |
| LLM | `Core/LLM/` | `LLMPipeline.swift` | Provider 抽象、聊天与文本处理 |
| LiveCaption | `Core/LiveCaption/` | `LiveCaptionManager.swift` | 系统/应用音频字幕、翻译刷新、稳定化 |
| MessagePanel | `Core/MessagePanel/` | `MessagePanelState.swift` | Pipeline 卡片状态、附件与标签协同 |
| QuickAsk | `Core/QuickAsk/` | `QuickAskState.swift` | Quick Ask 会话状态、附件接入 |
| Screenshot | `Core/Screenshot/` | `ScreenshotManager.swift` | 截图生命周期、恢复、增强协同 |
| SelectionToolbar | `Core/SelectionToolbar/` | `SelectionToolbarState.swift` | 选区上下文、工具栏显示状态与动作元数据 |
| Tags | `Core/Tags/` | `TagLibrary.swift` | 标签模型、颜色、筛选与删除事件 |
| Testing | `Core/Testing/` | `UITestIdentifiers.swift` | UI 测试标识与测试辅助常量 |
| Transcription | `Core/Transcription/` | `TranscriptionManager.swift` | ASR Provider 管理、模型配置、字典准备 |
| Translation | `Core/Translation/` | `TranslationService.swift` | Apple Translation API 封装、缓存与语言清单 |
| Workflow | `Core/Workflow/` | `WorkflowExecutor.swift` | Workflow Prompt 构建、模型选择、输出分发 |

### 1.2 横切文件

| 文件 | 职责 |
|------|------|
| `Core/DataModels.swift` | SwiftData 持久化模型定义 |
| `Core/RecordingState.swift` | 录音状态机与错误表示 |

### 1.3 占位目录

以下目录当前存在，但本次仓库快照下未见受跟踪源码文件：

- `Core/Errors/`
- `Core/Metal/`

建议后续如果仍作为保留目录存在，在 README 或架构文档中说明其预期用途。

---

## 二、关键调用关系

### 2.1 录音主链路

`RecordingController -> AudioRecorderService -> TranscriptionManager -> HistoryManager / LLMPipeline`

### 2.2 Quick Ask

`QuickAskService -> AudioRecorderService -> LLMPipeline -> AnswerPanelManager`

### 2.3 实时字幕

`LiveCaptionManager -> SystemAudioCaptureService / AppAudioCaptureService -> LiveCaptionTranscriber -> TranslationService`

### 2.4 截图

`ScreenshotManager -> ScreenCaptureService -> ImageEnhancementService -> ScreenshotWindow`

### 2.5 Workflow

`WorkflowState / WorkflowPickerView -> WorkflowExecutor -> LLMPipeline -> clipboard/panel 输出`

### 2.6 Message Panel

`MessagePanelManager -> MessagePanelState -> SessionHistoryService / SummaryService / TagLibrary`

---

## 三、模块观察

### 3.1 当前最重的枢纽

- `TranscriptionManager`
- `LLMPipeline`
- `ScreenshotManager`
- `MessagePanelState`
- `WorkflowExecutor`

### 3.2 设计特征

- Core 层既包含纯业务模块，也承担部分状态管理职责
- 多个模块仍通过 `*.shared` 直接互调
- `Workflow`、`Translation`、`MessagePanel` 已经从“附属功能”演变为独立业务域

---

## 四、配套文档

- 架构首页：`./overview.md`
- 当前状态审计：`./current-state-audit.md`
- 功能定位索引：`./quick-reference.md`
- 风险与收敛建议：`./risks-and-recommendations.md`
