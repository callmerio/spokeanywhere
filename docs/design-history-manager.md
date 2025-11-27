# 历史记录管理器 (History Manager) 设计文档

> 版本: 1.0 | 更新: 2025-11-27

---

## L1 - 架构层

### 需求概述

为 SpokenAnyWhere 添加"时光机"功能：将临时录音持久化到 SwiftData，支持搜索历史、播放音频、使用新 Prompt 重新处理旧内容。

### 模块划分

```
RecordingController
  └── processTranscription() ── [修改] ── 保存到 HistoryManager

HistoryManager (新增)
  ├── saveRecording(rawText, processedText, audioURL, appBundleId)
  ├── reprocess(item, newPrompt) → 调用 LLMPipeline
  ├── deleteItem(item) → 删除数据库记录 + 音频文件
  └── audioStorageURL → Application Support/Spoke/Audio/

AudioPlayerService (新增)
  └── play(url), pause(), seek(to:), onProgress, onComplete

HistorySettingsContent (修改)
  ├── HistoryItemRow ── [修改] ── 播放/删除/重处理按钮
  └── ReprocessSheet ── [新增] ── 输入新 Prompt 的弹窗
```

### 数据流向

```
录音完成 → processTranscription()
  ↓
HistoryManager.saveRecording()
  1. 移动音频: temp → Audio/{uuid}.caf (后台队列)
  2. 创建 HistoryItem
  3. modelContext.insert(item)
  ↓
用户打开历史记录 Tab → @Query 获取 [HistoryItem]
  ↓
HistoryItemRow
  ├── 播放 → AudioPlayerService
  ├── 删除 → HistoryManager.delete()
  └── 重处理 → ReprocessSheet → HistoryManager.reprocess()
```

---

## L2 - 逻辑层

### HistoryManager

```pseudo
// 保存录音记录 (异步文件操作)
func saveRecording(rawText, processedText, tempAudioURL, appBundleId) async:
    if tempAudioURL 存在:
        // [优化] 后台队列执行文件操作
        await Task.detached {
            permanentURL = audioStorageURL/uuid.caf
            移动文件 tempAudioURL → permanentURL
        }.value
        audioPath = uuid.caf
        audioDuration = 获取音频时长(permanentURL)
    else:
        audioPath = nil
        audioDuration = nil
    
    // 回到 MainActor 操作数据库
    创建 HistoryItem(rawText, processedText, audioPath, audioDuration, appBundleId)
    modelContext.insert(item)

// 重新处理 (使用自定义 Prompt)
func reprocess(item, customPrompt) async -> Result:
    result = await llmPipeline.refine(item.rawText, customSystemPrompt: customPrompt)
    
    if result.success:
        item.processedText = result.text
    
    return result

// 删除记录
func deleteItem(item):
    if item.audioPath 存在:
        删除文件 audioStorageURL/item.audioPath
    modelContext.delete(item)
```

### AudioPlayerService

```pseudo
@MainActor
class AudioPlayerService: ObservableObject:
    @Published isPlaying = false
    @Published progress = 0.0
    @Published currentTime = 0
    @Published duration = 0
    
    private var player: AVAudioPlayer?
    private var timer: Timer?
    
    func play(url):
        if player.isPlaying: stop()
        
        player = AVAudioPlayer(url)
        duration = player.duration
        player.play()
        isPlaying = true
        启动进度定时器
    
    func pause():
        player.pause()
        isPlaying = false
    
    func stop():
        player.stop()
        timer.invalidate()
        isPlaying = false
        progress = 0
```

---

## L3 - 接口层

### HistoryManager

```swift
@MainActor
final class HistoryManager {
    static let shared = HistoryManager()
    
    private var modelContext: ModelContext?
    
    var audioStorageURL: URL { get }
    
    func configure(with context: ModelContext)
    
    func saveRecording(
        rawText: String,
        processedText: String?,
        tempAudioURL: URL?,
        appBundleId: String?
    ) async
    
    func reprocess(
        _ item: HistoryItem,
        with customPrompt: String
    ) async -> Result<String, LLMError>
    
    func deleteItem(_ item: HistoryItem)
    
    func audioURL(for item: HistoryItem) -> URL?
}
```

### AudioPlayerService

```swift
@MainActor
final class AudioPlayerService: ObservableObject {
    static let shared = AudioPlayerService()
    
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var currentURL: URL? = nil
    
    func play(_ url: URL) throws
    func pause()
    func resume()
    func stop()
    func seek(to time: TimeInterval)
}
```

### LLMPipeline 扩展

```swift
// 新增重载方法
func refine(
    _ text: String,
    customSystemPrompt: String? = nil
) async -> Result<String, LLMError>
```

### HistoryItem 扩展

```swift
@Model
class HistoryItem {
    // ... existing fields ...
    var audioDuration: TimeInterval?  // 新增
    
    var displayText: String { processedText ?? rawText }
    var hasAudio: Bool { audioPath != nil }
}
```

### 文件存储

```
~/Library/Application Support/Spoke/
└── Audio/
    ├── {uuid1}.caf
    └── {uuid2}.caf
```

---

## L4 - 验证层

| 场景 | 预期结果 |
|------|----------|
| 保存录音 | HistoryItem 创建，音频移动到永久目录 |
| 保存无音频 | HistoryItem 创建，audioPath = nil |
| 重处理成功 | processedText 更新 |
| 重处理失败 | processedText 保持原值 |
| 删除记录 | 数据库记录 + 音频文件删除 |
| 播放音频 | 进度条更新，完成后重置 |

---

## L5 - 风险

| 问题 | 缓解措施 |
|------|----------|
| 存储空间 | Phase 2 添加自动清理 |
| ModelContext 注入 | AppDelegate 启动时配置 |
| 文件 I/O 阻塞 | 使用 Task.detached 后台执行 |
