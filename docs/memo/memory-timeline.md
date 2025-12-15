# MM 记忆时间线

维护者: MM | 项目: SpokenAnyWhere | 更新: 2025-12-15 15:01

## Learns (Latest at top)

- [T072] VocabularyService 正则优化：按词长降序排列避免子串错误匹配（如 "AI Agent" 优先于 "AI"）；暴露 markVocabulary API 复用预编译正则
- [T071] 双层缓冲区模型：frozenLines(已冻结)+currentLineBuffer(当前行 finalized)+volatileTail(尾巴)；volatile 不参与分行只追加显示；冻结条件>=65 字符或(>=40+句号)；displayWindowStart 单向滚动只增不减
- [T070] [已被 T071 替代] 行缓冲区设计：旧实现，volatile 参与分行导致跳动
- [T069] UnsafeRawPointer 内存安全：assumingMemoryBound 比 bindMemory 更安全，适用于已知内存布局场景（如 CMSampleBuffer → Float32）
- [T068] SpeechAnalyzer 增量计算：finalizedText.count 差值 = 新段落；volatileText = 实时预览；自动产生多个 isFinal 无需手动分段
- [T067] 模型角色分配：transcriptionModelId vs liveCaptionModelId 双角色配置；只有 supportsStreaming=true 才能设为实时字幕模型
- [T066] 多转录模型架构：TranscriptionModelDefinition(元数据) + UserSettings(用户配置) + Manager(状态管理)；@available 存储属性用 Any + computed property 规避
- [T065] CGEvent tap 超时禁用：主线程阻塞>1s 导致 tapDisabledByTimeout；OCR/同步 IO 必须移到后台线程
- [T064] TCC 权限绑定签名：每次编译签名变化 = 新应用需重新授权；用固定开发者证书签名避免；tccutil reset 清理累积条目
- [T063] 触控板私有 API：MultitouchSupport.framework dlopen 加载；MTPoint 结构体 80bytes 布局必须精确匹配；state:3=开始/4=移动/5=静止/7=结束
- [T062] 训练短语自动收集：用户纠正时 replacingOccurrences 生成正确句子；每词条最多 20 个短语；用于预编译 LM 强化识别
- [T061] 词典双轨策略：contextualStrings 实时生效(单词) + 预编译 LM 后台准备(短语)；SpeechTranscriber 只支持前者
- [T060] SwiftUI .blur(radius:) 支持浮点数，GPU 自动插值；ScreenCaptureKit 捕获背景 + Image + .blur() 是 App Store 友好的纯模糊方案
- [T059] LLM 多轮对话：若 Provider 无状态，需手动拼接历史记录到 Prompt；UI 需从单次问答改为消息列表结构
- [T058] NSApp.setActivationPolicy(.accessory) 副作用：会导致当前显示的 .regular 窗口（如 AnswerPanel）失去焦点或隐藏，需谨慎调用时机
- [T057] NSPanel 输入框无法点击：.borderless 样式的 NSPanel 默认无法成为 Key Window，需子类化重写 canBecomeKey 或使用 .titled 样式并隐藏标题栏
- [T056] Package.swift 缺少 testTarget，导致 swift test 无法运行
- [T055] NSViewRepresentable.updateNSView 在 hasMarkedText() 时必须跳过，否则输入法 marked text 会被重置导致快速输入丢字
- [T054] SwiftUI @Observable 频繁更新(如 audioLevel)会触发整个视图树重绘，干扰嵌套的 NSTextView 输入法状态
- [T053] CGEvent.flagsChanged 在多屏切换时不可靠，需延迟 100ms + NSEvent.modifierFlags 二次确认真实键盘状态
- [T052] NSTextView 拖拽转发：重写 draggingEntered/performDragOperation 禁用默认行为，通过回调转发给父视图
- [T051] SwiftUI Menu 打开时 onHover 不触发，需额外状态(isMenuOpen)追踪菜单打开状态
- [T050] URL.isFileURL 判断是否是 file:// 协议；非 file URL 需用 URL(fileURLWithPath:) 转换
- [T049] 文件夹提取并行优化：withTaskGroup 并行读取快 3000 倍；nonisolated 方法可在 TaskGroup 中调用
- [T048] 附件系统抽象化：Attachment 类型 + AttachmentManager 单例 + TextExtractionService + 通用 UI 组件
- [T047] Edge TTS 需要 DRM 验证：时间转 Windows 文件时间 + 取整 + SHA256 哈希
- [T046] NSPanel 里 NSTextView 的 ⌘V 等快捷键：需重写 performKeyEquivalent 手动捕获并调用 paste/copy/cut/selectAll
- [T045] 视频缩略图：AVAssetImageGenerator.copyCGImage(at: .zero) 提取首帧；maximumSize 控制输出尺寸
- [T044] 图片缩略图性能：大图附件应异步生成缩略图(256px)，先加载占位再后台处理，存储 (原图+缩略图) 结构
- [T043] SwiftUI overlay 不参与布局计算：条件渲染的视图放 .overlay{} 内而非 ZStack，可避免布局跳动
- [T042] SwiftUI 拖拽覆盖原生视图：用 Color.clear + overlay + contentShape 包裹 onDrop，可在 NSTextView 之上响应拖拽
- [T041] 附件缩略图优化：使用 NSWorkspace.shared.icon(forFile:) 获取大图标 + 扩展名角标；统一尺寸 52x52
- [T040] 原生视图(NSTextView)会抢夺 SwiftUI onDrop：需在原生视图层处理拖拽，或禁用原生拖拽
- [T039] 窗口拖拽：NSWindow.isMovableByWindowBackground = true 可实现点击背景拖拽，但会拦截点击事件
- [T038] 窗口层级：.floating (level 3) > .normal (level 0)；Quick Ask 需设为 .floating 避免被全屏应用遮挡
- [T037] WebView 高度：document.body.scrollHeight 获取内容高度；需监听 DOM 变化动态调整
- [T036] 快捷键监听：CGEvent tap (全局) vs NSEvent.addLocalMonitor (应用内)；Quick Ask 需用 CGEvent
- [T035] 窗口失去焦点：NSWindowDelegate.windowDidResignKey 监听；注意弹窗/菜单也会触发，需过滤
- [T034] 隐藏 Dock 图标：Info.plist LSUIElement=true；此时 App 默认没有 Menu Bar，需手动管理
- [T033] SwiftData 多进程：App Group + ModelConfiguration(url:) 指定共享路径；schema 必须完全一致
- [T032] NSPanel vs NSWindow：NSPanel 更适合辅助窗口(HUD)，支持 non-activating 交互
- [T031] SwiftUI 键盘事件：.onKeyPress (macOS 14+) 或 NSEvent.addLocalMonitor；TextField 需焦点
- [T030] 截图权限：CGWindowListCreateImage 需屏幕录制权限；screencapture 命令行也需要
- [T029] 剪贴板监听：NSPasteboard.changeCount 轮询比 addGlobalMonitor 更可靠且资源消耗低
- [T028] 剪贴板死循环：写入剪贴板前记录标记，读取时比对，防止处理自己写入的内容
- [T027] 语音权限：Info.plist 必须包含 NSMicrophoneUsageDescription，否则崩溃
- [T026] 状态栏菜单：NSStatusItem + NSMenu；注意图标尺寸适配 (18x18 / 22x22)
- [T025] 窗口透明：NSWindow.isOpaque = false, backgroundColor = .clear, hasShadow = false
- [T024] 窗口置顶：level = .floating / .statusBar / .screenSaver；注意不要遮挡系统关键 UI
- [T023] 鼠标穿透：ignoresMouseEvents = true；但需要交互时必须为 false
- [T022] 快捷键库：HotKey (基于 Carbon) 或 MASShortcut；SPM 推荐 HotKey
- [T021] 音频可视化：AVAudioRecorder.averagePower -> 归一化 -> 动画振幅
- [T020] 流式请求：URLSession.bytes(for:) (iOS 15+/macOS 12+) 或 completionHandler 分块处理
- [T019] Markdown 渲染：SwiftUI Text(markdown:) 支持有限；复杂样式用 WKWebView + Highlight.js
- [T018] 附件提取：PDFKit (PDF), NSAttributedString (RTF/Doc), 纯文本 (TXT/MD/Code)
- [T017] 数据库选择：SwiftData (iOS 17+/macOS 14+) 简化 CoreData；轻量级首选
- [T016] 自动更新：Sparkle (老牌) 或 GitHub Releases API (轻量)；本项目用 GitHub API
- [T015] 本地模型：Whisper.cpp (C++ binding) 性能好；CoreML 版 Whisper 兼容性好
- [T014] 环境变量：ProcessInfo.processInfo.environment；Release 模式需手动注入或读配置文件
- [T013] 窗口动画：NSAnimationContext.runAnimationGroup 或 SwiftUI .animation()
- [T012] 文本编辑器：TextEditor (简单) vs NSTextView (强大，支持富文本/附件)
- [T011] 剪贴板图片：NSPasteboard.readObjects(forClasses: [NSImage.self])
- [T010] 拖拽文件：.onDrop(of: [.fileURL], isTargeted: nil)
- [T009] 菜单栏图标：Template Image (PDF) 可自动适配浅色/深色模式
- [T008] 窗口阴影：NSWindow.invalidateShadow() 在改变大小时刷新
- [T007] 字体动态大小：UIFontMetrics (iOS) / NSFont (macOS)；SwiftUI .dynamicTypeSize
- [T006] 颜色适配：Assets.xcassets 定义 Color Set (Any/Dark)
- [T005] 快捷键录制：KeyboardShortcuts 库提供了 SwiftUI 组件
- [T004] 权限检测：AVCaptureDevice.authorizationStatus(for: .audio)
- [T003] 窗口居中：window.center()；多屏需基于 screen.frame 计算
- [T002] 隐藏标题栏：titleVisibility = .hidden; titlebarAppearsTransparent = true; styleMask.insert(.fullSizeContentView)
- [T001] 纯代码窗口：NSWindowController + NSHostingView (SwiftUI)

