# SpokenAnyWhere UI 组件体系

**版本**: 1.2
**更新时间**: 2026-03-23

---

## 一、UI 分层结构

UI 层按场景目录组织，核心样式来源仍为 `UI/Theme/DesignTokens.swift`。与旧文档相比，当前 UI 体系已经扩展出 `MessagePanel` 与 `Workflow` 等新场景。

| 场景 | 目录 | 关键视图 | 主要依赖 |
|------|------|----------|----------|
| Components | `UI/Components/` | `AttachmentPickerMenu.swift`、`TagBubbleView.swift`、`AddToDictionaryHandler.swift` | `AttachmentManager`、`MessagePanelState`、`TagLibrary`、`DictionaryService` |
| Dictionary | `UI/Dictionary/` | `DictionaryPanelView.swift`、`DictionaryPanelWindow.swift` | `DictionaryPanelManager`、`DictionaryDefinitionParser`、`LocalDictionaryService`、`VocabularyService` |
| HUD | `UI/HUD/` | `QuickAskCapsuleView.swift`、`QuickAskInputView.swift` | `RecordingController`、`QuickAskService`、`WorkflowState`、`AttachmentManager` |
| Live Caption | `UI/LiveCaption/` | `LiveCaptionView.swift`、`LiveCaptionWindow.swift`、`VocabularyHighlightText.swift` | `LiveCaptionManager`、`TranslationService`、`VocabularyService`、`UnifiedDictionaryService` |
| MessagePanel | `UI/MessagePanel/` | `MessagePanelView.swift`、`MessageCardView.swift`、`SessionHistoryListView.swift` | `MessagePanelManager`、`MessagePanelState`、`SessionHistoryService`、`SummaryService` |
| Quick Ask | `UI/QuickAsk/` | `AnswerPanelView.swift`、`AnswerPanelManager.swift`、`MarkdownWebView.swift` | `LLMPipeline`、`TTSService`、`WorkflowState`、`AttachmentManager` |
| Screenshot | `UI/Screenshot/` | `ScreenshotWindow.swift`、`ScreenshotContentView.swift`、`ActionBarView.swift` | `ScreenshotManager`、`ImageEnhancementService`、`QuickAskService` |
| Selection Toolbar | `UI/SelectionToolbar/` | `SelectionToolbarView.swift` | `SelectionToolbarState`、`SelectionToolbarManager`、`ToolbarConfigService` |
| Settings | `UI/Settings/` | `SettingsView.swift`、`GeneralSettingsContent.swift`、`AISettingsContent.swift` | `AppSettings`、`LLMSettings`、`TTSSettings`、`HistoryManager`、`ScreenshotSettings` |
| Theme | `UI/Theme/` | `DesignTokens.swift` | 样式令牌与全局视觉语义 |
| Workflow | `UI/Workflow/` | `WorkflowPickerView.swift`、`WorkflowTagView.swift` | `WorkflowState`、`WorkflowConfigService` |

---

## 二、当前 UI 特征

### 2.1 交互承载

- `HUD` 与 `QuickAsk` 承担即时输入与回答展示
- `MessagePanel` 承担 Pipeline 卡片流、历史浏览、标签筛选
- `Screenshot` 与 `LiveCaption` 依赖 AppKit 窗口/浮层行为
- `Settings` 集中暴露 AI、词典、截图、历史与快捷键配置

### 2.2 依赖方式

UI 层当前仍保留若干直接访问 `*.shared` 的高频入口，例如：

- `MessagePanelView`
- `QuickAskCapsuleView`
- `LiveCaptionView`
- `ActionBarView`
- `ScreenshotContentView`

因此 UI 层虽然目录结构清晰，但测试替换与预览隔离成本仍高；近期的收敛主要集中在 service/live factory 一侧，尚未系统性压到所有视图层。

### 2.3 样式系统

- 唯一样式源：`UI/Theme/DesignTokens.swift`
- 当前仓库中未发现 `docs/style/INDEX.md`
- 文档层面的设计系统说明应直接以 `DesignTokens.swift` 为准

---

## 三、建议阅读顺序

1. `HUD` / `QuickAsk`：理解即时输入体验
2. `MessagePanel`：理解 Pipeline 卡片流
3. `Screenshot` / `LiveCaption`：理解浮窗与 AppKit 协作
4. `Settings`：理解配置面与状态来源
5. `Workflow`：理解用户动作到 LLM 执行的扩展路径

---

## 四、配套文档

- 架构首页：`./overview.md`
- 当前状态审计：`./current-state-audit.md`
- 快速定位索引：`./quick-reference.md`
