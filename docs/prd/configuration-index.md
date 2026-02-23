# 配置项索引

> 版本: v1.0
> 创建时间: 2026-02-23
> 用途: 快速查找配置项及其文档位置

---

## 配置项分类

### 1. 通用设置 (General Settings)

| setting_key | owner | read-path | write-path | 生效语义 | dependencies | side_effects |
|-------------|-------|-----------|------------|----------|--------------|--------------|
| `startAtLogin` | AppSettings.swift:57 | AppSettings.swift:58-66 (didSet) | GeneralSettingsContent.swift | 即时 | SMAppService | 登录项注册/注销 |
| `showInDock` | AppSettings.swift:68 | AppSettings.swift:69-77 (didSet) | GeneralSettingsContent.swift | 即时 | NSApp.setActivationPolicy | Dock 图标显示/隐藏 |
| `showInMenuBar` | AppSettings.swift:79 | 多处读取 | GeneralSettingsContent.swift | 即时 | 无 | 菜单栏图标显示/隐藏 |
| `pressEscToCancel` | AppSettings.swift | 录音/Quick Ask 流程 | GeneralSettingsContent.swift | 即时 | 无 | Esc 键取消行为 |
| `playSoundEffect` | AppSettings.swift | 录音/Quick Ask 流程 | GeneralSettingsContent.swift | 即时 | 无 | 音效播放 |
| `recordingMode` | AppSettings.swift | HotKeyService.swift | GeneralSettingsContent.swift | 即时 | 无 | 录音触发模式 |
| `realtimeTypingEnabled` | AppSettings.swift | RecordingController.swift | GeneralSettingsContent.swift | 即时 | InputService | 实时打字输出 |
| `clipboardHistoryEnabled` | AppSettings.swift | ClipboardHistoryService.swift | GeneralSettingsContent.swift | 即时 | ClipboardHistoryService | 剪贴板历史记录 |
| `clipboardHistoryLimit` | AppSettings.swift | ClipboardHistoryService.swift | GeneralSettingsContent.swift | 即时 | clipboardHistoryEnabled | 历史条数限制 |
| `startupDiagnosticsEnabled` | AppSettings.swift | AppDelegate.swift | GeneralSettingsContent.swift | 重启 | 无 | 启动诊断日志 |

**配置位置**: `spoke/Services/AppSettings.swift`
**详细文档**: [通用设置详细文档](./config-general.md)

---

### 2. 历史清理 (History Cleanup)

| setting_key | owner | read-path | write-path | 生效语义 | dependencies | side_effects |
|-------------|-------|-----------|------------|----------|--------------|--------------|
| `historyAutoCleanupEnabled` | AppSettings.swift | HistoryManager.swift | **UI 未实现** | 即时 | 无 | 自动清理任务启动/停止 |
| `historyKeepDays` | AppSettings.swift | HistoryManager.swift | **UI 未实现** | 即时 | historyAutoCleanupEnabled | 清理保留天数 |
| `historyMaxCount` | AppSettings.swift | HistoryManager.swift | **UI 未实现** | 即时 | historyAutoCleanupEnabled | 清理最大数量 |

**配置位置**: `spoke/Services/AppSettings.swift`
**详细文档**: [历史清理详细文档](./config-history.md)

---

### 3. 快捷键 (Shortcuts)

