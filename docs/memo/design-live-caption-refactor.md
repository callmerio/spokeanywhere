# 实时字幕重构方案

> 创建时间: 2025-12-04
> 状态: 待实现
> 优先级: 高

## 1. 背景

### 1.1 当前问题

实时字幕功能（Live Caption）存在以下问题：

1. **中英文混合识别失败** - 使用 `SFSpeechRecognizer` 配置 `zh-CN` locale，只能识别中文，英文被转为拼音
2. **分段显示异常** - SFSpeech 的 partial result 是累积式的，导致：
   - 连续音频永远不产生 `isFinal=true`
   - 手动分段时保存了整个累积文本，造成重复内容
3. **无词典支持** - 主转录功能支持用户词典注入，但实时字幕没有复用

### 1.2 目标

1. 支持中英文混合识别（如 "hello bro, my name is 知乎饭"）
2. 自然分段显示，无重复内容
3. 复用用户词典，提高识别准确率
4. 代码复用，减少维护成本

## 2. 技术调研

### 2.1 SFSpeechRecognizer vs SpeechAnalyzer

| 特性           | SFSpeechRecognizer   | SpeechAnalyzer (macOS 26+)              |
| -------------- | -------------------- | --------------------------------------- |
| 多语言         | ❌ 单语言            | ❌ 单 locale（但 zh-Hans 支持混合英文） |
| 离线           | ⚠️ 需配置            | ✅ 完全离线                             |
| Final/Volatile | ❌ 只有累积 partial  | ✅ 自动区分                             |
| 自然分段       | ❌ 需手动实现        | ✅ 自动产生多个 final                   |
| 词典注入       | ✅ contextualStrings | ✅ AnalysisContext.contextualStrings    |
| 性能           | 一般                 | 比 Whisper 快 2.2x (MacStories 实测)    |

> **注意**：SpeechAnalyzer 不是真正的 multilingual，而是单 locale 模式。但 `zh-Hans` locale 天然支持识别混入的英文词汇（与 SFSpeechRecognizer 行为一致）。

### 2.2 SpeechAnalyzer 工作原理

```swift
// SpeechAnalyzer 结果处理（已实现于 SpeechAnalyzerProvider.swift）
private func handleResult(_ result: SpeechTranscriber.Result) async {
    let segmentText = String(result.text.characters)
    let isFinal = result.isFinal

    if isFinal {
        // Final 结果：累积到 finalizedText（一个自然段落）
        self.finalizedText += segmentText
        self.volatileText = ""
    } else {
        // Volatile 结果：更新预览
        self.volatileText = segmentText
    }
}
```

**关键发现**：SpeechAnalyzer 会自动产生多个 `isFinal=true` 的结果，每个代表一个自然的语句段落，无需手动分段。

### 2.3 词典注入机制对比

**当前项目有两种词典注入方式**：

| 方式                    | 使用场景                  | API                               | 预编译    |
| ----------------------- | ------------------------- | --------------------------------- | --------- |
| `SFSpeechLanguageModel` | 主转录 (SFSpeechProvider) | `request.customizedLanguageModel` | ✅ 需要   |
| `contextualStrings`     | LiveCaption (当前)        | `request.contextualStrings`       | ❌ 不需要 |

**SpeechAnalyzer 支持的方式**：

```swift
// 使用 AnalysisContext.contextualStrings（类似当前 LiveCaption 的 contextualStrings）
let context = AnalysisContext()
context.contextualStrings[.general] = DictionaryService.shared.getAllWords()
try await analyzer.setContext(context)
```

> **重要**：SpeechAnalyzer 的 `AnalysisContext.contextualStrings` 与 SFSpeech 的 `request.contextualStrings` 类似，都是轻量级提示，**不需要预编译**。这意味着 LiveCaption 重构后可以直接使用词典词汇，无需调用 `TranscriptionManager.prepareDictionary()`。

## 3. 方案设计

### 3.1 架构变化

```
【改动前】
SystemAudioCapture (ScreenCaptureKit)
    ↓ CMSampleBuffer
    ↓ 转换
LiveCaptionTranscriber (SFSpeechRecognizer)
    ↓ 累积式 partial result
    ↓ ❌ 无词典
    ↓ ❌ 单语言
LiveCaptionManager
    ↓ 手动分段逻辑（有 bug）
UI


【改动后】
SystemAudioCapture (ScreenCaptureKit)
    ↓ CMSampleBuffer → AVAudioPCMBuffer
    ↓
SpeechAnalyzerProvider (复用主转录引擎)
    ↓ ✅ 自动 final/volatile 分离
    ↓ ✅ 词典注入 (AnalysisContext.contextualStrings)
    ↓ ✅ zh-Hans locale 支持中英混合
    ↓ ✅ 离线、高性能
LiveCaptionManager
    ↓ isFinal=true → 新增 segment (自然段落，每次就是增量)
    ↓ isFinal=false → 更新 pendingText (预览)
UI
```

