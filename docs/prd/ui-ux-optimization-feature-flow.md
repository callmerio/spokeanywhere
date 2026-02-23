# PRD: UI/UX 优化与功能流视图

> 版本: v1.0
> 创建时间: 2026-02-23
> 状态: Draft
> 优先级: P1

---

## 执行摘要

本 PRD 定义 SpokenAnyWhere 的 UI/UX 优化工作，重点包括：
1. **功能流视图文档**（树形结构）- 映射所有已实现功能及其操作流程
2. **QuickAsk/QuickAnswer 面板优化** - 统一交互体验
3. **设置界面统一** - 整体风格一致性
4. **配置逻辑与响应流程文档** - 为 Agent 提供完整上下文

**核心目标**: 在进行 UI/UX 优化前，先建立完整的功能流视图，确保每个 Agent 都能快速理解整个应用的功能结构和配置流程。

---

## 背景与动机

### 当前问题
1. **上下文碎片化**: Agent 上下文有限，无法完整理解整个应用的功能流程
2. **功能文档缺失**: 缺少树形结构的功能映射，难以快速定位特定功能的实现位置
3. **UI 风格不统一**: QuickAsk/QuickAnswer 面板、设置界面风格存在不一致
4. **配置逻辑不清晰**: 配置项的响应流程和依赖关系未文档化

### 解决方案
1. **建立功能流视图**: 树形结构文档，映射所有功能的入口、流程、配置
2. **UI/UX 优化**: 基于功能流视图，进行针对性的界面优化
3. **配置流程文档**: 记录每个配置项的响应逻辑和影响范围

---

## 第一阶段：功能流视图（Feature Flow Map）

### 目标
创建树形结构的功能流视图文档，作为所有 UI/UX 优化工作的基础。

### 功能树结构

