# 交接文档：DictationTranscriber + 预编译 LM 集成

> 日期：2025-12-04
> 目标：主转录功能 (Option+R) 支持预编译词典 (SFSpeechLanguageModel)

## 一、背景与目标

### 用户需求

1. 主转录 (Option+R) 使用 macOS 26 新模型，并支持**预编译词典**
2. 词典条目（如 Gemini、Claude、描边等）应该被 ASR 引擎识别
3. 保留原有代码作为 fallback，便于后续优化

### 技术发现

| 引擎                   | 预编译 LM (`SFSpeechLanguageModel`)         | 轻量级 (`contextualStrings`) |
| ---------------------- | ------------------------------------------- | ---------------------------- |
| `SpeechTranscriber`    | ❌ 不支持                                   | ✅ 支持                      |
| `DictationTranscriber` | ✅ 支持 `contentHints.customizedLanguage()` | ✅ 支持                      |
| `SFSpeechRecognizer`   | ✅ 支持                                     | ✅ 支持                      |

**结论**：要使用预编译 LM，必须用 `DictationTranscriber` 而非 `SpeechTranscriber`

## 二、代码变更

### 1. `SpeechAnalyzerProvider.swift`

- 从 `SpeechTranscriber` 切换到 `DictationTranscriber`
- 新增 `createDictationTranscriber()` 方法，通过 `contentHints.insert(.customizedLanguage(modelConfiguration:))` 注入预编译 LM
- 保留 `SpeechTranscriber` 代码（注释）作为 fallback

**关键代码**：

```swift
private func createDictationTranscriber(locale: Locale) async throws -> DictationTranscriber {
    // ...
    if let lmConfiguration = injector.languageModelConfiguration {
        contentHints.insert(.customizedLanguage(modelConfiguration: lmConfiguration))
        reportingOptions.insert(.frequentFinalization)
        logger.info("📚 [词典] 预编译 LM 已应用")
    }
    // ...
}
```

### 2. `DictionaryInjector.swift`

- 新增 `languageModelConfiguration` 属性，供 `DictationTranscriber` 使用
- 添加详细的预编译耗时日志

```swift
var languageModelConfiguration: SFSpeechLanguageModel.Configuration? {
    guard isPrepared, let outputURL = modelOutputURL else { return nil }
    return SFSpeechLanguageModel.Configuration(languageModel: outputURL, vocabulary: lexiconOutputURL)
}
```

### 3. `TranscriptionManager.swift`

- **修复关键 bug**：`createBestProvider()` 不再覆盖已准备好的 `dictionaryInjector`
- 添加 `isDictionaryPrepared` 状态日志

**修复前（bug）**：

```swift
dictionaryInjector = DictionaryInjectorFactory.createInjector(for: engineType) // 每次都创建新的！
```

**修复后**：

```swift
if dictionaryInjector == nil {
    dictionaryInjector = DictionaryInjectorFactory.createInjector(for: engineType)
}
```

### 4. `TranscriptionPostProcessor.swift`

- 修改 `isDictionaryEnabled` 默认值为 `true`

### 5. `AppDelegate.swift`

- 添加 Logger 用于词典准备日志
- 调整日志输出方式（Logger 代替 print/NSLog）

### 6. `dev.sh`

- 添加 `--level info` 参数捕获 info 级别日志
- 调整时序：先启动 `log stream`，再启动应用
- 添加词典相关关键词过滤

## 三、测试验证

### 预期日志流程

```
📚 [预编译 LM] 开始准备词典... isDictionaryInjectionEnabled=true
📚 [预编译 LM] dictionaryInjector 为 nil，创建新的 injector...
📚 [预编译 LM] 获取到词典条目数: 8
📚 [预编译 LM] 开始预编译 8 个词条...
⏱️ [预编译 LM] SFSpeechLanguageModel.prepareCustomLanguageModel 耗时: XXXms
✅ [预编译 LM] 词典准备完成！
⏱️ [词典] App 启动 → 词典预编译完成: XXXms
✅ [词典] 现在可以正常使用带词典的转录功能

# 用户录音时
✅ Using engine: Apple 语音分析器, isDictionaryPrepared=true
📚 [词典] 预编译 LM 已应用，配置耗时: XXXms
```

### 测试命令

```bash
cd spoke && ./dev.sh
```

## 四、待处理问题

### 1. `<private>` 日志隐私问题

Apple 的隐私保护机制导致数值显示为 `<private>`，需要使用 `.public` 修饰符：

```swift
logger.info("耗时: \(time, privacy: .public)ms")
```

### 2. `ModelContext not configured` 错误

SwiftData 历史记录清理功能报错，不影响词典功能，后续修复。

### 3. Roadmap TODO

- **预编译 LM 耗时优化**：当预编译耗时过长时，使用 `SpeechTranscriber + contextualStrings` 作为快速 fallback
- **SFSpeechRecognizer 兼容性回退**：当 `DictationTranscriber` 不可用时回退

## 五、相关文件

| 文件                                                              | 说明                      |
| ----------------------------------------------------------------- | ------------------------- |
| `spoke/Core/Transcription/Providers/SpeechAnalyzerProvider.swift:11` | DictationTranscriber 实现 |
| `spoke/Core/Dictionary/DictionaryInjector.swift:10`                  | 预编译 LM 注入器          |
| `spoke/Core/Transcription/TranscriptionManager.swift:30`             | 词典准备逻辑              |
| `spoke/Core/Transcription/TranscriptionPostProcessor.swift:10`       | 词典默认开关              |
| `spoke/App/AppDelegate.swift:7`                                      | 启动时词典准备            |
| `spoke/dev.sh:1`                                                     | 开发调试脚本              |
| `docs/roadmap.md:1`                                                  | TODO 记录                 |
| `docs/memo/memory.csv:1`                                             | 修改历史                  |

## 六、架构图

```
App 启动
    │
    ▼
AppDelegate.applicationDidFinishLaunching()
    │
    ├── TranscriptionManager.shared.prepareDictionary()
    │       │
    │       ▼
    │   DictionaryInjectorFactory.createInjector()
    │       │
    │       ▼
    │   AppleSpeechDictionaryInjector.prepare()
    │       │
    │       ▼
    │   SFSpeechLanguageModel.prepareCustomLanguageModel()  ← 预编译（耗时）
    │       │
    │       ▼
    │   isDictionaryPrepared = true
    │   languageModelConfiguration 可用
    │
    ▼
用户按 Option+R 录音
    │
    ▼
AudioRecorderService.startRecording()
    │
    ▼
TranscriptionManager.createBestProvider()
    │
    ├── 检查 dictionaryInjector (不为 nil，不创建新的)
    │
    ▼
SpeechAnalyzerProvider.prepare()
    │
    ▼
createDictationTranscriber()
    │
    ├── injector.languageModelConfiguration  ← 获取预编译 LM
    │
    ▼
DictationTranscriber(contentHints: [.customizedLanguage(modelConfiguration)])  ← 注入词典
    │
    ▼
转录开始，词典生效
```

## 七、memory.csv 记录

```
2025-12-04T14:32,spoke,SpeechAnalyzerProvider.swift;DictionaryInjector.swift;TranscriptionManager.swift,feat,主转录切换到DictationTranscriber+预编译LM,SpeechTranscriber不支持预编译LM;修复createBestProvider覆盖injector的bug,详见handover-dictation-transcriber-precompiled-lm.md
```