| setting_key | owner | read-path | write-path | 生效语义 | dependencies | side_effects |
|-------------|-------|-----------|------------|----------|--------------|--------------|
| `shortcutKeyCode` | AppSettings.swift | HotKeyService.swift | ShortcutsSettingsContent.swift | 即时 | HotKeyService | NotificationCenter 通知 |
| `shortcutModifiers` | AppSettings.swift | HotKeyService.swift | ShortcutsSettingsContent.swift | 即时 | HotKeyService | NotificationCenter 通知 |
| `quickAskKeyCode` | AppSettings.swift | HotKeyService.swift | ShortcutsSettingsContent.swift | 即时 | HotKeyService | NotificationCenter 通知 |
| `quickAskModifiers` | AppSettings.swift | HotKeyService.swift | ShortcutsSettingsContent.swift | 即时 | HotKeyService | NotificationCenter 通知 |
| `messagePanelKeyCode` | AppSettings.swift | HotKeyService.swift | ShortcutsSettingsContent.swift | 即时 | HotKeyService | NotificationCenter 通知 |
| `messagePanelModifiers` | AppSettings.swift | HotKeyService.swift | ShortcutsSettingsContent.swift | 即时 | HotKeyService | NotificationCenter 通知 |
| `liveCaptionKeyCode` | AppSettings.swift | HotKeyService.swift | ShortcutsSettingsContent.swift | 即时 | HotKeyService | NotificationCenter 通知 |
| `liveCaptionModifiers` | AppSettings.swift | HotKeyService.swift | ShortcutsSettingsContent.swift | 即时 | HotKeyService | NotificationCenter 通知 |
| `screenshotKeyCode` | AppSettings.swift | HotKeyService.swift | ShortcutsSettingsContent.swift | 即时 | HotKeyService | NotificationCenter 通知 |
| `screenshotModifiers` | AppSettings.swift | HotKeyService.swift | ShortcutsSettingsContent.swift | 即时 | HotKeyService | NotificationCenter 通知 |

**配置位置**: `spoke/Services/AppSettings.swift`
**详细文档**: [快捷键详细文档](./config-shortcuts.md)

---

### 4. Selection Toolbar

| setting_key | owner | read-path | write-path | 生效语义 | dependencies | side_effects |
|-------------|-------|-----------|------------|----------|--------------|--------------|
| `selectionToolbarEnabled` | AppSettings.swift:178 | AppSettings.swift:180-189 (didSet) | AppDelegate.swift:381 (菜单切换) | 即时 | SelectionMonitorService | 启动/停止选择监听服务 |
| `selectionToolbarAutoHideDelay` | AppSettings.swift:191 | N/A (当前未消费) | N/A (UI 未暴露/未接线) | 配置已定义 | 无 | 配置链路断裂（loadConfig 未实现） |
| `selectionToolbarShowText` | AppSettings.swift:194 | N/A (当前未消费) | N/A (UI 未暴露/未接线) | 配置已定义 | 无 | 配置链路断裂（loadConfig 未实现） |
| `selectionToolbarOCRContext` | AppSettings.swift:197 | N/A (当前未消费) | N/A (UI 未暴露/未接线) | 配置已定义 | 无 | 配置链路断裂（loadConfig 未实现） |

**配置位置**: `spoke/Services/AppSettings.swift`
**详细文档**: [Selection Toolbar 详细文档](./config-selection-toolbar.md)

---

### 5. Live Caption

| setting_key | owner | read-path | write-path | 生效语义 | dependencies | side_effects |
|-------------|-------|-----------|------------|----------|--------------|--------------|
| `liveCaptionTargetLanguage` | AppSettings.swift:292 | N/A (当前未消费) | N/A (UI 未暴露/未接线) | 配置已定义 | 无 | 配置链路断裂（LiveCaptionManager 使用独立配置） |
| `liveCaptionSourceLanguage` | AppSettings.swift:295 | N/A (当前未消费) | N/A (UI 未暴露/未接线) | 配置已定义 | 无 | 配置链路断裂（LiveCaptionManager 使用独立配置） |
| `liveCaptionShowOriginal` | AppSettings.swift:298 | N/A (当前未消费) | N/A (UI 未暴露/未接线) | 配置已定义 | 无 | 配置链路断裂（LiveCaptionManager 使用独立配置） |
| `liveCaptionTranslationEnabled` | AppSettings.swift:301 | N/A (当前未消费) | N/A (UI 未暴露/未接线) | 配置已定义 | 无 | 配置链路断裂（LiveCaptionManager 使用独立配置） |

**配置位置**: `spoke/Services/AppSettings.swift`
**详细文档**: [Live Caption 详细文档](./config-live-caption.md)

---

### 6. LLM 设置 (LLM Settings)

