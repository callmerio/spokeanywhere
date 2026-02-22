# SpokenAnyWhere 快速导航索引

**版本**: 1.0
**更新时间**: 2026-02-22

本文档提供功能到实现位置的快速映射，帮助开发者快速定位代码。

---

## 一、按功能查找

### 语音输入

| 功能 | 入口文件 | 关键类型 | 说明 |
|------|---------|---------|------|
| 录音控制 | Services/RecordingController.swift | RecordingController | 录音生命周期管理 |
| 音频捕获 | Core/Audio/AudioRecorderService.swift | AudioRecorderService | AVAudioEngine 封装 |
| 语音识别 | Core/Transcription/TranscriptionManager.swift | TranscriptionManager | ASR 引擎管理 |
| Apple STT | Core/Transcription/Providers/SFSpeechProvider.swift | SFSpeechProvider | SFSpeechRecognizer 适配器 |
| Speech Analyzer | Core/Transcription/Providers/SpeechAnalyzerProvider.swift | SpeechAnalyzerProvider | SFSpeechAnalyzer 适配器 |

**调用链**:
```
HotKeyService → VoiceHandler → RecordingController → AudioRecorderService → TranscriptionManager
```

### AI 对话

| 功能 | 入口文件 | 关键类型 | 说明 |
|------|---------|---------|------|
| Quick Ask 面板 | Services/QuickAskService.swift | QuickAskService | 快速提问编排 |
| LLM 集成 | Core/LLM/LLMPipeline.swift | LLMPipeline | AI 模型管道 |
| OpenAI 兼容 | Core/LLM/OpenAICompatibleProvider.swift | OpenAICompatibleProvider | OpenAI API 适配器 |
| 对话状态 | Core/QuickAsk/QuickAskState.swift | QuickAskState | 对话状态管理 |
| 对话 UI | UI/QuickAsk/AnswerPanelView.swift | AnswerPanelView | 对话面板视图 |

**调用链**:
```
HotKeyService → QuickAskHandler → QuickAskService → LLMPipeline → OpenAICompatibleProvider
```

### 截图管理

| 功能 | 入口文件 | 关键类型 | 说明 |
|------|---------|---------|------|
| 截图管理器 | Core/Screenshot/ScreenshotManager.swift | ScreenshotManager | 截图生命周期 |
| 截图项 | Core/Screenshot/ScreenshotItem.swift | ScreenshotItem | 截图数据模型 |
| 区域选择 | UI/Screenshot/RegionSelectionWindow.swift | RegionSelectionWindow | 选区 UI |
| 截图窗口 | UI/Screenshot/ScreenshotWindow.swift | ScreenshotWindow | 浮动截图窗口 |
| 屏幕捕获 | Core/Attachment/ScreenCaptureService.swift | ScreenCaptureService | ScreenCaptureKit 封装 |
| AI 增强 | Services/ImageEnhancementService.swift | ImageEnhancementService | 图片超分辨率 |

**调用链**:
```
HotKeyService → ScreenshotHandler → ScreenshotManager → ScreenCaptureService
```

### 实时字幕

| 功能 | 入口文件 | 关键类型 | 说明 |
|------|---------|---------|------|
| 字幕管理器 | Core/LiveCaption/LiveCaptionManager.swift | LiveCaptionManager | 字幕生命周期 |
| 字幕转录 | Core/LiveCaption/LiveCaptionTranscriber.swift | LiveCaptionTranscriber | 实时转录 |
| 字幕稳定器 | Core/LiveCaption/CaptionStabilizer.swift | CaptionStabilizer | 字幕平滑 |
| 系统音频捕获 | Core/LiveCaption/SystemAudioCaptureService.swift | SystemAudioCaptureService | 系统音频 |
| 应用音频捕获 | Core/LiveCaption/AppAudioCaptureService.swift | AppAudioCaptureService | 应用音频 |
| 字幕 UI | UI/LiveCaption/LiveCaptionView.swift | LiveCaptionView | 字幕显示 |

**调用链**:
```
HotKeyService → CaptionHandler → LiveCaptionManager → SystemAudioCaptureService → LiveCaptionTranscriber
```

### 文本选择工具栏

