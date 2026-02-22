# SpokenAnyWhere 项目架构全景

**版本**: 1.0
**更新时间**: 2026-02-22
**代码规模**: ~51,000 行 Swift 代码

---

## 一、项目概览

SpokenAnyWhere 是一个原生 macOS 生产力应用（macOS 14+），提供语音转文本转录和 AI 驱动的文本处理功能。

**核心能力**:
- 全局热键支持的语音输入
- 实时字幕显示
- 截图 OCR 与标注
- 文本选择工具栏
- AI 对话与文本处理

**技术栈**:
- Swift 5.9+, SwiftUI + AppKit 混合架构
- SwiftData 持久化
- Swift Package Manager
- Swift 6 strict concurrency 合规

---

## 二、架构分层

```
┌─────────────────────────────────────────────────────────┐
│                    App Layer (入口层)                     │
│  SpokenlyApp.swift, AppDelegate.swift                   │
│  - 应用生命周期管理                                        │
│  - 启动序列编排                                           │
│  - ModelContainer 初始化                                 │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                 Services Layer (服务层)                   │
│  全局单例服务，跨功能协调                                   │
│  - HotKeyService: 全局热键管理                            │
│  - SelectionMonitorService: 文本选择监控                  │
│  - QuickAskService: 快速提问面板编排                       │
│  - RecordingController: 录音控制器                        │
│  - ServiceContainer: 轻量级依赖注入                       │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                  Core Layer (核心业务层)                   │
│  按功能域组织的业务逻辑模块                                  │
│  - Audio: 音频捕获与处理                                   │
│  - Transcription: ASR 引擎集成                           │
│  - LLM: AI 模型集成                                      │
│  - Screenshot: 截图捕获与管理                             │
│  - LiveCaption: 实时字幕                                 │
│  - Dictionary: 词典服务                                  │
│  - Attachment: 附件管理                                  │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                    UI Layer (视图层)                      │
│  SwiftUI 视图组件，按功能域组织                             │
│  - QuickAsk: AI 对话面板                                 │
│  - LiveCaption: 字幕显示                                 │
│  - Screenshot: 截图标注 UI                               │
│  - Settings: 设置界面                                    │
│  - Components: 可复用组件                                │
│  - Theme: DesignTokens (设计系统)                        │
└─────────────────────────────────────────────────────────┘
```

---

## 三、目录结构

### App/ - 应用入口
```
App/
├── SpokenlyApp.swift          # SwiftUI App 入口
└── AppDelegate.swift          # AppKit 生命周期管理
```

**职责**:
- 应用启动序列（12 步初始化流程）
- ModelContainer 配置（SwiftData）
- 菜单栏图标管理
- 权限检查与引导

### Core/ - 核心业务逻辑
```
Core/
├── Audio/                     # 音频捕获与处理
│   ├── AudioRecorderService.swift
│   ├── AudioCallbackRouter.swift
│   └── AudioRecoveryPolicy.swift
├── Transcription/             # 语音识别
│   ├── Providers/             # ASR 引擎适配器
│   │   ├── SFSpeechProvider.swift
│   │   └── SpeechAnalyzerProvider.swift
│   ├── Models/                # 模型管理
│   └── TranscriptionManager.swift
├── LLM/                       # AI 模型集成
│   ├── LLMProvider.swift
│   ├── LLMPipeline.swift
│   └── OpenAICompatibleProvider.swift
├── Screenshot/                # 截图管理
│   ├── ScreenshotManager.swift
│   ├── ScreenshotItem.swift
│   └── ImageUpscalerModelManager.swift
├── LiveCaption/               # 实时字幕
│   ├── LiveCaptionManager.swift
│   ├── CaptionStabilizer.swift
│   └── SystemAudioCaptureService.swift
├── Dictionary/                # 词典服务
│   ├── Models/
│   ├── Providers/
│   └── UnifiedDictionaryService.swift
├── Attachment/                # 附件管理
│   ├── AttachmentManager.swift
│   └── ScreenCaptureService.swift
└── [其他功能域...]
```