| setting_key | owner | read-path | write-path | 生效语义 | dependencies | side_effects |
|-------------|-------|-----------|------------|----------|--------------|--------------|
| `isEnabled` | LLMSettings.swift | RecordingController.swift | AISettingsContent.swift | 即时 | 无 | LLM 处理开关 |
| `profiles` | LLMSettings.swift | LLMProvider.swift | AISettingsContent.swift | 即时 | 无 | LLM 配置列表 |
| `selectedProfileId` | LLMSettings.swift | LLMProvider.swift | AISettingsContent.swift | 即时 | profiles | 当前使用的 Profile |
| `systemPrompt` | LLMSettings.swift | LLMProvider.swift | AISettingsContent.swift | 即时 | isEnabled | 系统提示词 |
| `includeClipboard` | LLMSettings.swift | LLMProvider.swift | AISettingsContent.swift | 即时 | isEnabled | 上下文收集 |
| `includeActiveApp` | LLMSettings.swift | LLMProvider.swift | AISettingsContent.swift | 即时 | isEnabled | 上下文收集 |
| `temperature` | LLMSettings.swift:137 | N/A (运行时用 profile.temperature) | N/A (UI 未暴露/未接线) | 配置已定义 | 无 | 全局键（运行时未接线） |
| `timeout` | LLMSettings.swift:142 | N/A (硬编码 30 秒) | N/A (UI 未暴露/未接线) | 配置已定义 | 无 | 全局键（运行时未接线） |
| `aiGeneratedTitleEnabled` | LLMSettings.swift:147 | LLMSettings.swift:693 | AISettingsCards.swift:83-84 | 即时 | isEnabled | 标题生成开关 |
| `summaryAutoEnabled` | LLMSettings.swift:169 | MessagePanelState.swift:728 | AISettingsCards.swift:95-98 | 即时 | isEnabled | 自动摘要开关 |
| `transcriptionProfileId` | LLMSettings.swift:154 | N/A (当前未消费) | AISettingsContent.swift:84 | 配置已定义 | profiles | 转录专用 Profile（配置链路断裂） |
| `chatProfileId` | LLMSettings.swift:159 | WorkflowExecutor.swift:86-87, LLMSettings.swift:693 | AISettingsContent.swift:87 | 即时 | profiles | Workflow fast + AI 标题 |
| `summaryProfileId` | LLMSettings.swift | SummaryService.swift | AISettingsContent.swift | 即时 | profiles | 摘要专用 Profile |

**配置位置**: `spoke/Core/LLM/LLMSettings.swift`
**详细文档**: [LLM 设置详细文档](./config-llm.md)

---

### 7. Quick Ask 专属 (Quick Ask Specific)

| setting_key | owner | read-path | write-path | 生效语义 | dependencies | side_effects |
|-------------|-------|-----------|------------|----------|--------------|--------------|
| `quickAskIncludeOCR` | LLMSettings.swift:176 | QuickAskService.swift:183 | AISettingsCards.swift | 即时 | ScreenOCRService 可用 | 上下文收集 + OCR 延迟 |
| `quickAskIncludeScreenshot` | LLMSettings.swift:181 | QuickAskService.swift:192 | AISettingsCards.swift | 即时 | ScreenOCRService 可用 + 屏幕录制权限 | 上下文收集 + 截图延迟 |
| `quickAskIncludeClipboard` | LLMSettings.swift:186 | QuickAskService.swift:423 (getHistoryForContext) | AISettingsCards.swift | 即时 | ClipboardHistoryService 自动启动 | 上下文收集 |
| `quickAskIncludeLiveCaption` | LLMSettings.swift:191 | QuickAskService.swift:433 (getOriginalTextHistory) | AISettingsCards.swift | 即时 | LiveCaptionManager 已启动 | 上下文收集 |
| `quickAskLiveCaptionLimit` | LLMSettings.swift:196 | QuickAskService.swift:433 | AISettingsCards.swift (Picker: 50/0) | 即时 | quickAskIncludeLiveCaption=true | 限制字幕数量 |

**配置位置**: `spoke/Core/LLM/LLMSettings.swift`
**详细文档**: [Quick Ask 配置详细文档](./config-quickask.md)

