# SpokenAnyWhere 技术架构设计文档 v2.0

## 1. 架构概览 (Architecture Overview)

采用 **MVVM (Model-View-ViewModel)** 架构，结合 **Service Layer** 模式解耦业务逻辑。
核心原则：
- **Unidirectional Data Flow**: 数据单向流动，状态（State）驱动 UI。
- **Protocol Oriented**: 听写引擎、AI 提供商均通过协议定义，便于扩展。
- **Crash-Safe**: 音频数据优先落盘，非易失性优先。
- **Latency First**: 优先展示流式中间结果，异步处理 AI 优化。

---

## 2. 技术栈选型 (Tech Stack)

| 模块 | 技术选型 | 说明 |
| --- | --- | --- |
| **OS Target** | macOS 14.0+ (Sonoma) | 利用最新的 SwiftUI API 和 SwiftData |
| **Distribution** | **Notarized DMG** (Non-Sandboxed) | 需绕过沙盒以使用 AX API 模拟键盘输入 |
| **Language** | Swift 5.9+ | 强类型、并发安全 (Swift Concurrency) |
| **UI Framework** | SwiftUI + AppKit | 主界面用 SwiftUI，悬浮窗需 AppKit (`NSPanel`) 微调 |
| **Data Persistence** | **SwiftData** | 存储历史记录、Prompt 规则、Provider 配置 |
| **Key Storage** | Keychain Services | 安全存储 API Key |
| **Audio** | AVFoundation | `AVAudioEngine` 用于录制与处理 |
| **HotKeys** | `HotKey` (Library) | 封装 Carbon Global Hotkeys |
| **Text Insertion** | Accessibility API (AX) | 模拟键盘输入 / 粘贴 |
| **Local Model** | Apple Speech (SFSpeech) | 系统原生，零开销 |
| **Local Whisper** | `WhisperKit` (Argmax) | 针对 Apple Silicon 优化的 CoreML 版本 |

---

## 3. 核心模块设计 (Core Modules)

### 3.1 音频录制服务 (AudioRecorderService)
* **职责**：管理麦克风生命周期、音频流数据、格式转换。
* **关键特性 [NF-8]**：
  * **Tap Node Strategy**: 在 `AVAudioEngine` 的 inputNode 安装 Tap。
  * **Format Conversion**: 统一转换为 16kHz Mono PCM (Whisper 标准)，同时保留原始高保真备份。
  * **Stream-to-Disk**: 在 Buffer 回调中，直接将音频流写入临时目录下的 `.caf` 文件。
  * **Crash Recovery**: 初始化时扫描 `NSTemporaryDirectory`，发现未归档文件即触发恢复流程。

### 3.2 声音活动检测 (VADService) [新增]
* **职责**：检测语音开始与结束，实现“自动停止”和“实时字幕”触发。
* **实现**：
  * 方案 A (MVP): 基于振幅阈值 (Amplitude Threshold) + 持续静音时长 (Silence Duration)。
  * 方案 B (v1.1): 集成轻量级 VAD 模型 (如 Silero VAD ONNX)。

### 3.3 听写引擎层 (Transcription Layer)
定义统一协议 `TranscriptionProvider`：
```swift
protocol TranscriptionProvider {
    var id: String { get }
    var displayName: String { get }
    var isAvailable: Bool { get } // 模型是否就绪
    var requiresDownload: Bool { get } // 是否需要下载资源
    
    /// 配置音频引擎（如安装 Tap）
    func configure(audioEngine: AVAudioEngine) throws
    
    /// 开始转写，返回包含中间结果的流
    /// TranscriptionResult 包含：text, isFinal, confidence
    func startTranscription() async throws -> AsyncStream<TranscriptionResult>
    
    func stop()
}
```
* **实现类**：
  * `AppleSpeechProvider`: 封装 `SFSpeechRecognizer`。
  * `WhisperLocalProvider`: 封装 `WhisperKit`。
  * `RemoteWhisperProvider`: 调用 OpenAI 格式 API。

### 3.4 上下文感知模块 (ContextAwarenessService)
* **职责**：由 [F-54] 和 [F-56] 驱动。
* **实现机制**：
  * 监听 `NSWorkspace.didActivateApplicationNotification`。
  * 获取 `frontmostApplication.bundleIdentifier` 和 `icon`。
  * **PromptEngine**：接收 App ID，查询 SwiftData 中的 `AppRule`，拼接最终 Prompt。
    * `FinalPrompt = GlobalPrompt + (AppRules[CurrentAppID] ?? "")`

### 3.5 悬浮胶囊管理器 (FloatingHUDManager)
* **定位策略**：
  * 默认：屏幕顶部中央 (Dynamic Island 风格)。
  * 可选：跟随当前 App 光标位置。
