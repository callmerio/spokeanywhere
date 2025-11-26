# SpokenAnyWhere 开发路线图 (Roadmap)

> **愿景**: 你的声音，智能精炼。(Your Voice, Intelligently Refined.)

## Phase 1: 基础打磨与体验优化 (进行中)
**目标**: 打造坚如磐石的输入体验与稳定性。

- [ ] **触觉与声音反馈 (Haptic & Sound Feedback)**
    - 开始/停止录音时增加系统提示音效
    - 在支持的触控板上增加触觉反馈
- [ ] **音频可视化 (Audio Visualization)**
    - 升级音频波形动画：从简单的音量缩放改为灵动的 Siri 风格波形
- [ ] **设置界面 (Settings UI)**
    - 完善设置窗口功能实现
    - 支持快捷键自定义
    - 语言选择 (中/英/混合)
    - UI 缩放与透明度调节

## Phase 2: 注入灵魂 - AI 集成 (优先级: 高)
**目标**: 从单纯的“听写”进化为“创作”。

- [ ] **LLM 处理管线 (LLM Pipeline)**
    - 后处理流程：音频 -> 文本 -> LLM -> 精炼文本
    - 在 HUD 上增加可视化的“思考中”状态
- [ ] **上下文感知 (Context Awareness)**
    - 检测当前活跃应用 (例如：VS Code vs 微信)
    - 基于上下文动态注入 Prompt (例如在代码编辑器中偏向代码生成)
    - 集成 `ContextService`
- [ ] **自定义指令 (Custom Instructions)**
    - 用户自定义 Prompt 库 (例如："翻译成英文", "委婉的邮件回复")
    - 快捷键或语音命令触发特定指令

## Phase 3: 本地智能 - 隐私与离线 (The Ear)
**目标**: 隐私安全、离线可用、超低延迟。

- [ ] **本地 Whisper 集成**
    - 集成 `WhisperKit` (针对 Apple Silicon 优化的 CoreML 版本)
    - 支持高精度的离线听写
    - 模型下载与管理界面

## Phase 4: 第二大脑 - 记忆与知识库 (The Memory)
**目标**: 可追溯性与知识沉淀。

- [ ] **历史记录管理器 (History Manager)**
    - 语音笔记的“时光机”
    - 可搜索的历史数据库 (基于 SwiftData)
    - 支持使用新 Prompt 对旧音频进行重新处理
- [ ] **标签与整理 (Tags & Organization)**
    - 智能自动打标签 (#Idea, #Todo)
    - 智能文件夹分类

---

## 功能愿望清单 (Feature Wishlist)

### 魔术键 (Magic Key)
- **交互**: 录音结束后，按 `Enter` 直接上屏原文，按 `Tab` 或 `Cmd+Enter` 触发 AI 润色。
- **价值**: 让用户自主选择“速度”还是“质量”。

### 悬浮指令盘 (Floating Palette)
- **交互**: 录音结束后，HUD 变为工具条。
- **操作**: "润色", "翻译", "总结", "转为代码"。

### 语音宏 (Voice Macros)
- **交互**: 说 *"切换到编程模式"* -> 自动激活编程相关的 Prompt。
- **价值**: 极速切换工作流上下文。
