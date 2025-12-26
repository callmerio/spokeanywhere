# SpokenAnyWhere 开发路线图

> 愿景: Your Voice, Intelligently Refined.

更新: 2025-12-26

---

## 🔥 当前焦点: 合规 + 统一查词

- [ ] App Sandbox 启用 + entitlements + 沙盒路径验证
- [ ] 权限引导 Onboarding（麦克风/屏幕录制/辅助功能）
- [ ] UnifiedDictionaryService：本地词典 + 在线 API 聚合输出
- [ ] 模拟输入降级策略：默认剪贴板输出，允许授权后启用

## 🎯 当前焦点: 选择工具栏 + 实时字幕

> 全局文本选择浮动工具栏 (类似 PopClip)

- [√] **选择工具栏**: AXObserver + NSPanel 全局监听 ✅
- [√] **多策略文本获取**: SelectedText → Parameterized → Value+Range ✅
- [√] **Electron 兼容**: Windsurf/VSCode 已支持 ✅
- [~] **Terminal 支持**: 待研究 (Accessibility API 限制)

> 实时字幕基本可用（多语言仍需完善）

- [~] **实时字幕**: 应用 SpeechTranscriber 模型（多语言待完善）
- [√] **实时翻译**: Apple Translation API 集成，无卡顿 ✅
- [√] **生词记忆**: 右键添加 + 橙色高亮 ✅

---

## Phase 1: 基础体验 [√]

- [√] 设置界面 + 快捷键自定义
- [√] 边说边打字 (Real-time Typing via CGEvent)

## Phase 2: AI 集成 [√]

- [√] LLM Pipeline: 音频 → 转录 → LLM → 精炼
- [√] 多 Provider: Ollama/OpenAI/Anthropic/Gemini/Groq/OpenRouter
- [√] 上下文感知: 活跃应用检测 + 剪贴板历史
- [√] OCR 上下文: 屏幕内容识别注入 Prompt
- [√] Gemini 思考模式: thinkingBudget 控制 ✨
- [√] Gemini 联网搜索: Google Search grounding ✨
- [√] CLI2API 代理: v1beta + Bearer token 支持

## Phase 3: 本地智能 [√]

### 转录引擎 (macOS 26+)

- [√] `TranscriptionProvider` 协议抽象
- [√] `SpeechAnalyzerProvider` (DictationTranscriber/SpeechTranscriber)
- [√] `SFSpeechProvider` 回退方案 (macOS 15+)
- [√] 自动版本检测 + 引擎选择

### 多模型架构

- [√] `TranscriptionModelDefinition`: 模型元数据
- [√] `TranscriptionModelManager`: 选择/配置/持久化
- [√] 设置 UI: 模型卡片 + 语言选择 + 预编译词典开关
- [√] 模型切换通知 → Provider 自动重建

支持模型:
| 模型 | 状态 | 特点 |
|-----|------|-----|
| Apple Dictation | [√] 可用 | 内置，预编译 LM |
| Apple SpeechTranscriber | [√] 可用 | ~2GB，多语言强 |

### 词典注入

- [√] contextualStrings 轻量级注入 (实时生效)
- [√] 预编译 LM (后台准备，高精度)
- [√] 训练短语支持

## Phase 4: 记忆系统 [~]

- [√] 历史记录管理器 (SwiftData) - 基础版
- [ ] 智能标签 (#Idea, #Todo)
- [ ] 旧音频重新处理

## Phase 5: Quick Ask [√]

> 设计文档: [design-quick-ask.md](./design-quick-ask.md)

- [√] 独立快捷键触发（双击 ⌥）
- [√] HUD: 波形 + 输入框
- [√] 截图上下文
- [√] AI 对话窗口

---

## Wishlist

### P1 近期

- [ ] 魔术键: Enter=原文 / Tab=AI 润色
- [√] 选择工具栏: 朗读/查询/翻译/总结 ✅
- [ ] 语音宏: "切换到编程模式"

### P2 中期 (封存)

- [ ] Whisper API 集成 (Apple 模型已足够好)
- [ ] Whisper.cpp Local (CoreML)
- [ ] 自定义指令库: 用户 Prompt 模板

### P3 低优先级

- [√] TTS 朗读: 选中文本 → 语音 ✅ (集成到选择工具栏)
- [ ] 多模态音频: 原始音频 + 转录同时发送 (token 消耗大，功能重复)