| 功能 | 入口文件 | 关键类型 | 说明 |
|------|---------|---------|------|
| 选择监控 | Services/SelectionMonitorService.swift | SelectionMonitorService | 文本选择检测 |
| 工具栏管理 | Services/SelectionToolbarManager.swift | SelectionToolbarManager | 工具栏生命周期 |
| 工具栏配置 | Services/ToolbarConfigService.swift | ToolbarConfigService | 工具栏配置 |
| 选择动作 | Services/SelectionActionService.swift | SelectionActionService | 动作执行 |
| 工具栏 UI | UI/SelectionToolbar/SelectionToolbarView.swift | SelectionToolbarView | 工具栏视图 |

**调用链**:
```
SelectionMonitorService → SelectionToolbarManager → SelectionActionService
```

### 词典服务

| 功能 | 入口文件 | 关键类型 | 说明 |
|------|---------|---------|------|
| 统一词典 | Core/Dictionary/UnifiedDictionaryService.swift | UnifiedDictionaryService | 词典服务聚合 |
| 本地词典 | Core/Dictionary/Providers/LocalDictionaryService.swift | LocalDictionaryService | 系统词典 |
| 远程词典 | Core/Dictionary/Providers/RemoteProvider.swift | RemoteProvider | API 词典 |
| 词典注入 | Core/Dictionary/DictionaryInjector.swift | DictionaryInjector | ASR 词典注入 |
| 词典面板 | UI/Dictionary/DictionaryPanelView.swift | DictionaryPanelView | 词典查询 UI |

### 热键系统

| 功能 | 入口文件 | 关键类型 | 说明 |
|------|---------|---------|------|
| 热键服务 | Services/HotKeyService.swift | HotKeyService | 全局热键管理 |
| 热键注册 | Services/HotKey/HotKeyRegistry.swift | HotKeyRegistry | 热键注册表 |
| 热键监听 | Services/HotKey/HotKeyListener.swift | HotKeyListener | 系统热键监听 |
| 语音处理器 | Services/HotKey/Handlers/VoiceHandler.swift | VoiceHandler | 语音输入热键 |
| 字幕处理器 | Services/HotKey/Handlers/CaptionHandler.swift | CaptionHandler | 字幕热键 |
| Quick Ask 处理器 | Services/HotKey/Handlers/QuickAskHandler.swift | QuickAskHandler | Quick Ask 热键 |
| 截图处理器 | Services/HotKey/Handlers/ScreenshotHandler.swift | ScreenshotHandler | 截图热键 |

---

## 二、按文件类型查找

### 核心业务逻辑 (Core/)

```
Core/
├── Audio/                     # 音频捕获
│   ├── AudioRecorderService.swift      # 主音频服务
│   ├── AudioCallbackRouter.swift       # 回调路由
│   └── AudioRecoveryPolicy.swift       # 恢复策略
├── Transcription/             # 语音识别
│   ├── TranscriptionManager.swift      # 转录管理器
│   ├── Providers/
│   │   ├── SFSpeechProvider.swift      # Apple STT
│   │   └── SpeechAnalyzerProvider.swift # Speech Analyzer
│   └── Models/
│       ├── TranscriptionModelManager.swift
│       └── TranscriptionModelDefinition.swift
├── LLM/                       # AI 模型
│   ├── LLMPipeline.swift               # LLM 管道
│   ├── LLMProvider.swift               # 提供商接口
│   └── OpenAICompatibleProvider.swift  # OpenAI 适配器
├── Screenshot/                # 截图
│   ├── ScreenshotManager.swift         # 截图管理器
│   ├── ScreenshotItem.swift            # 截图数据模型
│   └── ImageUpscalerModelManager.swift # AI 超分
├── LiveCaption/               # 实时字幕
│   ├── LiveCaptionManager.swift        # 字幕管理器
│   ├── LiveCaptionTranscriber.swift    # 实时转录
│   ├── CaptionStabilizer.swift         # 字幕稳定
│   └── SystemAudioCaptureService.swift # 系统音频
└── Dictionary/                # 词典
    ├── UnifiedDictionaryService.swift  # 统一服务
    ├── Providers/
    │   ├── LocalDictionaryService.swift
    │   └── RemoteProvider.swift
    └── Models/
        └── DictionaryEntry.swift
```

### 全局服务 (Services/)