---

## 快速查找

### 按功能查找

- **录音功能**: [通用设置](./config-general.md) → recordingMode, realtimeTypingEnabled
- **Quick Ask**: [Quick Ask 配置](./config-quickask.md) → 所有 quickAsk* 配置项
- **文本选择**: [Selection Toolbar](./config-selection-toolbar.md) → 所有 selectionToolbar* 配置项
- **实时字幕**: [Live Caption](./config-live-caption.md) → 所有 liveCaption* 配置项
- **历史管理**: [历史清理](./config-history.md) → 所有 history* 配置项
- **LLM 处理**: [LLM 设置](./config-llm.md) → 所有 LLM 相关配置项

### 按影响范围查找

- **启动行为**: startAtLogin, showInDock, showInMenuBar, startupDiagnosticsEnabled
- **UI 显示**: showInDock, showInMenuBar, selectionToolbarShowText
- **性能相关**: realtimeTypingEnabled, historyAutoCleanupEnabled, startupDiagnosticsEnabled
- **上下文收集**: quickAskIncludeOCR, quickAskIncludeScreenshot, quickAskIncludeClipboard, quickAskIncludeLiveCaption

---

## 配置依赖关系图

```
录音功能
├── shortcutKeyCode/Modifiers (触发)
├── recordingMode (模式)
├── realtimeTypingEnabled (实时打字)
└── LLM isEnabled (润色)
    └── selectedProfileId (模型选择)

Quick Ask
├── quickAskKeyCode/Modifiers (触发)
├── quickAskIncludeOCR (OCR 上下文)
├── quickAskIncludeScreenshot (截图上下文)
├── quickAskIncludeClipboard (剪贴板上下文)
├── quickAskIncludeLiveCaption (字幕上下文)
│   └── quickAskLiveCaptionLimit (数量限制)
└── chatProfileId (LLM 模型)

Selection Toolbar
├── selectionToolbarEnabled (总开关)
├── selectionToolbarAutoHideDelay (自动隐藏)
├── selectionToolbarShowText (显示文本)
└── selectionToolbarOCRContext (OCR 上下文)

Live Caption
├── liveCaptionKeyCode/Modifiers (触发)
├── liveCaptionSourceLanguage (源语言)
├── liveCaptionTargetLanguage (目标语言)
├── liveCaptionTranslationEnabled (翻译开关)
└── liveCaptionShowOriginal (显示原文)

历史管理
├── historyAutoCleanupEnabled (自动清理)
├── historyKeepDays (保留天数)
└── historyMaxCount (最大数量)
```

---

## 配置变更通知机制

### NotificationCenter 通知

| 配置项 | 通知名称 | 监听者 |
|--------|----------|--------|
| shortcutKeyCode/Modifiers | `ShortcutDidChange` | HotKeyService |
| quickAskKeyCode/Modifiers | `QuickAskShortcutDidChange` | HotKeyService |
| messagePanelKeyCode/Modifiers | `MessagePanelShortcutDidChange` | HotKeyService |
| liveCaptionKeyCode/Modifiers | `LiveCaptionShortcutDidChange` | HotKeyService |
| screenshotKeyCode/Modifiers | `ScreenshotShortcutDidChange` | HotKeyService |

### didSet 直接响应

| 配置项 | 响应逻辑 | 位置 |
|--------|----------|------|
| startAtLogin | SMAppService.register/unregister | AppSettings.swift:58-66 |
| showInDock | NSApp.setActivationPolicy | AppSettings.swift:69-77 |
| selectionToolbarEnabled | SelectionToolbarManager.start/stop | AppSettings.swift:178-188 |

---

## 下一步

详细配置逻辑文档：
1. [通用设置详细文档](./config-general.md)
2. [历史清理详细文档](./config-history.md)
3. [快捷键详细文档](./config-shortcuts.md)
4. [Selection Toolbar 详细文档](./config-selection-toolbar.md)
5. [Live Caption 详细文档](./config-live-caption.md)
6. [LLM 设置详细文档](./config-llm.md)
7. [Quick Ask 详细文档](./config-quickask.md)
