# 词典功能开发交接文档

> 最后更新: 2025-12-03 21:40
> 状态: ✅ 已完成基础实现，待实际测试

---

## 一、功能概述

### 1.1 需求背景

用户在使用语音转录时，专有名词（如 Anthropic、Claude、GPT-4）经常被识别错误。需要一个词典功能来提高转录准确性。

### 1.2 功能范围

- **设置界面入口**：设置 → 词典 Tab
- **Pipeline 右键菜单**：
  - 「添加到词典」→ 将选中文本作为新词添加
  - 「纠正为...」→ 将选中的错误识别映射到正确词形
- **手动输入**：单个添加 + 批量导入
- **自动推荐**：热词学习，分析高频词推荐给用户确认
- **转录集成**：
  - Apple 原生 LM 自定义（macOS 14+）
  - Whisper initial_prompt 注入（预留）
  - 后处理文本替换（Fallback）

---

## 二、核心文件清单

### 2.1 数据模型层

| 文件                                      | 用途                                      |
| ----------------------------------------- | ----------------------------------------- |
| `Core/Dictionary/DictionaryEntry.swift`   | 词典条目数据模型                          |
| `Core/Dictionary/DictionaryService.swift` | 词典核心服务（CRUD/匹配/热词挖掘/持久化） |

### 2.2 注入抽象层

| 文件                                       | 用途                          |
| ------------------------------------------ | ----------------------------- |
| `Core/Dictionary/DictionaryInjector.swift` | 统一词典注入协议 + 各引擎实现 |

### 2.3 转录集成

| 文件                                                  | 用途                            |
| ----------------------------------------------------- | ------------------------------- |
| `Core/Transcription/TranscriptionManager.swift`       | 词典准备/注入生命周期管理       |
| `Core/Transcription/TranscriptionPostProcessor.swift` | 后处理器（文本替换 + 热词学习） |
| `Core/Transcription/Providers/SFSpeechProvider.swift` | Apple Speech 词典应用           |

### 2.4 UI 层

| 文件                                           | 用途                   |
| ---------------------------------------------- | ---------------------- |
| `UI/Settings/DictionarySettingsView.swift`     | 词典设置页面           |
| `UI/Components/DictionarySelectableText.swift` | 支持右键菜单的文本组件 |
| `UI/MessagePanel/MessagePanelView.swift`       | 集成词典弹窗           |

---

## 三、数据模型

### 3.1 DictionaryEntry

```swift
struct DictionaryEntry: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var word: String              // 期望的正确词形（最终输出）
    var corrections: [String]     // 纠错映射：可能的错误识别形式
    var source: DictionaryEntrySource  // .manual 或 .auto
    var frequency: Int            // 使用频率（热词学习）
    let createdAt: Date
    var lastUsedAt: Date?
    var confirmedByUser: Bool     // 用户是否已确认
}
```

### 3.2 纠错映射的作用

```
word = "Anthropic"  (期望输出)
corrections = ["安索皮克", "anthropick", "anthro pick"]  (可能的错误识别形式)

工作流程:
1. ASR 识别出 "安索皮克"
2. 后处理器检查是否匹配任何 correction
3. 匹配成功 → 替换为对应的 word "Anthropic"
```

### 3.3 数据存储

- 词典条目: `~/Library/Application Support/Spoke/dictionary.json`
- 待确认热词: `~/Library/Application Support/Spoke/pending_hotwords.json`
- 语言模型缓存: `~/Library/Application Support/Spoke/LanguageModels/`

---

## 四、架构设计

### 4.1 词典注入抽象

```
                    DictionaryInjector (协议)
                           │
         ┌─────────────────┼─────────────────┐
         ▼                 ▼                 ▼
AppleSpeechInj.    WhisperInj.      PostProcessInj.
(🟢 转录阶段)      (🟢 转录阶段)    (🔴 后处理阶段)
使用: word        使用: word       使用: corrections
     │                   │                 │
     ▼                   ▼                 ▼
SFCustomLM         initial_prompt      字符串替换
(macOS 14+)        (每次传递)          (fallback)
```

**重要区别**：

- **转录阶段**：只使用 `word`，让 ASR 更容易识别这个词
- **后处理阶段**：使用 `corrections → word` 映射，把错误识别替换为正确词形

**纠错策略**（默认使用 LLM 智能纠错）：

- 不强制替换，而是把 `corrections → word` 映射告诉 LLM
- LLM 根据上下文判断是否需要替换
- 避免盲目替换导致误伤

### 4.2 工作流程

```
App 启动
    │
    ▼
TranscriptionManager.prepareDictionary()  ← 后台异步预热
    │
    ▼
用户开始录音
    │
    ▼
createBestProvider() → 创建对应 DictionaryInjector
    │
    ▼
SFSpeechProvider.prepare()
    │
    ├─→ injector.apply(to: &request)  ← 注入词典到识别请求
    │
    ▼
识别过程（仍然流式实时）
    │
    ▼
TranscriptionPostProcessor.process(result)
    ├─→ applyDictionary()  ← 后处理替换
    └─→ learnHotwords()    ← 热词学习
```