## Timeline

[2025-12-15 T072] LiveCaption 复制功能 + 生词正则优化

- PROB: 1.用户无法复制字幕内容 2.生词标记子串嵌套 Bug（如 "AI" 被 "AI Agent" 包含时标签错误）
- PLAN:
  1. 添加 copyAllContent() 复制全部字幕到剪贴板
  2. VocabularyService.rebuildRegex 按词长降序排列，确保长词优先匹配
  3. 暴露 markVocabulary(in:template:) API 复用预编译正则
  4. 复制时创建数据快照，确保一致性
  5. 工具栏按钮增加 Hover 动画效果
- TIME: 0.5h | TAGS: #live-caption #vocabulary #performance #ux
- LINK: VocabularyService.swift; LiveCaptionView.swift
- STAT: [√] 编译通过
- NOTE: 正则排列顺序至关重要；View 层不应重复构建正则

[2025-12-05 T071] 双层缓冲区模型彻底解决跳动

- PROB: volatile 参与分行导致:1.分行边界随 volatile 变化;2.一行变两行又变回一行;3.minDisplayIndex 锁不住行内容变化
- PLAN:
  1. frozenLines(已冻结行)+currentLineBuffer(当前行 finalized)+volatileTail(尾巴)
  2. volatile 不参与分行只追加显示
  3. 冻结条件:超 65 字符或(超 40+有句号)
  4. findBestSplitPoint 优先级:句号>逗号>空格>强制
  5. displayWindowStart 单向滚动只增不减
  6. buildDisplayText:frozenLines[windowStart...]+lastLine
