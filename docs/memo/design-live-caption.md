# 实时字幕翻译功能设计

创建: 2024-12-04 | 状态: `基本完成` | 更新: 2025-12-06

> [!NOTE] 技术路线已从 SFSpeechRecognizer 改为 SpeechAnalyzer (macOS 26+)
> 详细重构方案见 `design-live-caption-refactor.md`

> [!IMPORTANT] 2025-12-06 滚动稳定性优化
>
> - `CaptionLineBuffer.maxItems` 扩容到 200 条支持更长历史
> - `AppKitScrollView` 桥接 NSScrollView 精确滚动检测（替代不可靠的 SwiftUI）
> - 滚动用 `main.async` 最小延迟，避免 `asyncAfter` 累积导致错位
> - `layoutSubtreeIfNeeded()` 确保布局完成再计算滚动位置

## 需求概述

监控系统音频(YouTube/Apple Music 等)，实时转录+翻译成中文，支持单词级高亮查询。

## 技术路线

```
ScreenCaptureKit → SFSpeechRecognizer → Apple Translation → 悬浮字幕窗口
(系统音频)         (实时转录)           (本地翻译)         (双语显示)
```

关键发现:

- Apple Live Captions **无公开 API**，无法直接读取
- 必须自建完整 pipeline

## 版本要求

| 功能         | 最低版本   | 降级策略     |
| ------------ | ---------- | ------------ |
| 系统音频捕获 | macOS 12.3 | 提示需要更新 |
| 翻译功能     | macOS 14.4 | 仅显示原文   |

## 文件结构

### 新建文件

```
Core/LiveCaption/
├── SystemAudioCaptureService.swift   # ScreenCaptureKit音频捕获
├── LiveCaptionTranscriber.swift      # 音频→文字转录
├── LiveCaptionManager.swift          # 整合调度+状态管理

Core/Translation/
├── TranslationService.swift          # Apple Translation封装

UI/LiveCaption/
├── LiveCaptionView.swift             # 双语UI(折叠/展开)
├── LiveCaptionWindow.swift           # 可拖动悬浮窗
├── LiveCaptionToolbar.swift          # 工具栏

UI/Settings/
├── LiveCaptionSettingsView.swift     # 字幕设置
```

### 修改文件

- `Services/HotKeyService.swift` - 新增 ⌥S 快捷键
- `App/AppDelegate.swift` - 菜单栏添加「实时字幕」
- `UI/Settings/SettingsView.swift` - 添加字幕 Tab
- `Services/AppSettings.swift` - 字幕配置项

## 核心数据模型

```swift
struct CaptionSegment: Identifiable {
    let id: UUID
    let timestamp: Date
    let originalText: String      // 原文
    let translatedText: String?   // 译文(可能为空)
    let sourceLanguage: String
}

@MainActor
class LiveCaptionManager: ObservableObject {
    @Published var isActive: Bool = false
    @Published var segments: [CaptionSegment] = []
    @Published var isExpanded: Bool = false

    private let audioCapture: SystemAudioCaptureService
    private let transcriber: LiveCaptionTranscriber
    private let translator: TranslationService
}
```

## UI 规格

### 折叠状态

- 只显示最新一段(原文+译文)
- 工具栏: 翻译语言 | 原文开关 | 字体 | 展开按钮 | 关闭

### 展开状态

- ScrollView 显示多段历史
- 最新在下方
- 工具栏: 同上，按钮变为「收起」

### 交互

- 可拖动定位
- ⌥S 切换开关
- 菜单栏入口

## 快捷键

```swift
// HotKeyService.swift
var liveCaptionKeyCode: UInt32 = UInt32(kVK_ANSI_S)
var liveCaptionModifiers: NSEvent.ModifierFlags = .option
var onLiveCaptionToggle: (() -> Void)?
```

## 权限需求

- [√] 屏幕录制权限 (ScreenCaptureKit)
- [√] 语音识别权限 (SFSpeech)

## 工时估算

| 模块                      | 时间     |
| ------------------------- | -------- |
| SystemAudioCaptureService | 1h       |
| LiveCaptionTranscriber    | 1.5h     |
| TranslationService        | 0.5h     |
| LiveCaptionManager        | 1h       |
| LiveCaptionView + Toolbar | 2h       |
| LiveCaptionWindow         | 0.5h     |
| HotKeyService 改动        | 0.5h     |
| AppDelegate 菜单栏        | 0.5h     |
| 设置页面                  | 0.5h     |
| 测试调试                  | 2h       |
| **总计**                  | **~10h** |

## 双层缓冲区模型 (2025-12-05)

解决 volatile 文本不稳定导致的跳动问题。

### 数据模型

```swift
// 已冻结的行（内容永不改变）
private var frozenLines: [String] = []

// 当前行的 finalized 部分（还未冻结）
private var currentLineBuffer: String = ""

// volatile 文本（仅做显示用，不参与分行）
private var volatileTail: String = ""

// 显示窗口起点（只增不减）
private var displayWindowStart: Int = 0
```

### 核心流程

```
update(finalized, volatile)
    │
    ├─ 1. 计算 finalized 增量 (delta)
    │
    ├─ 2. currentLineBuffer += delta
    │
    ├─ 3. while shouldFreezeLine():
    │      freezeCurrentLine()  → frozenLines.append()
    │
    ├─ 4. volatileTail = volatile  (不参与分行！)
    │
    └─ 5. displayText = buildDisplayText()
           = frozenLines[windowStart...] + (currentLineBuffer + volatileTail)
```

### 冻结条件

| 条件     | 阈值                               |
| -------- | ---------------------------------- |
| 强制冻结 | currentLineBuffer.count >= 65      |
| 句末冻结 | count >= 40 且包含句号/问号/感叹号 |

### 切分优先级

句号 > 逗号 > 空格 > 强制切分

### 稳定性保证

| 场景            | 行为                              |
| --------------- | --------------------------------- |
| volatile 变短   | 只有 volatileTail 变，其他不变 ✅ |
| volatile 变长   | 只有 volatileTail 变，其他不变 ✅ |
| frozenLine 增加 | 可能触发 displayWindowStart++ ✅  |
| 分行边界        | 只由 finalized 决定 ✅            |

## 后续扩展

- [ ] 单词级高亮/点击查询
- [ ] 保存到词典
- [ ] 字幕历史导出
- [ ] 多语言互译
- [ ] 翻译功能优化 (debounce + 后台线程)