```
SpokenAnyWhere
├── 1. 语音转文字 (Voice-to-Text)
│   ├── 1.1 录音触发
│   │   ├── 入口: ⌥R (可配置)
│   │   ├── 模式: Toggle/Hold/Mixed
│   │   ├── 实现: HotKeyService.swift:637-818
│   │   └── 配置: ShortcutsSettingsContent.swift
│   ├── 1.2 实时转录
│   │   ├── 引擎: Apple STT / Whisper
│   │   ├── 实现: TranscriptionProvider.swift
│   │   └── 配置: TranscriptionModelSettingsView.swift
│   ├── 1.3 LLM 润色
│   │   ├── 提供商: Gemini / OpenAI / Claude
│   │   ├── 实现: LLMProvider.swift
│   │   └── 配置: AISettingsContent.swift
│   └── 1.4 输出
│       ├── 实时打字: InputService.swift
│       ├── 剪贴板: ClipboardHistoryService.swift
│       └── 消息面板: MessagePanelManager.swift
│
├── 2. Quick Ask (⌥T)
│   ├── 2.1 触发与输入
│   │   ├── 入口: ⌥T (可配置)
│   │   ├── HUD 显示: FloatingCapsuleView.swift
│   │   ├── 语音输入: AudioRecorderService.swift
│   │   ├── 文本输入: 手动输入框
│   │   └── 图片输入: Cmd+V 粘贴
│   ├── 2.2 上下文收集
│   │   ├── OCR: ScreenOCRService (活动窗口文本，最多 2000 字符)
│   │   ├── Screenshot: ScreenOCRService.captureActiveWindow()
│   │   ├── Clipboard: ClipboardHistoryService (最近 5 项)
│   │   └── Live Caption: LiveCaptionManager (可配置数量)
│   ├── 2.3 LLM 处理
│   │   ├── 组合提示词: QuickAskService.swift:179-202
│   │   ├── 发送到 LLM: LLMPipeline
│   │   └── 流式响应: AnswerPanelView.swift
│   ├── 2.4 Answer Panel
│   │   ├── 消息历史: 对话记录
│   │   ├── Follow-up: 追问功能
│   │   ├── Suggested Questions: 建议问题
│   │   ├── Auto-read: TTSSettings
│   │   └── 快捷键: Cmd+W (关闭), Cmd+, (设置)
│   └── 2.5 配置选项
│       ├── quickAskIncludeOCR: 是否包含 OCR
│       ├── quickAskIncludeScreenshot: 是否包含截图
│       ├── quickAskIncludeClipboard: 是否包含剪贴板
│       ├── quickAskIncludeLiveCaption: 是否包含实时字幕
│       └── quickAskLiveCaptionLimit: 字幕历史数量
│
├── 3. 截图与标注 (⌥A)
│   ├── 3.1 区域选择
│   │   ├── 入口: ⌥A (可配置)
│   │   ├── 全屏覆盖: RegionSelectionView.swift
│   │   └── 拖拽选择: 鼠标拖拽
│   ├── 3.2 截图窗口
│   │   ├── 浮动窗口: ScreenshotWindow.swift (NSPanel)
│   │   ├── Live Text: macOS 13+ 支持
│   │   └── Pin to Space: 固定到当前空间
│   ├── 3.3 标注工具
│   │   ├── 绘图: AnnotationCanvasView.swift
│   │   ├── 文本: 文本标注
│   │   ├── 形状: 矩形、圆形、箭头
│   │   └── Undo/Redo: 撤销/重做
│   ├── 3.4 快捷键操作
│   │   ├── P: Pin to space
│   │   ├── M: Mark/annotate
│   │   ├── A: Quick Ask with screenshot
│   │   ├── C: Copy image
│   │   ├── T: Copy recognized text (OCR/Live Text)
│   │   └── Q: Close window
│   ├── 3.5 图像增强
│   │   ├── 路径: none/basic/ai-fallback
│   │   ├── 实现: ImageEnhancementService.swift
│   │   └── 配置: ScreenshotSettingsView.swift
│   └── 3.6 配置选项
│       ├── 捕获质量: Capture quality
│       ├── 自动保存: Auto-save
│       └── 标注默认: Annotation defaults
│
├── 4. 文本选择工具栏
│   ├── 4.1 选择检测
│   │   ├── AXObserver: SelectionMonitorService.swift:273-310
│   │   ├── 鼠标事件: 拖拽、双击
│   │   └── 键盘事件: Shift+Arrow, Cmd+A
│   ├── 4.2 工具栏显示
│   │   ├── 位置: 选中文本下方
│   │   ├── 自动隐藏: 5 秒（可配置）
│   │   └── 显示保护: 300ms 防止立即隐藏
│   ├── 4.3 工具栏操作
│   │   ├── Logo 菜单: 主要操作
│   │   ├── 分隔线: Divider
│   │   ├── 操作按钮: ToolbarConfigService
│   │   └── 词典结果: DictionaryResultManager
│   └── 4.4 配置选项
│       ├── selectionToolbarEnabled: 启用/禁用
│       ├── selectionToolbarAutoHideDelay: 自动隐藏延迟
│       ├── selectionToolbarShowText: 显示文本
│       └── selectionToolbarOCRContext: OCR 上下文
│
├── 5. 实时字幕 (⌥S)
│   ├── 5.1 触发与显示
│   │   ├── 入口: ⌥S (可配置)
│   │   ├── 窗口位置: 屏幕顶部居中
│   │   ├── 尺寸: 672×400px
│   │   └── 可拖拽: 支持
│   ├── 5.2 字幕显示
│   │   ├── 实时转录: 音频实时转文字
│   │   ├── 滚动历史: 可滚动查看
│   │   ├── 词汇高亮: VocabularyHighlightText.swift
│   │   └── 可折叠: 折叠/展开状态
│   └── 5.3 配置选项
│       ├── 启动时自动开启: Auto-start
│       ├── 字幕语言: Language selection
│       ├── 字体大小: Font size
│       └── 透明度: Transparency
│
├── 6. 消息面板 (⌥P)
│   ├── 6.1 触发与显示
│   │   ├── 入口: ⌥P (可配置)
│   │   └── 实现: MessagePanelManager.swift
│   ├── 6.2 内容类型
│   │   ├── 欢迎消息: Welcome messages
│   │   ├── ASR 结果: 转录结果（模型、文本、时长、来源）
│   │   ├── LLM 结果: LLM 响应（模型、文本、时长、来源）
│   │   ├── 剪贴板: 剪贴板历史
│   │   └── 系统消息: System messages
│   └── 6.3 功能
│       ├── 会话历史: Session history
│       ├── 过滤器: Filter chips
│       ├── 来源图标: Source app icons
│       ├── 可选文本: Selectable text
│       └── 快捷键: Cmd+V (粘贴图片)
│
├── 7. 词典 (⌥Space)
│   ├── 7.1 触发与查询
│   │   ├── 入口: ⌥Space (可配置)
│   │   ├── 实现: UnifiedDictionaryService.swift
│   │   └── 提供商: 多个词典源
│   ├── 7.2 词典管理
│   │   ├── 添加/编辑: EditDictionaryEntrySheet.swift
│   │   ├── 批量导入: Batch import
│   │   └── 词汇列表: Vocabulary list
│   └── 7.3 配置选项
│       └── DictionarySettingsView.swift
│
├── 8. 剪贴板管道 (⌥V)
│   ├── 8.1 触发
│   │   ├── 入口: ⌥V (可配置)
│   │   └── 实现: HotKeyService.swift:620-625
│   └── 8.2 处理流程
│       ├── 获取剪贴板: ClipboardHistoryService
│       └── 处理: LLM 处理或其他操作
│
├── 9. 设置界面 (⌘,)
│   ├── 9.1 General
│   │   ├── 登录时启动: Start at login
│   │   ├── 显示在 Dock: Show in dock
│   │   ├── 显示在菜单栏: Show in menu bar
│   │   └── 音效: Sound effects
│   ├── 9.2 Screenshot
│   │   ├── 捕获质量: Capture quality
│   │   ├── 自动保存: Auto-save
│   │   └── 标注默认: Annotation defaults
│   ├── 9.3 Selection Toolbar
│   │   ├── 启用/禁用: Enable/disable
│   │   ├── 自动隐藏延迟: Auto-hide delay
│   │   ├── 按钮文本: Button text
│   │   └── OCR 上下文: OCR context
│   ├── 9.4 Transcription Model
│   │   ├── 模型选择: Model selection
│   │   ├── 语言: Language
│   │   └── 置信度阈值: Confidence threshold
│   ├── 9.5 AI Processing
│   │   ├── LLM 提供商: LLM provider
│   │   ├── API Keys: API keys
│   │   ├── Temperature: Temperature
│   │   └── Max Tokens: Max tokens
│   ├── 9.6 Dictionary
│   │   ├── 添加/编辑: Add/edit entries
│   │   ├── 批量导入: Batch import
│   │   └── 词汇列表: Vocabulary list
│   ├── 9.7 TTS
│   │   ├── 语音选择: Voice selection
│   │   ├── 速度: Speed
│   │   ├── 音量: Volume
│   │   └── 自动朗读: Auto-read aloud
│   ├── 9.8 Shortcuts
│   │   ├── 录音触发: Recording trigger (⌥R)
│   │   ├── Quick Ask: Quick Ask (⌥T)
│   │   ├── 截图: Screenshot (⌥A)
│   │   ├── 录音模式: Recording mode (toggle/hold/mixed)
│   │   └── 实时打字: Real-time typing toggle
│   └── 9.9 History
│       ├── 自动清理: Auto-cleanup
│       ├── 保留天数: Keep days
│       ├── 最大数量: Max count
│       └── 清除历史: Clear history
│
└── 10. 菜单栏
    ├── 10.1 菜单项
    │   ├── 应用标题: App title
    │   ├── 当前热键: Current hotkey display (动态)
    │   ├── Live Caption: Live Caption toggle (⌥S)
    │   ├── Selection Toolbar: Selection Toolbar toggle
    │   ├── Screenshot: Screenshot (⌥A)
    │   ├── Dictionary: Dictionary (⌥Space)
    │   ├── Settings: Settings (⌘,)
    │   └── Quit: Quit (⌘Q)
    └── 10.2 初始化序列
        ├── Crash logger: 崩溃日志
        ├── Accessibility: 辅助功能权限
        ├── Menu bar: 菜单栏设置
        ├── Clipboard: 剪贴板服务
        ├── Recording: 录音控制器
        ├── History: 历史管理器
        ├── Dictionary: 词典预编译
        ├── Speech: 语音引擎预热
        ├── Trackpad: 触控板手势
        ├── Resource: 资源监控
        ├── Selection: 选择工具栏
        ├── Screenshot: 截图服务
        └── Dictionary Panel: 词典面板
```