### 4.3 Apple 原生 LM 预处理

```swift
// 关键 API (macOS 14+ / iOS 17+)
SFSpeechLanguageModel.prepareCustomLanguageModel(
    for: inputURL,
    configuration: .init(languageModel: outputURL, vocabulary: lexiconURL),
    ignoresCache: false  // ← 支持缓存！
)

// 应用到识别请求
request.requiresOnDeviceRecognition = true  // 必须！
request.customizedLanguageModel = config
```

**重要发现**：

- ✅ 预处理有缓存，不需要每次都执行
- ✅ 不影响流式实时性
- ❌ 必须使用 on-device 模式

---

## 五、设置界面

### 5.1 词典 Tab 结构

```
┌─────────────────────────────────────────────────────┐
│ 词典                                    [新增热词 ▼] │
│ 手动维护热词词典...                                  │
├─────────────────────────────────────────────────────┤
│ [词典注入] ○──  [热词学习] ○──           ● 已就绪   │
├─────────────────────────────────────────────────────┤
│ [全部] [自动添加] [手动添加]    🔍 搜索...          │
├─────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────┐ │
│ │ Anthropic                            ✏️ 🗑️    │ │
│ │ 别名: 安索皮克, anthropick                      │ │
│ └─────────────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────────────┐ │
│ │ Claude                               ✏️ 🗑️    │ │
│ │ 别名: 克劳德, cloud                             │ │
│ └─────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────┤
│ 💡 热词推荐                                         │
│ [OpenAI ✓ ✗] [Sonnet ✓ ✗] [Whisper ✓ ✗]           │
└─────────────────────────────────────────────────────┘
```

### 5.2 开关说明

| 开关     | 作用                                                      |
| -------- | --------------------------------------------------------- |
| 词典注入 | 启用后，词典 `word` 在**转录阶段**生效（Apple LM 预处理） |
| 识别强度 | 轻量/标准/增强，控制词典对 ASR 的影响程度                 |
| 热词学习 | 启用后，自动分析转录内容，推荐高频专有名词                |

---

## 六、通知机制

```swift
// 词典变化通知
Notification.Name.dictionaryDidChange
Notification.Name.hotwordsDidChange

// Pipeline 右键菜单请求
Notification.Name.requestAddToDictionary
// userInfo: ["word": String, "mode": "new" | "alias"]
```

---

## 七、待完成事项

### 7.1 测试验证

- [ ] 实际运行测试词典注入效果
- [ ] 验证 Apple LM 预处理缓存是否生效
- [ ] 测试热词推荐阈值是否合理

### 7.2 后续优化

- [ ] Whisper 集成时实现 WhisperDictionaryInjector
- [ ] 词典导入/导出 JSON 功能
- [ ] 词典同步（iCloud）

### 7.3 已知限制

- Apple LM 自定义仅支持 macOS 14+ / iOS 17+
- 必须使用 on-device 模式
- 预处理可能需要几秒钟（有 loading 状态）

---

## 八、关键代码片段

### 8.1 词典匹配逻辑

```swift
// DictionaryService.swift
func applyDictionary(to text: String) -> String {
    var result = text
    for entry in activeEntries {
        result = entry.replace(in: result)
    }
    return result
}

// DictionaryEntry.swift
func replace(in text: String) -> String {
    var result = text
    // 替换错误形式为正确词形
    for errorForm in corrections {
        result = result.replacingOccurrences(
            of: "\\b\(NSRegularExpression.escapedPattern(for: errorForm))\\b",
            with: word,
            options: [.regularExpression, .caseInsensitive]
        )
    }
    return result
}
```

### 8.2 注入器应用

```swift
// SFSpeechProvider.swift - prepare()
let manager = TranscriptionManager.shared
if manager.isDictionaryInjectionEnabled,
   manager.isDictionaryPrepared,
   let injector = manager.dictionaryInjector {
    try injector.apply(to: &request)
}
```

---

## 九、相关 Memo 记录

- `2025-12-03T17:05` - 词典功能完整实现
- `2025-12-03T19:40` - 词典注入抽象层 + Apple LM 原生支持
- `2025-12-03T20:40` - 术语重构: `aliases` → `corrections`（纠错映射）
- `2025-12-03T21:40` - 权重调节 UI + LLM 智能纠错（替代强制替换）

---

## 十、TODO（待实现）

- [ ] **分类词典**：按场景分组（技术/日常/专业），用户可选择激活哪些
- [ ] **上下文感知 n-gram**：Apple LM 支持 n-gram，可加入上下文短语提高识别
- [ ] **词典导入/导出**：支持从文件批量导入，导出分享

---

## 十一、参考资料

- [WWDC23 - Customize on-device speech recognition](https://developer.apple.com/videos/play/wwdc2023/10101/)
- [SFSpeechLanguageModel 文档](https://developer.apple.com/documentation/speech/sfspeechlanguagemodel)
- [Whisper initial_prompt 讨论](https://github.com/openai/whisper/discussions/963)
