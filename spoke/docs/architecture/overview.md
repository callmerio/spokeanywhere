# SpokenAnyWhere 项目架构全景

**版本**: 1.2
**更新时间**: 2026-03-22
**定位**: 架构首页与阅读导航

---

## 一、项目概览

SpokenAnyWhere 是一个原生 macOS 生产力应用（macOS 14+），以语音输入为核心，向外扩展 Quick Ask、实时字幕、截图标注、词典与文本选择工具栏等能力。

当前技术栈：

- Swift 5.9+
- SwiftUI + AppKit 混合 UI
- SwiftData 持久化
- Swift Package Manager
- Swift 6 strict concurrency 检查

---

## 二、架构分层

```text
App
  - SpokenlyApp.swift
  - AppDelegate.swift
  - 生命周期、启动编排、ModelContainer、菜单栏

Services
  - HotKeyService
  - RecordingController
  - QuickAskService
  - SelectionMonitorService
  - SelectionToolbarManager
  - HistoryManager
  - ServiceContainer
  - 全局协调、输入输出、设置与历史

Core
  - Audio / Transcription / LLM / Screenshot / LiveCaption
  - Dictionary / Attachment / Workflow / Translation
  - MessagePanel / History / Tags / SelectionToolbar / Debug
  - 业务逻辑、状态模型、平台能力封装

UI
  - HUD / QuickAsk / MessagePanel / LiveCaption / Screenshot
  - Dictionary / SelectionToolbar / Settings / Workflow / Components
  - 视图、浮窗、样式与交互承载
```

---

## 三、关键入口

### 3.1 应用入口

- `App/SpokenlyApp.swift`: SwiftUI `@main` 入口，仅暴露 Settings Scene
- `App/AppDelegate.swift`: 启动序列、状态栏、权限、历史清理、截图恢复、资源监控

### 3.2 核心编排入口

- `Services/RecordingController.swift`: 语音录制主编排器
- `Services/QuickAskService.swift`: Quick Ask 会话编排器
- `Services/ServiceContainer.swift`: 协议化依赖入口

### 3.3 持久化入口

`AppDelegate.sharedModelContainer` 初始化 SwiftData：

- `HistoryItem`
- `AppRule`
- `AIProviderConfig`

数据目录仍为：

- `~/Library/Application Support/Spoke/Data/`

---

## 四、主链路

### 4.1 语音输入

`HotKeyService -> VoiceHandler -> RecordingController -> AudioRecorderService -> TranscriptionManager`

### 4.2 Quick Ask

`HotKeyService -> QuickAskHandler -> QuickAskService -> LLMPipeline`

当前补充说明：

- `Core/QuickAsk/QuickAskPromptAssembler.swift` 已将 Quick Ask prompt 组装从 `QuickAskService` 热路径中抽离，成为可单测的纯拼装层。

### 4.3 截图

`HotKeyService -> ScreenshotHandler -> ScreenshotManager -> ScreenCaptureService`

### 4.4 实时字幕

`HotKeyService -> CaptionHandler -> LiveCaptionManager -> SystemAudioCaptureService -> LiveCaptionTranscriber`

### 4.5 文本选择工具栏

`SelectionMonitorService -> SelectionToolbarManager -> SelectionActionService`

---

## 五、当前架构特征

### 5.1 优点

- 分层边界基本清晰
- 主要功能域已按目录拆分
- 本地严格并发检查通过
- 测试基线已在 2026-03-22 更新到 `150 tests / 30 suites`

### 5.2 主要约束

- 仍以单例为主，初始化顺序较隐式
- UI 层存在大量 `*.shared` 直接依赖
- `NotificationCenter`、直接调用、`ServiceContainer` 三条依赖通道并存
- 文档需要持续校准，避免与代码现实脱节

本轮新增的结构收敛：

- `Services/RecordingTranscriptionDecision.swift` 已把录音转写后的 clipboard / HUD / processedText 决策从 `RecordingController` 中抽离。
- `App/AppLifecyclePlan.swift` 已把启动/关闭步骤顺序提炼为显式 plan spec，并由 `AppDelegate` 映射到实际 side effect。
- `Core/Workflow/WorkflowProfileResolver.swift` 已将 Workflow 的 profile fallback 选择从 `WorkflowExecutor` 中抽离，并新增表征测试。

### 5.3 当前判断

- 从可运行性看：**Go**
- 从可持续演进看：**Conditional Go**

详见：`./risks-and-recommendations.md`

---

## 六、文档导航

- `./current-state-audit.md`：当前状态审计与事实基线
- `./core-modules.md`：Core 层真实模块清单
- `./ui-components.md`：UI 场景与业务依赖
- `./quick-reference.md`：实现定位与验证命令
- `./risks-and-recommendations.md`：风险与建议
- `../m2-final-acceptance.md`：2026-02-22 历史验收记录

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-03-22