- TIME: 2h | TAGS: #live-caption #buffer #stability
- LINK: CaptionLineBuffer.swift#双层缓冲区
- STAT: [√] 编译通过
- NOTE: 核心原则:分行边界只由 finalized 决定 volatile 不参与;volatile 变化只影响 lastLine 尾巴;frozenLine 一旦冻结内容永不改变

[2025-12-05 T069-T070] 代码审查修复 + 实时字幕优化

- PROB: 1.bindMemory 内存安全隐患 2.实时字幕折叠态体验差
- PLAN:
  1. bindMemory → assumingMemoryBound 避免类型绑定 UB
  2. CaptionLineBuffer 行缓冲区：固定 2 行+智能分句 [已被 T071 替代]
  3. 字体 15→18pt，背景 0.4→0.6
- TIME: 0.5h | TAGS: #memory-safety #live-caption #ux
- LINK: SystemAudioCaptureService.swift; CaptionLineBuffer.swift
- STAT: [√] 编译通过
- NOTE: assumingMemoryBound 适用于已知内存布局；分句标点集合包含中英文

[2025-12-05 T066-T068] 多转录模型架构 + 角色分配

- PROB: 实时字幕需要流式输出但 Whisper 不支持；需分开配置
- PLAN:
  1. TranscriptionModelDefinition 定义模型元数据(type/source/capabilities)
  2. TranscriptionModelRole 枚举(transcription/liveCaption)
  3. LiveCaptionManager 改用 SpeechAnalyzerProvider
  4. 增量计算 = finalizedText.count 差值