### 3.2 核心改动

| 组件                              | 改动类型 | 说明                                  |
| --------------------------------- | -------- | ------------------------------------- |
| `LiveCaptionTranscriber.swift`    | **删除** | 不再需要，复用 SpeechAnalyzerProvider |
| `SpeechAnalyzerProvider.swift`    | **修改** | 新增词典注入 (AnalysisContext)        |
| `LiveCaptionManager.swift`        | **重写** | 使用 SpeechAnalyzerProvider           |
| `SystemAudioCaptureService.swift` | 修改     | 新增 AVAudioPCMBuffer 输出            |
| `TranscriptionManager.swift`      | 无需修改 | LiveCaption 不使用预编译词典          |

**影响范围分析**：

| 现有功能        | 是否受影响  | 原因                                                 |
| --------------- | ----------- | ---------------------------------------------------- |
| 主转录 (麦克风) | ❌ 不受影响 | 仍使用 AudioRecorderService → SpeechAnalyzerProvider |
| 词典预编译      | ❌ 不受影响 | LiveCaption 使用轻量级 contextualStrings，不走预编译 |
| 后处理纠错      | ❌ 不受影响 | corrections 替换逻辑不变                             |
| LLM 智能纠错    | ❌ 不受影响 | LiveCaption 不走 LLM Pipeline                        |

## 4. 详细实现

### 4.1 SystemAudioCaptureService 修改

**文件**: `spoke/Core/LiveCaption/SystemAudioCaptureService.swift`

当前输出 `CMSampleBuffer`，需要改为或增加 `AVAudioPCMBuffer` 输出：

```swift
// 当前接口
var onAudioBuffer: ((CMSampleBuffer) -> Void)?

// 新增接口
var onPCMBuffer: ((AVAudioPCMBuffer) -> Void)?

// 在 SCStreamOutput 中添加转换逻辑
nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
    guard type == .audio else { return }

    // 转换为 AVAudioPCMBuffer
    if let pcmBuffer = convertToPCMBuffer(sampleBuffer) {
        Task { @MainActor in
            self.onPCMBuffer?(pcmBuffer)
        }
    }
}

// 转换函数（可复用 LiveCaptionTranscriber 中的逻辑）
private func convertToPCMBuffer(_ sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
    // 参考 LiveCaptionTranscriber.swift 中的实现
    // 注意：SpeechAnalyzer 需要特定格式，查询 bestAvailableAudioFormat
}
```

### 4.2 SpeechAnalyzerProvider 词典注入修改

**文件**: `spoke/Core/Transcription/Providers/SpeechAnalyzerProvider.swift`

在 `setupSpeechAnalyzer()` 方法中添加词典注入：

```swift
private func setupSpeechAnalyzer() async throws {
    // ... 现有代码 ...
    
    // Step 6: 创建 SpeechAnalyzer
    let analyzer = SpeechAnalyzer(modules: [transcriber])
    self.analyzer = analyzer
    
    // 🆕 Step 6.5: 注入词典（新增）
    let context = AnalysisContext()
    let dictionaryWords = DictionaryService.shared.getAllWords()
    if !dictionaryWords.isEmpty {
        context.contextualStrings[.general] = dictionaryWords
        try await analyzer.setContext(context)
        logger.info("📚 Injected \(dictionaryWords.count) dictionary words via AnalysisContext")
    }
    
    // ... 后续代码 ...
}
```

### 4.3 LiveCaptionManager 重写

**文件**: `spoke/Core/LiveCaption/LiveCaptionManager.swift`

