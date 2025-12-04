# SpokenAnyWhere 开发路线图

> 愿景: Your Voice, Intelligently Refined.

更新: 2024-12-05

---

## 🎯 当前焦点: 实时字幕 + SpeechTranscriber

> Apple SpeechTranscriber 质量已经非常好，中英文转录效果出色

- [ ] **实时字幕**: 应用 SpeechTranscriber 模型
- [ ] SpeechTranscriber 下载体验优化 (首次加载检测 + 手动下载按钮)
- [ ] 单元测试覆盖 (TranscriptionModelManager/Provider)

---

## Phase 1: 基础体验 [√]

- [x] 设置界面 + 快捷键自定义
- [x] 边说边打字 (Real-time Typing via CGEvent)

## Phase 2: AI 集成 [√]

- [x] LLM Pipeline: 音频 → 转录 → LLM → 精炼
- [x] 多 Provider: Ollama/OpenAI/Anthropic/Gemini/Groq/OpenRouter
- [x] 上下文感知: 活跃应用检测 + 剪贴板历史
- [x] OCR 上下文: 屏幕内容识别注入 Prompt

## Phase 3: 本地智能 [√]

### 转录引擎 (macOS 26+)

- [x] `TranscriptionProvider` 协议抽象
- [x] `SpeechAnalyzerProvider` (DictationTranscriber/SpeechTranscriber)
- [x] `SFSpeechProvider` 回退方案 (macOS 15+)
- [x] 自动版本检测 + 引擎选择

### 多模型架构

- [x] `TranscriptionModelDefinition`: 模型元数据
- [x] `TranscriptionModelManager`: 选择/配置/持久化
- [x] 设置 UI: 模型卡片 + 语言选择 + 预编译词典开关
- [x] 模型切换通知 → Provider 自动重建

支持模型:
| 模型 | 状态 | 特点 |
|-----|------|-----|
| Apple Dictation | [√] 可用 | 内置，预编译 LM |
| Apple SpeechTranscriber | [√] 可用 | ~2GB，多语言强 |

### 词典注入

- [x] contextualStrings 轻量级注入 (实时生效)
- [x] 预编译 LM (后台准备，高精度)
- [x] 训练短语支持

## Phase 4: 记忆系统 [ ]

- [ ] 历史记录管理器 (SwiftData)
- [ ] 智能标签 (#Idea, #Todo)
- [ ] 旧音频重新处理

## Phase 5: Quick Ask [ ]

> 设计文档: [design-quick-ask.md](./design-quick-ask.md)

- [ ] 独立快捷键触发
- [ ] HUD: 波形 + 输入框
- [ ] 截图上下文
- [ ] AI 对话窗口

---

## Wishlist

### P1 近期

- [ ] 魔术键: Enter=原文 / Tab=AI 润色
- [ ] 悬浮指令盘: 润色/翻译/总结/转代码
- [ ] 语音宏: "切换到编程模式"

### P2 中期 (封存)

- [ ] Whisper API 集成 (Apple 模型已足够好)
- [ ] Whisper.cpp Local (CoreML)
- [ ] 自定义指令库: 用户 Prompt 模板

### P3 低优先级

- [ ] TTS: 选中/剪贴板/截图 → 语音
- [ ] 多模态音频: 原始音频 + 转录同时发送 (token 消耗大，功能重复)
