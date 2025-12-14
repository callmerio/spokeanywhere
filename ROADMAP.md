# 🗺️ SpokenAnyWhere Roadmap

macOS 语音助手应用开发路线图，按功能模块划分。

---

## ✅ 已完成功能

### 🎙️ 语音转录

- [x] 多转录模型架构 (SpeechTranscriber / DictationTranscriber / SFSpeech)
- [x] 词典注入系统 (contextualStrings + 预编译 LM 双轨)
- [x] 热词学习 + 训练短语自动收集
- [x] 纠错可视化 (删除线原词 + 橙色正确词)
- [x] 模型角色分配 (主转录 / 实时字幕)

### 🎬 实时字幕

- [x] 系统音频捕获 (ScreenCaptureKit)
- [x] Apple Translation 翻译集成 (macOS 15+)
- [x] 双层缓冲区稳定输出 (frozenLines + volatileTail)
- [x] 生词记忆 + 橙色高亮
- [x] 简洁卡片式 UI (毛玻璃 + 圆角)

### 💬 Quick Ask

- [x] 双击 ⌥ 快捷键唤起
- [x] 流式 LLM 响应 + Markdown 渲染
- [x] 多模态附件 (图片/PDF/截图)
- [x] 连续对话支持

### 📋 Pipeline 面板

- [x] 卡片持久化存储 (24h)
- [x] Todo/Done/Note 状态管理
- [x] 标签系统 (9 色 + 筛选排序)
- [x] 附件系统 (截图拖拽/粘贴)
- [x] 智能总结功能
- [x] 来源应用图标
- [x] 分页懒加载 + 性能优化

### ✂️ 划词工具栏

- [x] 系统级文本选择监听 (AXObserver)
- [x] 可配置化 + 自定义技能
- [x] AI 动作提示词/模型配置
- [x] 毛玻璃 UI + 设置跳转

### 🤖 LLM 集成

- [x] 多 Provider (Gemini / OpenAI Compatible)
- [x] 剪贴板历史作为上下文
- [x] 联网搜索增强

---

## 🔄 进行中

### 🎨 设计系统重构

- [x] 创建 `DesignTokens.swift` 统一设计入口 (2024-12-14)
- [x] 迁移 `HUDTheme` 到 DesignTokens (向后兼容)
- [x] 生成 `docs/style/` 设计体系文档
- [x] 迁移 Settings 模块硬编码 (SettingsView, DictionarySettingsView)
- [x] 迁移 HUD 模块硬编码 (FloatingCapsuleView)
- [ ] 迁移其他模块硬编码 (MessagePanel, LiveCaption 等)

### 实时字幕优化

- [ ] 翻译行截断问题深度修复
- [ ] 高频翻译触发优化 (防抖/批量)

---

## � 待开发

### 🎙️ 转录增强

- [ ] **中英文混合识别优化** - zh-CN locale 英文识别率低
- [ ] **Whisper 本地模型集成** - CoreML 模型下载管理器
- [ ] **Whisper API 支持** - API Key 配置 (Keychain 存储)

### 📖 词典查词

- [ ] **划词查词典** - 选中单词显示释义
- [ ] **生词本** - 收藏生词 + 复习功能
- [ ] **词形还原** - ran → run 自动关联

### ✨ 智能功能

- [ ] **已改写不重复改写** - 防止重复润色
- [ ] **上下文感知** - 根据前文智能补全
- [ ] **多模态音频输入** - 音频文件直接转录

### 🎨 UI/UX

- [ ] **菜单栏图标** - 状态指示 + 快捷操作
- [ ] **自定义快捷键** - 用户可配置热键
- [ ] **深色/浅色主题** - 跟随系统

### ⚡ 性能

- [ ] **启动速度优化** - 延迟加载非核心模块
- [ ] **内存占用优化** - 长时间运行监控

---

## 🔮 远期愿景

### 2025 H1

- 词典查词 + 生词本
- Whisper 本地模型
- 中英混合识别优化

### 2025 H2

- 多语言支持 (日语/韩语)
- iOS/iPadOS 版本
- iCloud 同步

### 2026+

- 企业版团队协作
- 开放 API
- 插件系统

---

_最后更新: 2025-12-10_\_
