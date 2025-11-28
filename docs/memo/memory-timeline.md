# MM 记忆时间线

维护者: MM | 项目: SpokenAnyWhere | 更新: 2025-11-28

## Learns (Latest at top)

- [T046] NSPanel 里 NSTextView 的 ⌘V 等快捷键：需重写 performKeyEquivalent 手动捕获并调用 paste/copy/cut/selectAll
- [T045] 视频缩略图：AVAssetImageGenerator.copyCGImage(at: .zero) 提取首帧；maximumSize 控制输出尺寸
- [T044] 图片缩略图性能：大图附件应异步生成缩略图(256px)，先加载占位再后台处理，存储 (原图+缩略图) 结构
- [T043] SwiftUI overlay 不参与布局计算：条件渲染的视图放 .overlay{} 内而非 ZStack，可避免布局跳动
- [T042] SwiftUI 拖拽覆盖原生视图：用 Color.clear + overlay + contentShape 包裹 onDrop，可在 NSTextView 之上响应拖拽
- [T041] 附件缩略图优化：使用 NSWorkspace.shared.icon(forFile:) 获取大图标 + 扩展名角标；统一尺寸 52x52
- [T040] 原生视图(NSTextView)会抢夺 SwiftUI onDrop 事件，需 unregisterDraggedTypes() 禁止其接收拖拽
- [T039] 拖拽区域优化：将 onDrop 和蒙版移至最外层容器(CapsuleView)，使用 ZStack + 全屏 overlay 实现 Hawar 风格大蒙版
- [T038] NSTextView 子类化可自定义键盘行为(Shift+Enter 换行/Enter 发送)；剪贴板图片用 readObjects forClasses NSImage
- [T037] 共享单例服务(如 audioService)的回调会被覆盖，每次使用前必须重新设置回调
- [T036] 测试模式可用 useSimpleStorage 开关让 Keychain 回退到 UserDefaults，发布前改回 false
- [T035] NSPanel 需要键盘输入时必须 canBecomeKey=true + makeKey()；ESC 键用 cancelOperation 处理
- [T034] Quick Ask 需要独立的状态管理(QuickAskState)和服务(QuickAskService)，与录音模式解耦
- [T033] 多套快捷键共存时，checkModifiersMatch 需要 target 参数区分不同快捷键的修饰符
- [T032] 彻底解决 Keychain 弹窗需移除所有回退逻辑，并使用统一存储 + 迁移标记
- [T031] System Prompt 要保守处理驼峰：只对英文/拼音词消歧义，中文保持原样；用具体例子说明
- [T030] System Prompt 要明确指导 LLM 如何利用上下文，否则 LLM 可能忽略剪贴板历史
- [T029] ClipboardHistoryService 使用定时器轮询剪贴板变化，过滤敏感信息（密码/API Key/长密钥）
- [T028] 剪贴板历史比当前剪贴板更有价值：可提供专业术语/人名/项目名上下文
- [T027] SwiftUI overlay 在 clipShape 之后才能显示超出边界的效果
- [T026] CGEvent tap 会被系统因超时自动禁用，需要监听 tapDisabledByTimeout 事件
- [T025] Keychain 访问可以用内存缓存优化，避免开发阶段重复授权弹窗
- [T024] AngularGradient 配合 rotationEffect 可以实现跑马灯效果
- [T023] ForEach + ZStack + rotationEffect 可以实现彩色点旋转动画

## 智能索引

技术栈: #swiftui(T023,T024,T027) #cgevent(T026,T033) #keychain(T025,T032,T036) #clipboard(T028,T029) #llm-prompt(T030,T031) #nspanel(T035)
架构模式: #hud-animation(@C001:T023,T024,T027) #event-handling(@C002:T026,T033) #security(@C003:T025,T032,T036) #context(@C004:T028,T029,T030,T031) #quick-ask(@C005:T033,T034,T035)
任务类型: #ui-optimization(T023,T024,T027) #bug-fix(T026,T035) #performance(T025) #design(T028,T034) #prompt-engineering(T030,T031) #feature(T033,T034)

## 记录条目 (Latest at bottom)

[2025-11-27 T027] LLM UI/UX 优化

- PROB: 流光效果被遮挡、转圈样式单调、消失时间过长
- PLAN: RunningLightBorder overlay + StatusIndicator 彩色点 + scheduleHide 减半
- TIME: 0.5h | TAGS: #swiftui #animation #ui-optimization
- LINK: spoke/UI/HUD/FloatingCapsuleView.swift
- STAT: [√]完成 4/4 通过
- NOTE: overlay 必须在 clipShape 之后才能显示超出边界的流光效果

[2025-11-27 T026] 快捷键失效修复

- PROB: CGEvent tap 被系统禁用导致快捷键失效
- PLAN: 监听 tapDisabledByTimeout 事件 + 自动重新启用 + 状态重置
- TIME: 0.2h | TAGS: #cgevent #bug-fix #event-handling
- LINK: spoke/Services/HotKeyService.swift
- STAT: [√]完成 3/3 通过
- NOTE: 系统会在事件处理超时时自动禁用 tap，需要主动重新启用

[2025-11-27 T025] Keychain 访问优化

- PROB: 开发阶段每次启动都弹 Keychain 授权
- PLAN: 内存缓存 + DispatchQueue 线程安全 + 首次访问后缓存
- TIME: 0.2h | TAGS: #keychain #security #performance
- LINK: spoke/Core/LLM/KeychainService.swift
- STAT: [√]完成 3/3 通过
- NOTE: 缓存策略减少重复授权，生产环境签名一致不会出现此问题

[2025-11-27 T028] 剪贴板历史功能设计