### 功能状态标记

#### ✅ 已实现功能
- 语音转文字（Toggle/Hold/Mixed 模式）
- Quick Ask（语音+文本+图片输入，上下文收集）
- 截图与标注（区域选择、标注工具、快捷键操作）
- 文本选择工具栏（自动检测、工具栏显示）
- 实时字幕（实时转录、词汇高亮）
- 消息面板（多种内容类型、过滤器）
- 词典（查询、管理、批量导入）
- 剪贴板管道
- 设置界面（9 个标签页）
- 菜单栏（完整菜单项、初始化序列）

#### 🚧 待优化功能
- QuickAsk/QuickAnswer 面板 UI 统一
- 设置界面风格统一
- 配置逻辑文档化

#### 📋 计划功能
- （待用户补充）

---

## 第二阶段：UI/UX 优化

### 2.1 QuickAsk/QuickAnswer 面板优化

#### 当前问题
- HUD 显示与 Answer Panel 风格不一致
- 输入框、按钮、布局需要统一
- 交互流程可以更流畅

#### 优化目标
1. **统一视觉风格**: 使用 DesignTokens 统一颜色、圆角、间距
2. **优化布局**: 改进 HUD 和 Answer Panel 的布局结构
3. **增强交互**: 优化输入、录音、显示的交互体验

