# SpokenAnyWhere 核心模块详解

**版本**: 1.0  
**更新时间**: 2026-02-22

---

## 一、模块总览

Core 层按功能域拆分，负责业务逻辑与平台能力封装。

| 模块 | 目录 | 关键职责 | 入口实现 |
|------|------|----------|----------|
| Audio | `Core/Audio/` | 音频采集、回调路由、恢复策略 | `AudioRecorderService.swift` |
| Transcription | `Core/Transcription/` | ASR 引擎适配、转录管理 | `TranscriptionManager.swift` |
| LLM | `Core/LLM/` | LLM Provider 抽象与请求管道 | `LLMPipeline.swift` |
| LiveCaption | `Core/LiveCaption/` | 系统/应用音频字幕流处理 | `LiveCaptionManager.swift` |
| Screenshot | `Core/Screenshot/` | 截图捕获、标注与状态管理 | `ScreenshotManager.swift` |
| Dictionary | `Core/Dictionary/` | 本地/远程词典聚合与注入 | `UnifiedDictionaryService.swift` |
| Attachment | `Core/Attachment/` | 附件抽取、屏幕捕获 | `AttachmentManager.swift` |

---

## 二、关键调用关系

1. 语音输入链路：`RecordingController` -> `AudioRecorderService` -> `TranscriptionManager`
2. Quick Ask 链路：`QuickAskService` -> `LLMPipeline` -> `OpenAICompatibleProvider`
3. 实时字幕链路：`LiveCaptionManager` -> `SystemAudioCaptureService` -> `LiveCaptionTranscriber`
4. 截图链路：`ScreenshotManager` -> `ScreenCaptureService` -> `ImageEnhancementService`

---

## 三、配套文档

- 架构全景：`./overview.md`
- 功能定位索引：`./quick-reference.md`
- 风险与收敛建议：`./risks-and-recommendations.md`