```swift
import Foundation
import Combine
import OSLog
import AppKit
import AVFoundation

@MainActor
final class LiveCaptionManager: ObservableObject {

    static let shared = LiveCaptionManager()

    private let logger = Logger(subsystem: "com.spokeanywhere", category: "LiveCaption")

    // MARK: - Published Properties

    @Published private(set) var isActive: Bool = false
    @Published private(set) var segments: [CaptionSegment] = []
    @Published private(set) var pendingText: String = ""
    @Published var sourceLanguage: String = "zh-Hans"  // SpeechAnalyzer 使用 zh-Hans

    // MARK: - Dependencies

    /// 复用主转录引擎（直接使用 SpeechAnalyzerProvider，不走 TranscriptionManager）
    private var provider: SpeechAnalyzerProvider?

    /// 系统音频捕获
    private let audioCapture = SystemAudioCaptureService.shared

    // MARK: - Constants

    private let maxSegments = 10000

    // MARK: - Public API

    func start() async throws {
        guard !isActive else { return }
        guard #available(macOS 26.0, *) else {
            throw LiveCaptionError.systemNotSupported
        }

        // 1. 创建 SpeechAnalyzerProvider（词典注入在 Provider 内部完成）
        let speechProvider = SpeechAnalyzerProvider(locale: Locale(identifier: sourceLanguage))

        // 2. 设置结果回调
        speechProvider.onResult = { [weak self] result in
            self?.handleTranscriptionResult(result)
        }

        speechProvider.onError = { [weak self] error in
            self?.logger.error("❌ Transcription error: \(error.localizedDescription)")
        }

        // 3. 准备引擎（包含词典注入）
        try await speechProvider.prepare()
        self.provider = speechProvider

        // 4. 设置音频回调
        audioCapture.onPCMBuffer = { [weak self] buffer in
            do {
                try self?.provider?.process(buffer: buffer)
            } catch {
                self?.logger.error("❌ Process buffer error: \(error.localizedDescription)")
            }
        }

        // 5. 启动音频捕获
        try await audioCapture.startCapture()

        isActive = true
        logger.info("🎬 LiveCaption started with SpeechAnalyzer")
    }

    func stop() async {
        guard isActive else { return }

        // 结束转录
        try? await provider?.finishProcessing()
        provider?.reset()
        provider = nil

        // 停止音频捕获
        await audioCapture.stopCapture()

        isActive = false
        pendingText = ""
        logger.info("🛑 LiveCaption stopped")
    }

    // MARK: - Private

    private func handleTranscriptionResult(_ result: TranscriptionResult) {
        // 更新 pendingText（实时预览）
        pendingText = result.volatileText
        
        // 🔑 关键修正：SpeechAnalyzer 每次 isFinal=true 的 result.text 就是本段增量
        // 不需要用累积的 finalizedText 计算差值
        //
        // SpeechAnalyzerProvider.handleResult() 中：
        // - segmentText = String(result.text.characters)  ← 这就是本次增量
        // - self.finalizedText += segmentText             ← Provider 内部累积
        // - TranscriptionResult.finalizedText = 累积值
        //
        // 但我们需要的是增量，所以这里需要追踪上次的 finalizedText 长度
        
        // 简化方案：利用 SpeechAnalyzerProvider 的特性
        // 每次回调时，如果 finalizedText 比上次长，差值就是新段落
        handleFinalizedTextIncrement(result.finalizedText)
    }
    
    /// 上次的 finalizedText 长度（用于计算增量）
    private var lastFinalizedLength: Int = 0
    
    private func handleFinalizedTextIncrement(_ finalizedText: String) {
        let currentLength = finalizedText.count
        
        // 如果有新增内容
        if currentLength > lastFinalizedLength {
            // 提取新增部分
            let startIndex = finalizedText.index(finalizedText.startIndex, offsetBy: lastFinalizedLength)
            let newText = String(finalizedText[startIndex...])
            
            if !newText.isEmpty {
                let segment = CaptionSegment(
                    originalText: newText,
                    sourceLanguage: sourceLanguage
                )
                addSegment(segment)
            }
            
            lastFinalizedLength = currentLength
        }
    }

    private func addSegment(_ segment: CaptionSegment) {
        segments.append(segment)

        if segments.count > maxSegments {
            segments.removeFirst(segments.count - maxSegments)
        }

        logger.debug("📝 New segment: \(segment.originalText)")
    }
    
    /// 清空历史（需要重置 lastFinalizedLength）
    func clearSegments() {
        segments.removeAll()
        pendingText = ""
        lastFinalizedLength = 0
    }
}
```

### 4.4 TranscriptionResult（无需修改）

当前 `TranscriptionProvider.swift` 已支持 `finalizedText` 和 `volatileText`：

```swift
// 已实现于 spoke/Core/Transcription/TranscriptionProvider.swift:13-53
struct TranscriptionResult {
    let text: String           // 完整文本 = finalizedText + volatileText
    let finalizedText: String  // 已确认文本
    let volatileText: String   // 预览文本
    let type: TranscriptionResultType
    // ...
}
```

### 4.5 删除 LiveCaptionTranscriber

**文件**: `spoke/Core/LiveCaption/LiveCaptionTranscriber.swift`