#### 实现文件
- `spoke/UI/HUD/FloatingCapsuleView.swift`
- `spoke/UI/QuickAsk/AnswerPanelView.swift`
- `spoke/Services/QuickAskService.swift`

### 2.2 设置界面统一

#### 当前问题
- 9 个设置标签页风格存在差异
- 部分设置项布局不一致
- 缺少统一的设计语言

#### 优化目标
1. **统一布局**: 所有设置标签页使用一致的布局模式
2. **统一组件**: 使用统一的输入框、开关、选择器组件
3. **统一间距**: 使用 DesignTokens 定义的间距规范

#### 实现文件
- `spoke/UI/Settings/SettingsView.swift`
- `spoke/UI/Settings/GeneralSettingsContent.swift`
- `spoke/UI/Settings/ScreenshotSettingsView.swift`
- `spoke/UI/Settings/ToolbarSettingsView.swift`
- `spoke/UI/Settings/TranscriptionModelSettingsView.swift`
- `spoke/UI/Settings/AISettingsContent.swift`
- `spoke/UI/Settings/Dictionary/DictionarySettingsView.swift`
- `spoke/UI/Settings/TTSSettingsContent.swift`
- `spoke/UI/Settings/ShortcutsSettingsContent.swift`
- `spoke/UI/Settings/HistorySettingsContent.swift`

### 2.3 配置逻辑与响应流程文档

#### 目标
为每个配置项创建文档，说明：
1. **配置项名称**: 在 AppSettings 中的字段名
2. **默认值**: 默认配置
3. **影响范围**: 哪些服务/组件会读取此配置
4. **响应逻辑**: 配置变更时的响应流程
5. **依赖关系**: 与其他配置项的依赖关系

#### 示例：quickAskIncludeOCR

```markdown
### quickAskIncludeOCR

**类型**: Boolean
**默认值**: true
**配置位置**: AppSettings.swift:145

**影响范围**:
- QuickAskService.swift:179-202 (上下文收集)
- ContextService.swift (OCR 上下文提供)

**响应逻辑**:
1. 用户在设置中切换 "Include OCR" 开关
2. AppSettings.quickAskIncludeOCR 更新
3. 下次 Quick Ask 触发时，QuickAskService 检查此配置
4. 如果为 true，调用 ContextService 获取 OCR 上下文
5. 如果为 false，跳过 OCR 上下文收集

**依赖关系**:
- 依赖: ScreenOCRService (OCR 服务必须可用)
- 互斥: 无
- 关联: quickAskIncludeScreenshot (通常一起使用)
```

---