### Services/ - 全局服务
```
Services/
├── ServiceContainer.swift     # 依赖注入容器
├── HotKeyService.swift        # 全局热键
├── SelectionMonitorService.swift  # 文本选择监控
├── QuickAskService.swift      # 快速提问编排
├── RecordingController.swift  # 录音控制
├── AppSettings.swift          # 用户设置
├── HistoryManager.swift       # 历史记录
└── HotKey/                    # 热键子系统
    ├── HotKeyRegistry.swift
    └── Handlers/              # 热键处理器
```

### UI/ - 用户界面
```
UI/
├── QuickAsk/                  # AI 对话面板
├── LiveCaption/               # 字幕显示
├── Screenshot/                # 截图标注
├── Settings/                  # 设置界面
├── Components/                # 可复用组件
├── Theme/                     # 设计系统
│   └── DesignTokens.swift     # 唯一样式来源
└── [其他 UI 模块...]
```

---

## 四、关键架构模式

### 4.1 Service-Oriented Architecture

**ServiceContainer** 提供轻量级依赖注入：

```swift
// 获取服务
let audio = ServiceContainer.shared.audioCapture

// SwiftUI 中使用
@Environment(\.services) var services

// 测试时注入 Mock
ServiceContainer.shared.register(audioCapture: MockAudioService())
```

**核心服务协议**:
- `AudioCaptureServiceProtocol`: 音频捕获
- `TranscriptionServiceProtocol`: 语音识别
- `LLMServiceProtocol`: AI 模型
- `AppSettingsProtocol`: 应用设置
- `HistoryManagerProtocol`: 历史记录
- `QuickAskServiceProtocol`: 快速提问

### 4.2 SwiftUI + AppKit 混合

- **SwiftUI**: 主要 UI 框架，用于设置界面、对话面板等
- **AppKit**: 用于需要精确控制的场景
  - NSPanel: 浮动窗口（字幕、截图）
  - NSWindow: 设置窗口
  - NSStatusItem: 菜单栏图标

### 4.3 SwiftData 持久化

**ModelContainer** 在 AppDelegate 中初始化：

```swift
static let sharedModelContainer: ModelContainer = {
    let schema = Schema([HistoryItem.self, AppRule.self, AIProviderConfig.self])
    // 专属路径: ~/Library/Application Support/Spoke/Data/
    // ...
}()
```

**持久化模型**:
- `HistoryItem`: 历史记录
- `AppRule`: 应用规则
- `AIProviderConfig`: AI 提供商配置

### 4.4 Swift 6 Concurrency

项目符合 Swift 6 strict concurrency：
- 0 warnings (48 个并发告警站点已清除)
- @MainActor 隔离
- Sendable 类型传播
- Task.detached 后台任务

**当前状态**: **Conditional Go**
- ✅ 代码可运行 (0 warnings, 129/129 tests)
- ⚠️ 质量门禁需补齐 (Build/Test/Sanitizer 完整，Concurrency gate 待补齐)
- ⚠️ 架构演进需收敛 (单例密度、UI 直连、双通道耦合)

**Full Go 触发条件**: 完成 QG-W1-1/W1-2 (并发门禁硬阻断)

详见: [风险评估与改进建议](./risks-and-recommendations.md)

---

## 五、启动流程

AppDelegate.applicationDidFinishLaunching 执行 12 步初始化：

1. **Step 0**: 安装崩溃日志记录器
2. **Step 1**: 检查辅助功能权限
3. **Step 2**: 设置状态栏图标
4. **Step 3**: 启动剪贴板服务
5. **Step 4**: 启动录音控制器
6. **Step 5**: 配置 HistoryManager
7. **Step 6**: 执行历史清理
8. **Step 6.1**: 清理孤立音频文件
9. **Step 6.5**: 词典预编译（后台）
10. **Step 7**: 启动热键服务
11. **Step 8**: 启动选择监控服务
12. **Step 9**: 恢复 Pinned 截图（异步）

**性能优化**:
- 词典预编译：Task.detached(priority: .background)
- 截图恢复：Task(priority: .utility) + 分帧恢复

---

## 六、数据流

### 6.1 语音输入流程

```
用户按下热键
    ↓
HotKeyService 触发 VoiceHandler
    ↓
RecordingController.startRecording()
    ↓
AudioRecorderService 捕获音频
    ↓
TranscriptionManager 转录
    ↓
LLMPipeline 处理（可选）
    ↓
HistoryManager 保存
    ↓
InputService 输入到活跃应用
```

### 6.2 Quick Ask 流程

