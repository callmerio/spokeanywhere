# SpokenAnyWhere UI 组件体系

**版本**: 1.0  
**更新时间**: 2026-02-22

---

## 一、UI 分层结构

UI 层按场景目录组织，核心样式由 `DesignTokens` 统一驱动。

| 场景 | 目录 | 关键视图 | 关联服务/核心模块 |
|------|------|----------|-------------------|
| HUD | `UI/HUD/` | `FloatingCapsuleView.swift` | `RecordingController.swift`, `QuickAskService.swift` |
| Quick Ask | `UI/QuickAsk/` | `AnswerPanelView.swift` | `LLMPipeline.swift` |
| Live Caption | `UI/LiveCaption/` | `LiveCaptionView.swift` | `LiveCaptionManager.swift` |
| Screenshot | `UI/Screenshot/` | `ScreenshotWindow.swift` | `ScreenshotManager.swift` |
| Settings | `UI/Settings/` | `SettingsView.swift` | `AppSettings.swift`, `ServiceContainer.swift` |
| Selection Toolbar | `UI/SelectionToolbar/` | `SelectionToolbarView.swift` | `SelectionMonitorService.swift` |
| Dictionary | `UI/Dictionary/` | `DictionaryPanelView.swift` | `UnifiedDictionaryService.swift` |

---

## 二、样式与复用组件

1. 唯一样式来源：`UI/Theme/DesignTokens.swift`
2. 通用组件目录：`UI/Components/`
3. 关键可复用组件：
   - `DictionarySelectableText.swift`
   - `AttachmentThumbnailView.swift`
   - `ScreenCaptureBlurBackground.swift`

---

## 三、配套文档

- 架构全景：`./overview.md`
- 快速定位索引：`./quick-reference.md`
- 设计系统：`../../../docs/style/INDEX.md`

