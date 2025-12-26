# 功能-代码索引与链路图

更新: 2025-12-26

目标：让 docs/memo 成为“项目全链路与状态真相源”，能快速定位每个功能的实现位置、链路、状态与计划。

## 维护规则

- 状态优先级：代码实现 > memo > roadmap > PRD。
- 每条功能必须包含：状态标记 + 入口文件(path:line) + 核心链路描述。
- 状态标记：已完成[√]、部分完成[~]、未开始[ ]。
- 更新触发：新增功能/重构入口/链路变更/roadmap 迁移时必须同步此文档。
- 引用格式：`path:line`，便于快速跳转。

## 应用入口与生命周期

- App 入口：`spoke/App/SpokenlyApp.swift:5`
- 生命周期与初始化：`spoke/App/AppDelegate.swift:7`
  - RecordingController 启动与 HistoryManager 配置在此接入。

## 主链路（听写 -> 转录 -> LLM -> 输出 -> 历史 -> Pipeline）

1. 热键触发：`spoke/Services/HotKeyService.swift:8`
2. 录音会话控制：`spoke/Services/RecordingController.swift:9`
3. 音频采集：`spoke/Core/Audio/AudioRecorderService.swift:10`
4. 转录调度与模型选择：`spoke/Core/Transcription/TranscriptionManager.swift:30`
5. 转录引擎：`spoke/Core/Transcription/TranscriptionProvider.swift:78`
   - SpeechAnalyzer：`spoke/Core/Transcription/Providers/SpeechAnalyzerProvider.swift:11`
   - SFSpeech 回退：`spoke/Core/Transcription/Providers/SFSpeechProvider.swift:9`
6. 文本后处理/词典注入：
   - 后处理：`spoke/Core/Transcription/TranscriptionPostProcessor.swift:10`
   - 词典：`spoke/Core/Dictionary/DictionaryService.swift:10`
   - 词典注入协议：`spoke/Core/Dictionary/DictionaryInjector.swift:10`
7. LLM 精炼：`spoke/Core/LLM/LLMPipeline.swift:7`
   - Provider 协议：`spoke/Core/LLM/LLMProvider.swift:326`
   - 设置与 Profile：`spoke/Core/LLM/LLMSettings.swift:8`
8. 输出与输入：`spoke/Services/InputService.swift:9`
9. 历史存储：`spoke/Services/HistoryManager.swift:9`
10. Pipeline 展示：
    - 状态：`spoke/Core/MessagePanel/MessagePanelState.swift:420`
    - 窗口：`spoke/Services/MessagePanelManager.swift:8`
    - UI：`spoke/UI/MessagePanel/MessagePanelView.swift:110`

## 功能矩阵（实现位置 + 状态）

| 功能 | 状态 | 核心实现(文件) | UI/入口 | 备注/计划 |
| --- | --- | --- | --- | --- |
| 听写录音/热键 | [√] | `spoke/Services/HotKeyService.swift:8`; `spoke/Services/RecordingController.swift:9` | `spoke/UI/HUD/FloatingCapsuleView.swift:8` | 长按 ESC 取消待补充 |
| 转录模型管理 | [√] | `spoke/Core/Transcription/Models/TranscriptionModelManager.swift:8` | `spoke/UI/Settings/TranscriptionModelSettingsView.swift:20` | 预编译 LM 已接入 |
| 词典注入/纠错 | [√] | `spoke/Core/Dictionary/DictionaryService.swift:10` | `spoke/UI/Settings/DictionarySettingsView.swift:9` | 双轨注入已完成 |
| LLM Pipeline | [√] | `spoke/Core/LLM/LLMPipeline.swift:7` | `spoke/UI/QuickAsk/AnswerPanelView.swift:72` | 多 Provider 已支持 |
| Quick Ask | [√] | `spoke/Services/QuickAskService.swift:26` | `spoke/UI/HUD/QuickAskInputView.swift:12` | 双击 ⌥ 触发 |
| Workflow | [√] | `spoke/Core/Workflow/WorkflowExecutor.swift:10` | `spoke/UI/Workflow/WorkflowPickerView.swift:5` | /keyword 已完成 |
| 实时字幕 | [~] | `spoke/Core/LiveCaption/LiveCaptionManager.swift:40` | `spoke/UI/LiveCaption/LiveCaptionView.swift:400` | 多语言仍需完善 |
| 划词工具栏 | [√] | `spoke/Services/SelectionMonitorService.swift:11` | `spoke/UI/SelectionToolbar/SelectionToolbarView.swift:32` | Terminal 支持待研究 |
| 截图钉图/标注 | [√] | `spoke/Core/Screenshot/ScreenshotManager.swift:11` | `spoke/UI/Screenshot/ScreenshotWindow.swift:8` | Space 绑定受限 |
| 词典面板 | [√] | `spoke/Services/LocalDictionaryService.swift:83` | `spoke/UI/Dictionary/DictionaryPanelView.swift:9` | ⌥+Space 已支持 |
| 统一查词服务 | [~] | `spoke/Services/UnifiedDictionaryService.swift:81` | `spoke/UI/SelectionToolbar/DictionaryResultView.swift:3` | 当前重点 |
| Pipeline 面板 | [√] | `spoke/Core/MessagePanel/MessagePanelState.swift:420` | `spoke/UI/MessagePanel/MessagePanelView.swift:110` | 支持卡片/标签 |
| App Store 合规 | [ ] | `docs/outline/app_store_compliance.md:1` | - | entitlements + 沙盒迁移 |