```
Services/
├── ServiceContainer.swift              # 依赖注入容器
├── HotKeyService.swift                 # 全局热键
├── RecordingController.swift           # 录音控制
├── QuickAskService.swift               # Quick Ask 编排
├── SelectionMonitorService.swift       # 文本选择监控
├── SelectionToolbarManager.swift       # 工具栏管理
├── AppSettings.swift                   # 应用设置
├── HistoryManager.swift                # 历史记录
├── ImageEnhancementService.swift       # 图片增强
└── HotKey/                             # 热键子系统
    ├── HotKeyRegistry.swift
    ├── HotKeyListener.swift
    └── Handlers/
        ├── VoiceHandler.swift
        ├── CaptionHandler.swift
        ├── QuickAskHandler.swift
        └── ScreenshotHandler.swift
```

### 用户界面 (UI/)

```
UI/
├── QuickAsk/                           # AI 对话
│   ├── AnswerPanelView.swift           # 对话面板
│   └── MessageBubbleView.swift         # 消息气泡
├── HUD/                                # 全局浮窗
│   └── QuickAskInputView.swift         # 输入框
├── LiveCaption/                        # 实时字幕
│   ├── LiveCaptionView.swift           # 字幕显示
│   ├── LiveCaptionWindow.swift         # 字幕窗口
│   └── CaptionItemView.swift           # 字幕项
├── Screenshot/                         # 截图
│   ├── RegionSelectionWindow.swift     # 选区窗口
│   ├── ScreenshotWindow.swift          # 截图窗口
│   ├── ScreenshotContentView.swift     # 内容视图
│   └── ScreenshotToolbarView.swift     # 工具栏
├── Settings/                           # 设置
│   ├── SettingsView.swift              # 设置主界面
│   ├── GeneralSettingsContent.swift    # 通用设置
│   ├── ShortcutsSettingsContent.swift  # 快捷键设置
│   └── AISettingsContent.swift         # AI 设置
├── Components/                         # 可复用组件
│   ├── AttachmentThumbnailView.swift
│   ├── DictionarySelectableText.swift
│   └── HoverButtons.swift
└── Theme/                              # 设计系统
    └── DesignTokens.swift              # 唯一样式来源
```

---

## 三、按数据模型查找

### SwiftData 持久化模型

| 模型 | 文件 | 用途 |
|------|------|------|
| HistoryItem | Core/DataModels.swift | 历史记录 |
| AppRule | Core/DataModels.swift | 应用规则 |
| AIProviderConfig | Core/DataModels.swift | AI 提供商配置 |

### 核心数据模型

| 模型 | 文件 | 用途 |
|------|------|------|
| ScreenshotItem | Core/Screenshot/ScreenshotItem.swift | 截图项 |
| Attachment | Core/Attachment/Attachment.swift | 附件 |
| DictionaryEntry | Core/Dictionary/Models/DictionaryEntry.swift | 词典条目 |
| QuickAskState | Core/QuickAsk/QuickAskState.swift | Quick Ask 状态 |
| MessagePanelState | Core/MessagePanel/MessagePanelState.swift | 消息面板状态 |
| RecordingState | Core/RecordingState.swift | 录音状态 |

---

## 四、按协议查找

### ServiceContainer 协议

| 协议 | 实现 | 用途 |
|------|------|------|
| AudioCaptureServiceProtocol | AudioRecorderService | 音频捕获 |
| TranscriptionServiceProtocol | TranscriptionManager | 语音识别 |
| LLMServiceProtocol | LLMPipeline | AI 模型 |
| AppSettingsProtocol | AppSettings | 应用设置 |
| HistoryManagerProtocol | HistoryManager | 历史记录 |
| QuickAskServiceProtocol | QuickAskService | Quick Ask |

### 提供商协议

| 协议 | 实现 | 用途 |
|------|------|------|
| TranscriptionProvider | SFSpeechProvider, SpeechAnalyzerProvider | ASR 引擎 |
| LLMProvider | OpenAICompatibleProvider | LLM 提供商 |

---

## 五、常见任务快速定位

### 添加新的 ASR 引擎

1. 创建 `Core/Transcription/Providers/YourProvider.swift`（示例路径，文件需新建）
2. 实现 `TranscriptionProvider` 协议
3. 在 `TranscriptionManager.swift` 中注册
4. 更新 `TranscriptionEngineType` 枚举