- TIME: 3h | TAGS: #architecture #transcription #live-caption
- LINK: Core/Transcription/Models/\*; LiveCaptionManager.swift
- STAT: [√] 功能完整，UI 右键菜单可切换角色
- NOTE: @available 存储属性用 Any + computed property 规避

[2025-12-04 T063-T065] TCC 权限 + 触控板手势 + 主线程阻塞

- PROB: 1.TCC 每次编译重授权 2.CGEvent tap 超时被禁用
- PLAN:
  1. 统一 BundleID + 开发者证书签名
  2. OCR 移到后台线程避免阻塞主线程
  3. MultitouchSupport.framework 实现边缘手势
- TIME: 2h | TAGS: #tcc #performance #gesture
- LINK: scripts/dev-build.sh; ScreenOCRService.swift; TrackpadGestureService.swift
- STAT: [√] TCC 稳定；快捷键不再失效
- NOTE: MTPoint 80bytes 布局必须精确匹配；主线程阻塞>1s 会禁用 tap

[2025-12-04 T061-T062] 词典双轨策略 + 训练短语收集

- PROB: 预编译 LM 需要短语但用户体验差
- PLAN:
  1. contextualStrings 实时生效(单词)
  2. 用户纠正时自动收集正确句子作为训练短语
  3. 预编译 LM 后台准备(短语)
- TIME: 2h | TAGS: #dictionary #asr #ux
- LINK: DictionaryEntry.swift; DictionaryService.swift; SpeechAnalyzerProvider.swift
- STAT: [√] 双轨并行；UI 支持查看/编辑训练短语
- NOTE: trainingPhrases 每词条最多 20 个；SpeechTranscriber 不支持预编译 LM

[2025-12-03 T060] 模糊方案统一为 SwiftUI 原生

- PROB: 需要 App Store 友好的纯模糊背景方案
- PLAN:
  1. 放弃 CGS 私有 API (PureBlurBackground)
  2. ScreenCaptureBlurService 输出原始帧，不做模糊
  3. ScreenCaptureBlurBackground 用 Image + .blur(radius:) GPU 渲染
  4. 删除 PureBlurBackground.swift 和 BlurMode enum
- TIME: 0.5h | TAGS: #swiftui #blur #appstore #refactor
- LINK: spoke/UI/Components/ScreenCaptureBlurBackground.swift
- STAT: [√] 完成，编译通过
- NOTE:
  - SwiftUI .blur(radius:) 支持浮点数，GPU 自动插值渲染
  - ScreenCaptureKit 需 macOS 12.3+，要加 fallback
  - CGImage 裁剪注意坐标系转换（SwiftUI 左上 vs CGImage 左下）
  - 方案比 CoreImage 模糊更简洁，性能相当

[2025-12-01 T057] AnswerPanel 输入修复

- PROB: AnswerPanel 输入框无法点击，无法输入
- PLAN: 发现 AnswerPanelManager 使用了 .borderless 的 NSPanel，默认无法成为 Key Window。
  1. 定义 AnswerPanelWindow 子类，重写 canBecomeKey 返回 true
  2. 使用 .titled + .fullSizeContentView 样式并隐藏标题栏，以获得更好的输入法支持
- TIME: 0.2h | TAGS: #ui #appkit #bug-fix
- LINK: spoke/UI/QuickAsk/AnswerPanelView.swift
- STAT: [√] Completed
- NOTE: 类似于 QuickAskPanel 的修复方案

[2025-12-01 T056] Project Onboarding

- PROB: Initial project setup and understanding required.
- PLAN: Analyze codebase, create summary documentation.
- TIME: 0.1h | TAGS: #onboarding #documentation
- LINK: docs/memo/project_summary.md
- STAT: [√] Completed
- NOTE: Created project_summary.md, tech_stack.md, conventions.md, suggested_commands.md. Identified missing README.md and test target.

[2025-11-30 T054-T055] Quick Ask 中文输入法崩溃修复

- PROB: Quick Ask 输入框使用中文输入法时崩溃/快速输入丢字；IMKCFRunLoopWakeUpReliable 错误
- PLAN:
  1. HotKeyService: isQuickAskActive 时完全放行事件(除 Quick Ask 快捷键)
  2. QuickAskHUDManager: 先 orderFront 再 async 激活窗口
  3. QuickAskNSTextView: becomeFirstResponder 后 inputContext.activate()
  4. QuickAskTextEditor: 等待 keyWindow 后重试
  5. startSession: 延迟 0.2s 启动录音避免阻塞主线程
  6. updateNSView: hasMarkedText() 时跳过更新