```
用户按下 Quick Ask 热键
    ↓
QuickAskService.startSession()
    ↓
显示 QuickAskPanel (NSPanel)
    ↓
用户输入问题（语音/文本）
    ↓
LLMPipeline.chat()
    ↓
流式响应显示
    ↓
用户可继续对话或关闭
```

### 6.3 截图流程

```
用户按下截图热键
    ↓
ScreenshotManager.captureRegion()
    ↓
显示 RegionSelectionWindow
    ↓
用户选择区域
    ↓
ScreenCaptureService 捕获
    ↓
保存到 ~/Library/Application Support/Spoke/Screenshots/
    ↓
创建 ScreenshotWindow (NSPanel)
    ↓
用户可标注、Pin、Lock、Mark
```

---

## 七、关键技术决策

### 7.1 为什么使用 ServiceContainer？

- **轻量级**: 相比完整 DI 框架，代码量小
- **可测试**: 支持 Mock 注入
- **类型安全**: 协议约束
- **SwiftUI 友好**: Environment 集成

### 7.2 为什么混合 SwiftUI + AppKit？

- **SwiftUI**: 快速开发，声明式 UI
- **AppKit**: 精确控制（NSPanel 浮动行为、窗口层级）
- **渐进迁移**: 保留 AppKit 能力，逐步 SwiftUI 化

### 7.3 为什么使用 NSPanel 而非 NSWindow？

- **浮动行为**: 始终在最前
- **不抢焦点**: 不影响用户当前工作流
- **跨 Space**: 可配置是否跟随 Space 切换

---

## 八、性能特征

### 8.1 启动性能

- **冷启动**: ~33s (clean build)
- **热启动**: <1s
- **关键优化**:
  - 异步截图恢复（Task.detached）
  - 后台词典预编译
  - 分帧窗口恢复（await Task.yield()）

### 8.2 内存占用

- **基线**: ~50MB
- **录音中**: +10-20MB
- **AI 处理**: +50-100MB（取决于模型）

### 8.3 并发模型

- **主线程**: UI 更新、用户交互
- **后台线程**: 文件 I/O、网络请求、AI 推理
- **隔离策略**: @MainActor + Sendable

---

## 九、扩展点

### 9.1 添加新的 ASR 引擎

1. 实现 `TranscriptionProvider` 协议
2. 在 `TranscriptionManager` 中注册
3. 更新 `TranscriptionEngineType` 枚举

### 9.2 添加新的 LLM 提供商

1. 实现 `LLMProvider` 协议
2. 在 `LLMPipeline` 中注册
3. 更新设置界面

### 9.3 添加新的热键功能

1. 在 `Services/HotKey/Handlers/` 创建新 Handler
2. 实现 `HotKeyHandler` 协议
3. 在 `HotKeyService` 中注册

---

## 十、相关文档

- [风险评估与改进建议](./risks-and-recommendations.md) - 三维风险分析 + 双轴改进 Backlog
- [快速导航索引](./quick-reference.md) - 功能 → 实现位置映射
- [App 层启动序列](./app-layer-startup-sequence.md) - 12 步启动流程
- [App 层回调链](./app-layer-callback-chains.md) - 4 条主链路
- [App 层风险评估](./app-layer-risk-assessment.md) - 9 个风险点
- [设计系统规范](../../../docs/style/INDEX.md) - DesignTokens 使用指南
- [性能基准测试](../performance-benchmarking.md) - 性能测试方案

---

## 十一、快速定位

| 功能 | 入口文件 | 关键类型 |
|------|---------|---------|
| 语音输入 | Services/RecordingController.swift | RecordingController |
| AI 对话 | Services/QuickAskService.swift | QuickAskService |
| 截图管理 | Core/Screenshot/ScreenshotManager.swift | ScreenshotManager |
| 实时字幕 | Core/LiveCaption/LiveCaptionManager.swift | LiveCaptionManager |
| 热键管理 | Services/HotKeyService.swift | HotKeyService |
| 文本选择 | Services/SelectionMonitorService.swift | SelectionMonitorService |
| 历史记录 | Services/HistoryManager.swift | HistoryManager |
| 应用设置 | Services/AppSettings.swift | AppSettings |

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-02-22
**审阅**: codex-1 (架构轴), code (门禁轴), claude-2 (App 层)