- PROB: 当前剪贴板只有一条信息量有限，如何提供更多上下文帮助转录
- PLAN: 底层静默保存历史(20-50 条) + 替代当前剪贴板选项 + 用户可选开关
- TIME: 设计讨论 | TAGS: #context #llm #design
- LINK: docs/roadmap.md#Context-Awareness
- STAT: [√] 设计完成
- NOTE: 历史可识别专业术语/人名/项目名；需过滤敏感信息+限制单条长度

[2025-11-27 T029] 剪贴板历史功能实现

- PROB: 实现 ClipboardHistoryService 和集成
- PLAN: 定时器轮询 + 敏感过滤 + JSON 持久化 + LLMPipeline 集成
- TIME: 0.5h | TAGS: #clipboard #llm #implementation
- LINK: spoke/Services/ClipboardHistoryService.swift
- STAT: [√] 完成 4/4 通过
- NOTE: 检查间隔 1s；单条限制 500 字符；过滤密码/API Key/长密钥

[2025-11-27 T030] System Prompt 优化 v1~v3

- PROB: LLM 忽略剪贴板历史，无法修正术语（如 mirroday → mirrored）
- PLAN: 重写 defaultSystemPrompt 明确指导利用历史修正；添加同音纠错规则
- TIME: 0.3h | TAGS: #llm-prompt #prompt-engineering #context
- LINK: spoke/Core/LLM/LLMSettings.swift#defaultSystemPrompt
- STAT: [√] 完成
- NOTE: Prompt 迁移用 contains 匹配旧版特征字符串

[2025-11-27 T031] System Prompt 保守驼峰策略

- PROB: Prompt 太激进，把中文也改成驼峰了
- PLAN: 明确只对英文/拼音词消歧义 + 用具体例子说明中文不变 + v1~v4 迁移
- TIME: 0.2h | TAGS: #llm-prompt #prompt-engineering #iteration
- LINK: spoke/Core/LLM/LLMSettings.swift#defaultSystemPrompt
- STAT: [√] 完成
- NOTE: Prompt 给 LLM 具体例子比抽象规则更有效；后续可结合活跃应用判断是否代码环境

[2025-11-27 T032] Keychain 统一存储与迁移优化

- PROB: 开发环境签名变化导致每次启动都重复弹窗 (2 次+)
- PLAN: 统一存储(Unified Storage) + 一次性迁移(Migration) + 移除 Provider 回退逻辑 + hasConsolidatedAPIKeys Flag
- TIME: 0.5h | TAGS: #keychain #security #optimization
- LINK: spoke/Core/LLM/LLMSettings.swift
- STAT: [√]完成 3/3 通过
- NOTE: 迁移仅在首次运行触发；Provider 应完全依赖注入的 API Key 而非自行访问 Keychain

[2025-11-28 T033] Quick Ask 快捷键系统

- PROB: 需要独立快捷键触发 Quick Ask，与录音快捷键并存
- PLAN: AppSettings 添加 quickAskKeyCode/Modifiers + HotKeyService 区分两套快捷键 + 设置界面支持自定义
- TIME: 0.3h | TAGS: #cgevent #hotkey #feature
- LINK: spoke/Services/HotKeyService.swift#handleQuickAskKeyDown
- STAT: [√]完成 3/3 通过
- NOTE: checkModifiersMatch 需要 target 参数区分；默认 ⌥T

[2025-11-28 T034] Quick Ask 功能完整实现

- PROB: 实现快速提问功能：语音+文字输入 → AI 回答
- PLAN: QuickAskState(状态) + QuickAskInputView(输入框) + QuickAskCapsuleView(HUD) + QuickAskService(流程) + AnswerPanelView(回答窗口)
- TIME: 1.5h | TAGS: #feature #swiftui #architecture
- LINK: spoke/Core/QuickAsk/; spoke/UI/HUD/QuickAsk\*; spoke/Services/QuickAskService.swift
- STAT: [√]完成 5/7 (基础功能完成，追问/截图待实现)
- NOTE: 与录音模式解耦；附件支持拖拽；LLMPipeline 新增 chat() 方法

[2025-11-28 T035] Quick Ask 窗口键盘输入修复

- PROB: Quick Ask 输入框无法输入、ESC/Enter 无响应
- PLAN: 创建 QuickAskPanel(canBecomeKey=true) + cancelOperation 处理 ESC + makeKey() 激活焦点
- TIME: 0.3h | TAGS: #nspanel #bug-fix #keyboard
- LINK: spoke/UI/HUD/FloatingPanel.swift#QuickAskPanel
- STAT: [√]完成 3/3 通过
- NOTE: FloatingPanel 的 canBecomeKey=false 导致无法接收键盘；需要键盘的场景必须创建独立 Panel

[2025-11-28 T036] Keychain 测试模式开关

- PROB: 开发阶段每次启动都要输入 Keychain 密码很烦
- PLAN: KeychainService 添加 useSimpleStorage 开关：true=UserDefaults / false=Keychain
- TIME: 0.1h | TAGS: #keychain #debug #dx
- LINK: spoke/Core/LLM/KeychainService.swift#useSimpleStorage
- STAT: [√]完成 1/1 通过
- NOTE: 测试数据存 debug.apikey.\* 前缀；发布前改回 false

[2025-11-28 T037] Quick Ask 后录音无波形

- PROB: Quick Ask 结束后，按 ⌥R 录音没有声纹波动、无法转录
- PLAN: startRecordingSession 重新 setupAudioCallbacks + cancelSession/sendQuestion 调用 resetQuickAskState
- TIME: 0.1h | TAGS: #singleton #callback #bug-fix
- LINK: spoke/Services/RecordingController.swift#startRecordingSession
- STAT: [√]完成 2/2 通过
- NOTE: 共享单例服务的回调会互相覆盖；每次使用前必须重新设置回调
