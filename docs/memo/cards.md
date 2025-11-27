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
A: 底层静默保存历史(20-50条)替代当前剪贴板；用户可选开关；过滤敏感+限制长度
REF: T028 | docs/roadmap.md#Context-Awareness