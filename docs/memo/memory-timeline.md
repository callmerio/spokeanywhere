# MM 记忆时间线

维护者: MM | 项目: SpokenAnyWhere | 更新: 2025-11-27

## Learns (Latest at top)

- [T030] System Prompt 要明确指导 LLM 如何利用上下文，否则 LLM 可能忽略剪贴板历史
- [T029] ClipboardHistoryService 使用定时器轮询剪贴板变化，过滤敏感信息（密码/API Key/长密钥）
- [T028] 剪贴板历史比当前剪贴板更有价值：可提供专业术语/人名/项目名上下文
- [T027] SwiftUI overlay 在 clipShape 之后才能显示超出边界的效果
- [T026] CGEvent tap 会被系统因超时自动禁用，需要监听 tapDisabledByTimeout 事件
- [T025] Keychain 访问可以用内存缓存优化，避免开发阶段重复授权弹窗
- [T024] AngularGradient 配合 rotationEffect 可以实现跑马灯效果
- [T023] ForEach + ZStack + rotationEffect 可以实现彩色点旋转动画

## 智能索引

技术栈: #swiftui(T023,T024,T027) #cgevent(T026) #keychain(T025) #clipboard(T028)
架构模式: #hud-animation(@C001:T023,T024,T027) #event-handling(@C002:T026) #security(@C003:T025) #context(@C004:T028)
任务类型: #ui-optimization(T023,T024,T027) #bug-fix(T026) #performance(T025) #design(T028)

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
- PLAN: 底层静默保存历史(20-50条) + 替代当前剪贴板选项 + 用户可选开关
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