* **实现方案**：
  * 子类化 `NSPanel` (`.level = .floating`)。
  * **State Binding**: 注入 `RecordingViewModel`。
  * **Data Flow**: 接收 `TranscriptionProvider` 的 `AsyncStream`，实时展示灰色的“中间结果”。

### 3.6 AI 处理管线 (AIPipeline)
* **职责**：串联 听写 -> Prompt 组装 -> LLM 调用。
* **逻辑**：
  1. 接收 `rawText` (Complete)。
  2. 调用 `ContextAwarenessService` 获取当前 `contextPrompt`。
  3. 调用 `LLMService` (封装 Gemini/OpenAI API)。
  4. **Retry Policy**: 遇到 Rate Limit (429) 或 5xx 错误，执行指数退避重试 (最多 3 次)。
  5. **Fallback**: 最终失败 -> 返回 `rawText` 并标记 `isFallback = true`。

### 3.7 模型管理服务 (ModelManagerService) [新增]
* **职责**：管理本地模型文件的下载与存储。
* **功能**：
  * 检查本地模型完整性。
  * 执行下载任务 (URLSession)，发布进度更新。
  * 存储路径：`~/Library/Application Support/SpokenAnyWhere/Models/`。

---

## 4. 数据流 (Data Flow)

### 4.1 实时听写链路
1. **User Action**: 按下 `⌥ + R` (或 VAD 触发)。
2. **HotKeyManager**: 触发 `RecordingSession.start()`。
3. **UI Update**: 显示 **Floating Capsule** (State: `.recording`)，显示当前 App 图标。
4. **Audio Service**:
   * 开启 Mic，写入 `temp_{uuid}.caf`。
   * **VADService**: 开始监测静音。
   * **TranscriptionProvider**: 开始流式转写。
5. **Streaming Loop**: 
   * 引擎输出 `Partial Text` -> 胶囊实时更新 (灰字)。
6. **User Action / VAD**: 停止录音。
7. **Transcription**: 产出 `Final Raw Text`。
8. **AI Processing**:
   * UI 变更为 `.processing` (呼吸灯)。
   * **AIPipeline**: 组装 Prompt -> 调用 LLM (带重试)。
9. **Output**:
   * 成功：UI 变更为 `.success` (打钩)。
   * **OutputService**: 检查 AX 权限 -> 插入文本到当前 App。
   * **HistoryService**: 保存记录到 SwiftData。

### 4.2 异常处理链路
* **Case: App Crash** -> 重启扫描 Temp 目录 -> 恢复录音。
* **Case: Network Fail** -> Retry x3 -> Fallback to Raw Text -> UI 红色警告。
* **Case: No AX Permission** -> Fallback to Clipboard -> UI 提示“已复制”。

---

## 5. 数据模型 (Data Models)

### 5.1 HistoryItem (SwiftData)
```swift
@Model
class HistoryItem {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var rawText: String
    var processedText: String?
    var audioPath: String? // 本地相对路径
    var appBundleId: String? // 来源 App
    var tags: [String] // 需要 Transformable 或关联表，这里简化
    
    @Relationship(deleteRule: .nullify) 
    var providerConfig: AIProviderConfig?
}
```

### 5.2 AppRule (SwiftData)
```swift
@Model
class AppRule {
    @Attribute(.unique) var bundleId: String
    var appName: String
    var extraPrompt: String
    var isEnabled: Bool
}
```

### 5.3 AIProviderConfig (SwiftData) [新增]
```swift
@Model
class AIProviderConfig {
    @Attribute(.unique) var providerId: String // e.g., "gemini", "openai"
    var displayName: String
    var apiKeyReference: String // Keychain Key Identifier
    var baseURL: String?
    var defaultModelId: String // e.g., "gemini-2.5-flash"
    var isDefault: Bool
}
```

---

## 6. 项目目录结构规划

```
SpokenAnyWhere/
├── App/
│   ├── SpokenAnyWhereApp.swift
│   └── AppDelegate.swift (处理 MenuBar/Dock/LifeCycle)
├── Core/
│   ├── Audio/ (Recorder, VAD, FileHandler)
│   ├── Transcription/ (Protocols, Apple, Whisper)
│   └── LLM/ (Gemini, OpenAI, RetryLogic)
├── Services/
│   ├── ContextService.swift
│   ├── HotKeyService.swift
│   ├── OutputService.swift (AX Wrappers)
│   ├── PermissionService.swift (AX/Mic Check)
│   └── ModelManagerService.swift (Downloads)
├── UI/
│   ├── Settings/
│   ├── HUD/ (Floating Capsule)
│   └── MenuBar/
└── Resources/
    └── LocalModels/
```