**操作**: 删除整个文件，不再需要。

### 4.6 可选优化：TranscriptionResult 增加增量字段

如果希望简化 LiveCaptionManager 的增量计算，可以在 `SpeechAnalyzerProvider` 层面直接输出增量：

```swift
// SpeechAnalyzerProvider.swift 可选修改
struct TranscriptionResult {
    // ... 现有字段 ...
    
    /// 本次新增的 finalized 文本（仅 SpeechAnalyzer 有效）
    /// 用于 LiveCaption 直接获取增量，无需自行计算差值
    let incrementalFinalizedText: String?
}

// handleResult 中
let incrementalResult = TranscriptionResult(
    finalizedText: self.finalizedText,
    volatileText: self.volatileText,
    type: .partial,
    incrementalFinalizedText: isFinal ? segmentText : nil  // 🆕 增量
)
```

这样 LiveCaptionManager 可以简化为：
```swift
private func handleTranscriptionResult(_ result: TranscriptionResult) {
    pendingText = result.volatileText
    
    if let newText = result.incrementalFinalizedText, !newText.isEmpty {
        addSegment(CaptionSegment(originalText: newText, sourceLanguage: sourceLanguage))
    }
}
```

## 5. 测试要点

### 5.1 功能测试

- [ ] 启动实时字幕，播放英文视频
- [ ] 启动实时字幕，播放中文视频
- [ ] 启动实时字幕，播放中英混合视频（如技术讲座）
- [ ] 添加词典词汇，验证是否生效
- [ ] 长时间运行（1 小时+），检查内存和性能
- [ ] 展开字幕，检查历史段落是否正确

### 5.2 边界测试

- [ ] 无音频输入时的状态
- [ ] 快速开关字幕
- [ ] 同时使用主转录和实时字幕

## 6. 回滚方案

如果 SpeechAnalyzer 方案出现问题，可以：

1. 保留 `LiveCaptionTranscriber.swift`（暂时注释而非删除）
2. 在 `LiveCaptionManager` 中添加引擎切换逻辑
3. 通过配置项选择使用哪个引擎

## 7. 相关文件清单

```
spoke/
├── Core/
│   ├── LiveCaption/
│   │   ├── LiveCaptionManager.swift      ← 重写
│   │   ├── LiveCaptionTranscriber.swift  ← 删除
│   │   └── SystemAudioCaptureService.swift ← 修改（增加 PCMBuffer 输出）
│   └── Transcription/
│       ├── TranscriptionManager.swift    ← 少量修改
│       ├── TranscriptionProvider.swift   ← 确认 Result 结构
│       └── Providers/
│           └── SpeechAnalyzerProvider.swift ← 确认支持外部音频
└── UI/
    └── LiveCaption/
        └── LiveCaptionView.swift         ← 无需修改（数据绑定不变）
```

## 8. 参考资料

### Apple 官方文档
- [SpeechAnalyzer](https://developer.apple.com/documentation/speech/speechanalyzer)
- [SpeechTranscriber](https://developer.apple.com/documentation/speech/speechtranscriber)
- [AnalysisContext](https://developer.apple.com/documentation/speech/analysiscontext) - 词典注入
- [AnalysisContext.contextualStrings](https://developer.apple.com/documentation/speech/analysiscontext/contextualstrings) - 补充词汇
- [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)

### WWDC 2025
- [Session 277: Bring advanced speech-to-text to your app with SpeechAnalyzer](https://developer.apple.com/videos/play/wwdc2025/277/)
- [示例代码](https://developer.apple.com/documentation/speech/bringing-advanced-speech-to-text-capabilities-to-your-app)

### 第三方测试
- [MacStories: Apple's New Speech APIs Outpace Whisper](https://www.macstories.net/stories/hands-on-how-apples-new-speech-apis-outpace-whisper-for-lightning-fast-transcription/) - 性能对比测试

### 项目内部
- `docs/memo/memory.csv` 第 74-78 行 - LiveCaption 开发历史
- `spoke/Core/Transcription/Providers/SpeechAnalyzerProvider.swift` - 当前实现
- `spoke/Core/Dictionary/DictionaryInjector.swift` - 词典注入架构

---

## 变更记录

| 日期       | 变更     | 作者 |
| ---------- | -------- | ---- |
| 2025-12-04 | 创建文档 | AI   |
| 2025-12-04 | 深度审查：修正 multilingual 描述、补充词典注入机制 (AnalysisContext.contextualStrings)、修正增量计算逻辑、添加影响范围分析 | AI |