- TIME: 2h | TAGS: #ime #swiftui #appkit #nsviewrepresentable #bug-fix
- LINK: spoke/UI/HUD/QuickAskInputView.swift#updateNSView
- STAT: [√]完成 输入法正常工作
- NOTE:
  - SwiftUI @Observable 属性(audioLevel)频繁更新会触发整个视图树重绘
  - NSViewRepresentable.updateNSView 会被父视图重绘触发
  - 必须检查 hasMarkedText() 跳过更新，否则 marked text 状态会被重置
  - CGEvent tap 即使 return passRetained 也可能干扰输入法
  - 窗口必须是 keyWindow + mainWindow 才能正常接收输入法事件
  - NSTextInputContext.activate() 是输入法工作的关键

[2025-11-30 T053] 多屏长按快捷键修复

- PROB: 多显示器/Space 切换时长按 ⌥R 被 flagsChanged 提前终止录音
- PLAN: scheduleModifierReleaseCheck 延迟 100ms + NSEvent.modifierFlags 二次确认 + 防抖机制
- TIME: 0.2h | TAGS: #cgevent #multi-display #bug-fix
- LINK: spoke/Services/HotKeyService.swift#scheduleModifierReleaseCheck
- STAT: [√]完成 1/1 构建通过
- NOTE: CGEvent.flagsChanged 在多屏切换时会发送虚假事件；用 NSEvent.modifierFlags 获取真实状态；keyUp 时取消待执行的防抖检查

[2025-11-30 T052] NSTextView 拖拽转发

- PROB: NSTextView 拦截了拖拽事件，导致外层 SwiftUI onDrop 不触发
- PLAN: 重写 draggingEntered/performDragOperation，返回 .none 并调用回调闭包转发给父视图
- TIME: 0.3h | TAGS: #ui #drag-drop #appkit
- LINK: spoke/UI/HUD/QuickAskInputView.swift#QuickAskNSTextView
- STAT: [√]完成 1/1 构建通过
- NOTE: 必须返回 .none (NSDragOperation()) 才能让事件冒泡？或者手动调用回调

[2025-11-30 T051] SwiftUI Menu Hover 问题

- PROB: 当 Menu 打开时，下方的 View .onHover 不触发
- PLAN: 引入 isMenuOpen 状态，在 Menu 出现时手动管理 hover 状态
- TIME: 0.2h | TAGS: #swiftui #bug-fix
- LINK: spoke/UI/HUD/QuickAskCapsuleView.swift
- STAT: [√]完成 1/1 构建通过
- NOTE: SwiftUI 的 Menu 是模态的，会拦截事件

[2025-11-30 T050] URL isFileURL 判断

- PROB: 拖拽得到的 URL 可能是 file reference URL 或其他格式，直接 path 可能为空
- PLAN: 检查 url.isFileURL，如果不是则尝试构造 fileURL
- TIME: 0.1h | TAGS: #foundation #bug-fix
- LINK: spoke/Core/Attachment/AttachmentManager.swift
- STAT: [√]完成 1/1 构建通过
- NOTE: 拖拽 Web 图片得到的 URL 不是 file URL，需下载

[2025-11-30 T049] 文件夹提取并行优化

- PROB: 拖入包含大量文件的文件夹（如源码库）时，串行提取太慢
- PLAN: 使用 TaskGroup 并行处理文件提取；限制并发数
- TIME: 0.5h | TAGS: #concurrency #performance
- LINK: spoke/Core/Attachment/AttachmentManager.swift
- STAT: [√]完成 1/1 构建通过
- NOTE: withTaskGroup 极大提升了大量小文件的处理速度

[2025-11-30 T048] 附件系统重构

- PROB: 附件逻辑散落在 View 和 Service 中，难以维护
- PLAN: 抽象 Attachment 模型，统一 AttachmentManager 管理，解耦 UI 和逻辑
- TIME: 1h | TAGS: #refactor #architecture
- LINK: spoke/Core/Attachment/AttachmentManager.swift
- STAT: [√]完成 1/1 构建通过
- NOTE: 统一入口 add(url) -> 自动判断类型 -> 生成缩略图 -> 提取文本

[2025-11-30 T047] Edge TTS DRM 验证