## 子系统链路（重点功能）

### Quick Ask 链路
- 触发与会话：`spoke/Services/QuickAskService.swift:26` → `spoke/Core/QuickAsk/QuickAskState.swift:22`
- 输入与附件：`spoke/UI/HUD/QuickAskInputView.swift:12` → `spoke/Core/Attachment/AttachmentManager.swift:39`
- LLM 与输出：`spoke/Core/LLM/LLMPipeline.swift:7` → `spoke/UI/QuickAsk/AnswerPanelView.swift:72`
- 历史：`spoke/Core/History/SessionHistoryService.swift:124`

### 实时字幕链路
- 系统音频捕获：`spoke/Core/LiveCaption/SystemAudioCaptureService.swift:12`
- 应用选择模式：`spoke/Core/LiveCaption/AppAudioCaptureService.swift:12`
- 转录/稳定化：`spoke/Core/LiveCaption/LiveCaptionManager.swift:40` → `spoke/Core/LiveCaption/CaptionLineBuffer.swift:38`
- UI 展示：`spoke/UI/LiveCaption/LiveCaptionView.swift:400`
- 生词系统：`spoke/Services/VocabularyService.swift:24` → `spoke/Services/UnifiedDictionaryService.swift:81`

### 划词工具栏链路
- 监听：`spoke/Services/SelectionMonitorService.swift:11`
- 窗口与状态：`spoke/Services/SelectionToolbarManager.swift:10` → `spoke/Core/SelectionToolbar/SelectionToolbarState.swift:50`
- 动作执行：`spoke/Services/SelectionActionService.swift:9`
- UI：`spoke/UI/SelectionToolbar/SelectionToolbarView.swift:32`

### 截图钉图链路
- 管理器：`spoke/Core/Screenshot/ScreenshotManager.swift:11`
- Window/View：`spoke/UI/Screenshot/ScreenshotWindow.swift:8` → `spoke/UI/Screenshot/ScreenshotContentView.swift:10`
- 截图与增强：`spoke/Core/Attachment/ScreenCaptureService.swift:11` → `spoke/Services/ImageEnhancementService.swift:10`

### 字典面板链路
- 面板状态/窗口：`spoke/UI/Dictionary/DictionaryPanelState.swift:18` → `spoke/UI/Dictionary/DictionaryPanelView.swift:9`
- 本地词典：`spoke/Services/LocalDictionaryService.swift:83`
- 解析渲染：`spoke/Services/DictionaryDefinitionParser.swift:48` → `spoke/UI/Dictionary/FormattedDefinitionView.swift:5`

### Pipeline 面板链路
- 记录流入：`spoke/Services/RecordingController.swift:9` / `spoke/Services/ClipboardPipelineService.swift:7`
- 状态管理：`spoke/Core/MessagePanel/MessagePanelState.swift:420`
- UI 展示：`spoke/UI/MessagePanel/MessagePanelView.swift:110`

## 相关文档索引

- 路线图：`docs/roadmap.md:1`
- 合规矩阵：`docs/outline/app_store_compliance.md:1`
- 设计总览：`docs/design.md:1`
- LLM Pipeline 设计：`docs/design-llm-pipeline.md:1`
- Live Caption 设计：`docs/memo/design-live-caption.md:22`
- Quick Ask 设计：`docs/design-quick-ask.md:1`
- Workflow 设计：`docs/design-workflow.md:1`
- Docs 维护清单：`docs/memo/docs-maintenance.md:1`