## 第三阶段：实施计划

### Phase 1: 功能流视图文档（已完成）
- ✅ 创建树形结构功能映射
- ✅ 标记已实现/待优化/计划功能
- ✅ 记录入口、实现文件、配置选项

### Phase 2: 配置逻辑文档（1-2 天）
- 为所有配置项创建文档
- 记录响应逻辑和依赖关系
- 创建配置项索引

### Phase 3: QuickAsk/QuickAnswer 优化（2-3 天）
- 设计统一的视觉风格
- 重构 HUD 和 Answer Panel 布局
- 优化交互流程
- 测试与验证

### Phase 4: 设置界面统一（2-3 天）
- 设计统一的设置页面布局
- 创建统一的设置组件库
- 重构 9 个设置标签页
- 测试与验证

### Phase 5: 验收与文档（1 天）
- 完整测试所有优化功能
- 更新用户文档
- 创建变更日志

---

## 验收标准

### 功能流视图
- ✅ 树形结构完整映射所有功能
- ✅ 每个功能都有入口、实现文件、配置选项
- ✅ 功能状态标记清晰（已实现/待优化/计划）

### 配置逻辑文档
- [ ] 所有配置项都有完整文档
- [ ] 响应逻辑和依赖关系清晰
- [ ] 配置项索引可快速查找

### UI/UX 优化
- [ ] QuickAsk/QuickAnswer 面板风格统一
- [ ] 设置界面 9 个标签页风格统一
- [ ] 所有 UI 使用 DesignTokens（无硬编码值）
- [ ] 交互流程流畅自然

### 质量标准
- [ ] Build gate: PASS
- [ ] Test gate: PASS
- [ ] Concurrency gate: PASS
- [ ] 用户体验测试: PASS

---

## 风险与缓解

### 风险 1: 范围蔓延
**描述**: UI/UX 优化可能引发更多优化需求
**缓解**: 严格按照 PRD 范围执行，新需求记录到 backlog

### 风险 2: 破坏现有功能
**描述**: UI 重构可能影响现有功能
**缓解**:
- 每次修改后运行完整测试套件
- 保持小步迭代，及时验证
- 使用 git worktree 隔离开发

### 风险 3: DesignTokens 不足
**描述**: 现有 DesignTokens 可能不足以支持所有 UI 需求
**缓解**:
- 优先使用现有 tokens
- 必要时扩展 DesignTokens
- 保持 tokens 的一致性和可维护性

---

## 参考文档

- 功能流视图: 本文档
- 设计系统: `docs/style/INDEX.md`
- DesignTokens: `spoke/UI/Theme/DesignTokens.swift`
- 架构文档: `docs/design-*.md`
- 产品需求: `docs/prd.md`

---

## 附录：关键文件索引

### 核心服务
- `spoke/Services/HotKeyService.swift` - 全局热键管理
- `spoke/Services/QuickAskService.swift` - Quick Ask 服务
- `spoke/Services/AppSettings.swift` - 应用配置
- `spoke/Services/SelectionMonitorService.swift` - 文本选择监控
- `spoke/Services/SelectionToolbarManager.swift` - 选择工具栏管理

### UI 组件
- `spoke/UI/HUD/FloatingCapsuleView.swift` - 浮动 HUD
- `spoke/UI/QuickAsk/AnswerPanelView.swift` - Answer Panel
- `spoke/UI/Settings/SettingsView.swift` - 设置界面
- `spoke/UI/Screenshot/ScreenshotWindow.swift` - 截图窗口
- `spoke/UI/LiveCaption/LiveCaptionView.swift` - 实时字幕

### 核心逻辑
- `spoke/Core/Audio/AudioRecorderService.swift` - 音频录制
- `spoke/Core/Transcription/TranscriptionProvider.swift` - 转录引擎
- `spoke/Core/LLM/LLMProvider.swift` - LLM 提供商
- `spoke/Core/Screenshot/ScreenshotManager.swift` - 截图管理
- `spoke/Core/LiveCaption/CaptionLineBuffer.swift` - 字幕缓冲

### 设计系统
- `spoke/UI/Theme/DesignTokens.swift` - 设计 tokens（单一真实来源）
