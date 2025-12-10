# 📋 SpokenAnyWhere Changelog

macOS 语音助手应用变更日志，记录每次发布的新功能、改进和修复。

---

## 2025-12-10 - 划词工具栏完善

### ✨ New

- **语音引擎预热** - App 启动后台预热 SpeechTranscriber，消除首次使用 ~2s 卡顿
- **工具栏设置跳转** - 菜单项"自定义设置"直接打开设置页工具栏 Tab

### 🎨 Improvements

- 工具栏 UI 毛玻璃重构 (`.ultraThinMaterial`)
- Button+NSMenu 替代 SwiftUI Menu 解决 onHover 不可靠问题
- AI 动作模型选择改为实际 LLM Profile（而非抽象类型）
- 图标网格选择器 `IconPickerPopover`

### 🐛 Fixes

- 修复 `visibleCount.didSet` 无限递归导致栈溢出闪退

---

## 2025-12-09 - Pipeline 性能优化 + 划词工具栏

### ✨ New

- **划词工具栏可配置化** - 自定义技能 + 拖拽排序 + {{selection}} 占位符
- **SelectionToolbar 复用 AnswerPanel** - 查询/翻译/总结复用 Quick Answer 界面
- **Pipeline 智能总结** - 切换 Todo/Note 自动生成摘要 + 右键手动总结

### 🎨 Improvements

- Pipeline 分页懒加载 (displayLimit=20 + onAppear loadMore)
- IdentifiedArray 优化 ForEach 性能 (O(1) id 访问)
- MessageCard 从 struct 改为 class+ObservableObject 避免拷贝
- Todo 模式四段排序：匹配标签 todo → done → 不匹配 todo → done

### 🐛 Fixes

- 修复 TagListView 观察全局 state 导致 FlowLayout 卡死
- 修复快速连续触发 Option+R 导致新录音被旧延迟停止打断

---

## 2025-12-08 - Pipeline 标签系统 + 划词工具栏

### ✨ New

- **系统级划词工具栏** - 选中文本自动出现悬浮工具栏 (类似 PopClip)
- **Pipeline 标签系统** - 9 色调色板 + 气泡样式 + 筛选排序
- **卡片附件系统** - 截图拖拽/粘贴 + 流式布局缩略图
- **来源应用图标** - 卡片左上角显示来源 App 图标 + hover 提示

### 🎨 Improvements

- 点击卡片复制反馈优化 (scaleEffect + 触觉反馈 + 浮动提示)
- Todo/Done/Note 状态管理 + 过滤按钮

### 🐛 Fixes

- 修复长文本转录被截断 (maxTokens 2048→8192)

---

## 2025-12-07 - 实时字幕稳定性

### 🐛 Fixes

- 翻译偶发失败添加重试机制 (最多 3 次 + 递增间隔)
- 添加/移除生词后自动滚动停止问题修复
- 长时间运行后最后一行被截断 (累积误差修复)

---

## 2025-12-06 - 实时字幕翻译 + 生词记忆

### ✨ New

- **生词记忆功能** - 选中文字右键添加生词 → 全量橙色高亮
- **Apple Translation 集成** - macOS 15+ 原生翻译 API

### 🎨 Improvements

- 双层缓冲区模型彻底解决跳动问题 (frozenLines + volatileTail)
- AppKitScrollView 桥接 NSScrollView 精确检测滚动位置
- 历史扩容 maxItems 10→200

### 🐛 Fixes

- 修复三行闪烁跳变问题 (lineLimit + truncationMode)
- 修复翻译导致系统卡顿 (暂时禁用高频触发)

---

## 2025-12-05 - 实时字幕重构

### ✨ New

- **实时字幕功能** - 监控系统音频实时转录 + 翻译成中文
- **SpeechAnalyzerProvider** - 复用 TranscriptionProvider 统一架构
- **转录模型角色分配** - 主转录/实时字幕可配置不同模型

### 🎨 Improvements

- 简洁卡片式 UI 设计 (毛玻璃背景 + 圆角 20pt)
- O+R 风格快速上屏 + 可反改机制
- 独立语言设置 (captionLocale)

### 🐛 Fixes

- 修复音频文件泄漏 5GB (孤儿文件清理 + 大小限制)
- 修复取消录音后再次录音立即被终止

---

## 2025-12-04 - 多转录模型架构

### ✨ New

- **多模型架构** - SpeechTranscriber / DictationTranscriber / SFSpeech 可切换
- **词典双轨注入** - contextualStrings (轻量级) + 预编译 LM (重量级)
- **训练短语收集** - 右键纠正时自动收集整句话作为训练数据
- **Pipeline 纠错可视化** - 删除线原词 + 橙色正确词

### 🎨 Improvements

- 模型选择 UI 卡片式设计 + 角色标签 (转录/字幕)
- 词典权重调节 (light/standard/enhanced)

### 🐛 Fixes

- 修复 TCC 权限每次被 kill 重建 (统一 BundleID + 开发者证书签名)
- 修复 OCR 阻塞主线程导致快捷键失效

---

## 2025-12-03 - 词典功能 + Pipeline 优化

### ✨ New

- **词典功能** - 用户自定义词典提高转录准确性 + 右键添加
- **Pipeline 卡片持久化** - 24 小时内记录自动保存/恢复
- **触控板手势** - 从左边缘往右滑打开 Panel

### 🎨 Improvements

- MessagePanel 深色简洁卡片风格
- 点击卡片即复制内容 + 视觉反馈
- HoverButtons 可复用组件

---

## 2025-12-01 - Quick Ask 输入法修复

### 🐛 Fixes

- 修复 Quick Ask 中文输入法 IME 崩溃 + 无法组词问题
- 修复 AnswerPanel 输入不可点击 + 闪烁消失问题

### ✨ New

- **连续对话** - AnswerPanel 支持多轮对话和追问

---

## 2025-11-30 - Message Panel + Quick Ask

### ✨ New

- **Message Panel** - 类似 macOS 通知中心从左侧滑出的 Pipeline 可视化面板
- **Quick Ask** - 双击 ⌥ 唤起 Spotlight 风格输入框
- 多模态附件支持 (图片/PDF/截图拖拽)
- 流式 LLM 响应 + Markdown 渲染

---

## 2025-11-27 - 核心功能

### ✨ New

- **剪贴板历史** - 作为 LLM 上下文
- **HUD 状态指示** - 彩色点旋转动画 (Apple Intelligence 风格)
- Gemini 多模态支持

### 🐛 Fixes

- 修复 CGEvent tap 超时被系统禁用
- 修复流光效果被毛玻璃层遮挡

---

_最后更新: 2025-12-10_
