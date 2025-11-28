# MM 学习卡片

维护者: MM | 项目: SpokenAnyWhere | 更新: 2025-11-28

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
