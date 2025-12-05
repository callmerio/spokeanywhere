# MM 学习卡片

维护者: MM | 项目: SpokenAnyWhere | 更新: 2025-12-05 23:50

## C001|HUD 动画实现

ID: C001 | Tags: #swiftui #animation #overlay

Q: SwiftUI 如何实现超出边界的流光效果？
A: 使用 overlay 在 clipShape 之后，配合 AngularGradient + rotationEffect
REF: T023,T024,T027 | spoke/UI/HUD/FloatingCapsuleView.swift#RunningLightBorder

## C002|CGEvent 事件处理

ID: C002 | Tags: #cgevent #event-handling #macos

Q: CGEvent tap 被系统禁用如何恢复？
A: 监听 tapDisabledByTimeout/ByUserInput 事件，调用 CGEvent.tapEnable 重新启用
REF: T026 | spoke/Services/HotKeyService.swift#handleEvent

## C003|Keychain 缓存优化

ID: C003 | Tags: #keychain #security #performance

Q: 如何避免开发阶段重复 Keychain 授权？
A: 添加内存缓存，首次访问后缓存 API Key，使用 DispatchQueue 保证线程安全
REF: T025 | spoke/Core/LLM/KeychainService.swift#cache

## C004|剪贴板历史作为 LLM 上下文

ID: C004 | Tags: #context #llm #design #clipboard

Q: 如何利用剪贴板提供更丰富的转录上下文？
A: 底层静默保存历史(20-50 条)替代当前剪贴板；用户可选开关；过滤敏感+限制长度
REF: T028 | docs/roadmap.md#Context-Awareness

## C005|附件系统抽象化

ID: C005 | Tags: #architecture #attachment #refactor

Q: 如何让附件功能跨多入口(QuickAsk/HUD)复用？
A: Attachment 通用类型 + AttachmentManager 单例(handleDrop/pick/capture) + TextExtractionService + 通用 UI 组件
REF: T048 | spoke/Core/Attachment/AttachmentManager.swift

## C006|文件夹提取并行优化

ID: C006 | Tags: #performance #concurrency #swift

Q: Swift actor 中如何并行处理文件读取？
A: withTaskGroup + nonisolated 方法标记(可在 TaskGroup 中调用) + reserveCapacity 预分配内存
REF: T049 | spoke/Core/Attachment/TextExtractionService.swift#mergeFilesParallel

## C007|NSTextView 拖拽转发

ID: C007 | Tags: #appkit #drag-drop #nstextview

Q: 如何让 NSTextView 不拦截拖拽并转发给父视图？
A: 重写 draggingEntered/performDragOperation 禁用默认行为，通过回调链转发给 SwiftUI 层
REF: T052 | spoke/UI/HUD/QuickAskInputView.swift#QuickAskNSTextView

## C008|SwiftUI+NSTextView 输入法集成

ID: C008 | Tags: #ime #swiftui #appkit #nsviewrepresentable

Q: SwiftUI 中嵌套的 NSTextView 如何正确支持中文输入法？
A: 关键要点:

1. updateNSView 中检查 hasMarkedText() 跳过更新，避免重绘干扰 marked text
2. 父视图频繁更新(如 audioLevel)会触发 updateNSView，需隔离
3. becomeFirstResponder 后调用 inputContext.activate()
4. 窗口必须是 keyWindow + mainWindow
5. CGEvent tap 在输入时应完全放行
   REF: T054,T055 | spoke/UI/HUD/QuickAskInputView.swift#updateNSView

## C009|App Store 友好的纯模糊背景

ID: C009 | Tags: #swiftui #blur #screencapturekit #appstore

Q: 如何实现 App Store 友好的纯模糊背景（无系统色调）？
A: ScreenCaptureKit 捕获背景 + SwiftUI Image + .blur(radius:)

1. ScreenCaptureBlurService: 用 SCStream 捕获屏幕，排除自身窗口
2. 输出原始帧 CGImage（不做模糊）
3. View 层用 Image(nsImage:).blur(radius:) GPU 渲染
4. 裁剪时注意坐标系转换（SwiftUI 左上 vs CGImage 左下）
   REF: T060 | spoke/UI/Components/ScreenCaptureBlurBackground.swift

## C010|CGImage 坐标系转换

ID: C010 | Tags: #coregraphics #coordinate #swiftui

Q: SwiftUI frame 如何转换为 CGImage 裁剪区域？
A: SwiftUI origin 在左上，CGImage origin 在左下，需要翻转 Y 轴：

```swift
let cropRect = CGRect(
    x: viewFrame.origin.x * scale,
    y: screenHeight - (viewFrame.origin.y + viewFrame.height) * scale,
    width: viewFrame.width * scale,
    height: viewFrame.height * scale
)
```

REF: T060 | spoke/UI/Components/ScreenCaptureBlurBackground.swift#croppedBlurredImage

## C011|ScreenCaptureKit 系统音频捕获

ID: C011 | Tags: #screencapturekit #audio #macos

Q: 如何用 ScreenCaptureKit 捕获系统音频（非麦克风）？
A: SCStreamConfiguration 配置:

- `capturesAudio = true` 开启音频捕获
- `excludesCurrentProcessAudio = true` 排除自身声音
- `sampleRate = 16000` SFSpeech 推荐采样率
- `channelCount = 1` 单声道
- 视频设为最小(1x1)避免性能浪费
- 监听 `.audio` 类型的 sampleBuffer
  REF: T073 | docs/memo/design-live-caption.md

## C012|Apple Translation Framework