**参考**: SFSpeechProvider.swift, SpeechAnalyzerProvider.swift

### 添加新的 LLM 提供商

1. 创建 `Core/LLM/YourProvider.swift`（示例路径，文件需新建）
2. 实现 `LLMProvider` 协议
3. 在 `LLMPipeline.swift` 中注册
4. 更新设置界面

**参考**: OpenAICompatibleProvider.swift

### 添加新的热键功能

1. 创建 `Services/HotKey/Handlers/YourHandler.swift`（示例路径，文件需新建）
2. 实现 `HotKeyHandler` 协议
3. 在 `HotKeyService.swift` 中注册
4. 更新设置界面

**参考**: VoiceHandler.swift, CaptionHandler.swift

### 修改 UI 样式

**唯一样式来源**: `UI/Theme/DesignTokens.swift`

```swift
// ✅ 正确
.foregroundColor(DesignTokens.Colors.textPrimary)
.cornerRadius(DesignTokens.CornerRadius.lg)

// ❌ 禁止
.foregroundColor(Color.white.opacity(0.9))
.cornerRadius(14)
```

### 调试启动流程

**入口**: `App/AppDelegate.swift:43` - `applicationDidFinishLaunching`

12 步启动序列，每步都有日志输出：
```swift
logStep("Step 0: Installing crash logger...")
logStep("Step 1: Checking accessibility permission...")
// ...
```

### 调试热键问题

**入口**: `Services/HotKeyService.swift`

关键方法：
- `registerHotKey()`: 注册热键
- `handleHotKey()`: 处理热键事件
- `HotKeyRegistry`: 热键注册表

### 调试录音问题

**入口**: `Services/RecordingController.swift`

关键方法：
- `startRecording()`: 开始录音
- `stopRecording()`: 停止录音
- `handleRecordingResult()`: 处理录音结果

### 调试 AI 对话问题

**入口**: `Services/QuickAskService.swift`

关键方法：
- `startSession()`: 开始会话
- `sendQuestion()`: 发送问题
- `handleLLMResponse()`: 处理 AI 响应

---

## 六、性能关键路径

### 启动性能

**关键文件**: `App/AppDelegate.swift`

**优化点**:
- Line 92-97: 词典预编译（后台）
- Line 148-152: 截图恢复（异步）

**性能测试**: `Tests/ScreenshotManagerPerformanceTests.swift`

### 录音性能

**关键文件**: `Core/Audio/AudioRecorderService.swift`

**优化点**:
- 音频缓冲区大小
- 采样率配置
- 回调频率

### AI 推理性能

**关键文件**: `Core/LLM/LLMPipeline.swift`

**优化点**:
- 流式响应
- 并发请求控制
- 缓存策略

---

## 七、测试文件定位

### 单元测试

```
Tests/
├── AppSettingsTests.swift              # 应用设置测试
├── ScreenshotManagerPerformanceTests.swift  # 性能测试
└── [其他测试文件...]
```

### 性能基准

```
scripts/perf/
├── run_startup_bench.sh                # 启动性能测试
└── check_startup_regression.sh         # 回归检测

perf/
└── baseline-startup.json               # 性能基线
```

---

## 八、配置文件定位

### 构建配置

| 文件 | 用途 |
|------|------|
| Package.swift | Swift Package Manager 配置 |
| .swiftlint.yml | SwiftLint 配置 |

### CI/CD

| 文件 | 用途 |
|------|------|
| .github/workflows/test.yml | 测试工作流 |
| .github/workflows/perf-startup.yml | 性能测试工作流 |

---

## 九、文档索引

| 文档 | 路径 | 说明 |
|------|------|------|
| 项目架构全景 | ./overview.md | 本文档 |
| 核心模块详解 | ./core-modules.md | Core/ 深度分析 |
| UI 组件体系 | ./ui-components.md | UI/ 组件说明 |
| 设计系统规范 | ../../../docs/style/INDEX.md | DesignTokens 指南 |
| 性能基准测试 | ../performance-benchmarking.md | 性能测试方案 |
| M2 并发告警收敛 | ../m2-final-acceptance.md | Swift 6 合规 |

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-02-22