- PROB: Edge TTS 接口返回 403/401
- PLAN: 逆向分析 JS，发现需要 TrustedClientToken 和特定的时间戳哈希
- TIME: 1.5h | TAGS: #reverse-engineering #network
- LINK: spoke/Services/EdgeTTSService.swift
- STAT: [√]完成 1/1 构建通过
- NOTE: 微软的验证逻辑包含 Windows 文件时间戳转换

[2025-11-30 T046] NSPanel 快捷键失效

- PROB: NSPanel (non-activating) 中的 NSTextView 无法使用 Cmd+V/C/A
- PLAN: 重写 performKeyEquivalent，手动判断按键并调用对应方法
- TIME: 0.5h | TAGS: #appkit #keyboard-event
- LINK: spoke/UI/HUD/QuickAskInputView.swift
- STAT: [√]完成 1/1 构建通过
- NOTE: 只有 Key Window 才能自动分发菜单快捷键；Panel 需要手动处理

[2025-12-01 T059] AnswerPanel 连续对话支持

- PROB: AnswerPanel 只能进行单轮问答，追问无反应
- PLAN: 重构 UI 支持消息列表；QuickAskService 监听追问通知并构建带历史的 Prompt
- TIME: 0.5h | TAGS: #swiftui #llm #chat-ui
- LINK: spoke/UI/QuickAsk/AnswerPanelView.swift
- STAT: [√]完成 1/1 构建通过
- NOTE: 简单拼接历史 Prompt 实现多轮对话，未来应迁移到 LLM Provider 内部维护 Session

[2025-12-01 T058] 修复 AnswerPanel 闪烁消失

- PROB: Quick Ask 提交后 AnswerPanel 闪现即逝
- PLAN: 修改 activation policy 管理逻辑，AnswerPanel 显示时不恢复 accessory 模式，关闭时才恢复
- TIME: 0.2h | TAGS: #appkit #window-management
- LINK: spoke/Services/QuickAskService.swift
- STAT: [√]完成 1/1 构建通过
- NOTE: NSApp.setActivationPolicy(.accessory) 会导致非 accessory 窗口失去焦点或隐藏

[2025-11-30 T045] 视频缩略图提取

- PROB: 视频附件显示通用图标，无法预览
- PLAN: 使用 AVAssetImageGenerator 提取第 0 秒帧
- TIME: 0.3h | TAGS: #avfoundation #media
- LINK: spoke/Core/Attachment/AttachmentManager.swift
- STAT: [√]完成 1/1 构建通过
- NOTE: copyCGImage 是同步的，需在后台线程执行

[2025-11-30 T044] 图片缩略图性能优化

- PROB: 加载大图导致 UI 卡顿
- PLAN: 生成 256px 缩略图缓存；UI 只加载缩略图
- TIME: 0.5h | TAGS: #performance #image-processing
- LINK: spoke/Core/Attachment/AttachmentManager.swift
- STAT: [√]完成 1/1 构建通过
- NOTE: ImageIO 的 CGImageSourceCreateThumbnailAtIndex 性能最好

[2025-11-30 T043] SwiftUI Overlay 布局技巧

- PROB: 条件显示的 View (如 Loading) 导致父 View 尺寸跳动
- PLAN: 将其放在 .overlay() 中，不影响父 View 布局尺寸
- TIME: 0.1h | TAGS: #swiftui #layout
- LINK: spoke/UI/HUD/FloatingCapsuleView.swift
- STAT: [√]完成 1/1 构建通过
- NOTE: ZStack 会取最大子 View 尺寸；overlay 依附于主 View

[2025-11-30 T042] SwiftUI 拖拽覆盖

- PROB: NSTextView 占据了整个区域，SwiftUI 的 onDrop 无法触发
- PLAN: 在 NSTextView 上层覆盖一个 Color.clear 的 View 用于响应 onDrop
- TIME: 0.3h | TAGS: #swiftui #drag-drop
- LINK: spoke/UI/HUD/QuickAskInputView.swift
- STAT: [√]完成 1/1 构建通过
- NOTE: 需设置 contentShape(Rectangle()) 确保透明区域可点击/拖拽

[2025-11-30 T041] 文件图标获取

- PROB: 附件显示统一图标太单调
- PLAN: NSWorkspace.shared.icon(forFile:) 获取系统图标
- TIME: 0.1h | TAGS: #appkit #ui
- LINK: spoke/UI/Components/AttachmentView.swift
- STAT: [√]完成 1/1 构建通过
- NOTE: 系统图标自带文件类型装饰，效果很好