ID: C012 | Tags: #translation #apple #macos14

Q: 如何使用 Apple 原生翻译 API？
A: Translation.framework (macOS 14.4+):

- `TranslationSession.Configuration(source:target:)` 配置语言对
- `session.translate(text)` 翻译文本，返回 `response.targetText`
- SwiftUI: `.translationTask(config) { session in ... }`
- 首次使用需下载语言包(100-300MB/语言对)
- 完全本地运行，零 API 成本
  REF: T073 | docs/memo/design-live-caption.md

## C013|Apple Live Captions 无公开 API

ID: C013 | Tags: #accessibility #livecaptions #research

Q: 能否复用 Apple Live Captions 的字幕结果？
A: 不能。Apple Live Captions 无公开 API，只能通过系统设置开关，无法:

- 读取生成的字幕文本
- 监听字幕事件
- 自定义翻译语言
  必须自建 pipeline: ScreenCaptureKit → SFSpeech → Translation
  REF: T073 | docs/memo/design-live-caption.md

## C014|macOS 26 TCC 崩溃与代码签名

ID: C014 | Tags: #tcc #codesign #macos26 #screencapturekit

Q: macOS 26 上 ScreenCaptureKit 调用导致 `__TCC_CRASHING_DUE_TO_PRIVACY_VIOLATION__` 崩溃如何解决？
A: 三个关键条件缺一不可:

1. **必须使用 .app bundle** - `swift run`/plain exe 无法在系统设置显示(Apple 确认 bug)
2. **必须用开发者证书签名** - adhoc 签名(`--sign -`)会阻止 TCC 工作(参考 TN3127)
3. **必须用 `open` 启动** - 直接运行 exe 不被识别为完整 bundle

开发流程:

```bash
# 1. Swift Bundler 创建 .app
swift-bundler bundle
# 2. 开发者证书签名
codesign --force --deep --sign "Apple Development" --identifier "app.id" .build/bundler/App.app
# 3. open 启动 + log stream 看日志
open .build/bundler/App.app
log stream --predicate 'process == "App"' --style compact
```

REF: T075 | dev.sh; https://developer.apple.com/forums/thread/807898; TN3127

## C015|词典双轨策略

ID: C015 | Tags: #dictionary #asr #speechanalyzer

Q: 如何同时利用 contextualStrings 和预编译 LM？
A: 双轨并行策略:

1. **contextualStrings** - 实时生效，只需单词列表，适合 SpeechTranscriber
2. **预编译 LM** - 后台准备，需要短语+发音，适合 DictationTranscriber
3. 用户纠正时自动收集整句作为训练短语(每词条最多 20 个)
4. SpeechTranscriber 只支持前者，DictationTranscriber 两者都支持
   REF: T061,T062 | DictionaryInjector.swift; SpeechAnalyzerProvider.swift

## C016|多转录模型架构

ID: C016 | Tags: #architecture #transcription #models

Q: 如何支持多个转录模型切换？
A: 三层架构:

- **TranscriptionModelDefinition** - 模型元数据(type/source/capabilities/supportsStreaming)
- **TranscriptionModelUserSettings** - 用户配置(selectedModelId/locale/enablePrecompiledLM)
- **TranscriptionModelManager** - 状态管理(settings/downloadStates/roleAssignment)
- 角色分配: transcriptionModelId(主转录) vs liveCaptionModelId(实时字幕)
- @available 存储属性限制: 用 `Any?` + computed property 规避
  REF: T066,T067 | Core/Transcription/Models/\*

## C017|UnsafeRawPointer 内存安全

ID: C017 | Tags: #swift #memory #unsafe

Q: bindMemory vs assumingMemoryBound 如何选择？
A: 根据内存类型绑定历史:

- **bindMemory** - 改变内存的类型绑定，要求对齐+无先前绑定
- **assumingMemoryBound** - 假定已绑定为目标类型，不做检查
- CMBlockBuffer 返回的 Int8 指针实际是其他类型(Float32/Int16)，用 `assumingMemoryBound` 更安全
- 典型场景: 音频 buffer 转换 CMSampleBuffer → AVAudioPCMBuffer
  REF: T069 | SystemAudioCaptureService.swift#convertToPCMBuffer

## C018|实时字幕增量计算

ID: C018 | Tags: #live-caption #speechanalyzer #algorithm

Q: SpeechAnalyzer 如何计算新增段落？
A: 使用 finalizedText 长度差值:

1. `finalizedText` - 已确认文本（累积）
2. `volatileText` - 实时预览（覆盖式更新）
3. 新段落 = `finalizedText[lastLength...]`
4. 无需手动分段，SpeechAnalyzer 自动产生多个 isFinal
   REF: T068 | LiveCaptionManager.swift

## C019|双层缓冲区模型

ID: C019 | Tags: #live-caption #buffer #stability

Q: 如何解决实时字幕 volatile 文本导致的跳动问题？
A: 双层缓冲区模型，volatile 不参与分行:

1. `frozenLines` - 已冻结行，内容永不改变
2. `currentLineBuffer` - 当前行的 finalized 部分
3. `volatileTail` - volatile 文本，仅做显示追加
4. `displayWindowStart` - 单向滚动锁，只增不减
5. 冻结条件: count>=65 或 (count>=40 且有句号)
6. 切分优先级: 句号 > 逗号 > 空格 > 强制
7. displayText = frozenLines[windowStart...] + (currentLineBuffer + volatileTail)
   REF: T071 | CaptionLineBuffer.swift#双层缓冲区
