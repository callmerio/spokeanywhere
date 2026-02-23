# Quick Ask 配置详细文档

> 版本: v1.0
> 创建时间: 2026-02-23
> 用途: Quick Ask 功能的所有配置项详细说明

---

## 配置项总览

Quick Ask 功能共有 5 个配置项，控制上下文收集行为：

| setting_key | owner | read-path | write-path | 生效语义 | dependencies | side_effects |
|-------------|-------|-----------|------------|----------|--------------|--------------|
| `quickAskIncludeOCR` | LLMSettings.swift:176 | QuickAskService.swift:183 | AISettingsCards.swift | 即时 | ScreenOCRService | 上下文收集 |
| `quickAskIncludeScreenshot` | LLMSettings.swift:181 | QuickAskService.swift:192 | AISettingsCards.swift | 即时 | ScreenOCRService | 上下文收集 |
| `quickAskIncludeClipboard` | LLMSettings.swift:186 | QuickAskService.swift:buildPromptResult | AISettingsCards.swift | 即时 | ClipboardHistoryService | 上下文收集 |
| `quickAskIncludeLiveCaption` | LLMSettings.swift:191 | QuickAskService.swift:buildPromptResult | AISettingsCards.swift | 即时 | LiveCaptionManager | 上下文收集 |
| `quickAskLiveCaptionLimit` | LLMSettings.swift:196 | QuickAskService.swift:buildPromptResult | AISettingsCards.swift | 即时 | quickAskIncludeLiveCaption | 限制数量 |

---

## 1. quickAskIncludeOCR

### 基本信息

**类型**: `Bool`
**默认值**: `true`
**配置位置**: `spoke/Core/LLM/LLMSettings.swift:176`
**持久化**: UserDefaults (`llm.quickAskIncludeOCR`)

### 读取入口

**主要读取点**: `spoke/Services/QuickAskService.swift:183`

```swift
// QuickAskService.swift:179-188
let settings = LLMSettings.shared
var contextSources: [ContextSource] = []

// 异步获取 OCR 上下文
var ocrContext: String?
if settings.quickAskIncludeOCR {
    ocrContext = await ScreenOCRService.shared.getActiveWindowText(maxLength: 2000)
    if ocrContext != nil && !ocrContext!.isEmpty {
        contextSources.append(.ocr)
    }
}
```

### 写入入口

**UI 入口**: `spoke/UI/Settings/AISettingsCards.swift`

```swift
Toggle("包含应用 OCR", isOn: $settings.quickAskIncludeOCR)
```

**响应逻辑**:
1. 用户在设置界面切换开关
2. SwiftUI 绑定自动更新 `LLMSettings.shared.quickAskIncludeOCR`
3. `didSet` 触发 `save()` 方法
4. 保存到 UserDefaults

### 生效时机

**即时生效** - 下次 Quick Ask 触发时立即生效

**生效流程**:
1. 用户按下 ⌥T 触发 Quick Ask
2. `QuickAskService.sendQuestion()` 被调用
3. 检查 `settings.quickAskIncludeOCR` 当前值
4. 如果为 `true`，调用 `ScreenOCRService.shared.getActiveWindowText(maxLength: 2000)`
5. 如果为 `false`，跳过 OCR 上下文收集

### 依赖与联动

**前置依赖**:
- `ScreenOCRService` 必须可用
- 辅助功能权限（Accessibility）必须已授权

**跨模块影响**:
- 影响 `QuickAskService.sendQuestion()` 的上下文收集逻辑
- 影响 `AnswerPanelView` 显示的上下文来源标记

**关联配置**:
- `quickAskIncludeScreenshot`: 通常一起使用（截图 + OCR）
- `selectionToolbarOCRContext`: Selection Toolbar 的 OCR 开关（独立）

### 副作用与回退

**性能影响**:
- 开启时：每次 Quick Ask 触发会执行 OCR（约 100-300ms）
- 关闭时：无 OCR 开销

**UI 行为**:
- 开启时：Answer Panel 显示 "OCR" 上下文来源标记
- 关闭时：不显示 OCR 标记

**日志输出**:
```swift
// QuickAskService.swift:211-213
logger.info(
    "📤 Sending question: \(questionPreview, privacy: .public)... sources: \(sourceList, privacy: .public)"
)
```

**兼容性**:
- 无迁移逻辑（新增配置项）
- 默认值 `true` 保持向后兼容

### 验证方式

**最小复现步骤**:
1. 打开设置 → AI Processing
2. 关闭 "包含应用 OCR"
3. 打开任意应用（如 Safari）
4. 按下 ⌥T 触发 Quick Ask
5. 输入问题并发送

**证据路径**:
```bash
# 查看日志
log show --predicate 'subsystem == "com.spokeanywhere" AND category == "QuickAsk"' \
    --style syslog --last 1m | grep "sources:"
```

**预期结果**:
- 关闭时：`sources: []` 或不包含 "OCR"
- 开启时：`sources: ["OCR"]` 或包含 "OCR"

---

## 2. quickAskIncludeScreenshot

### 基本信息

**类型**: `Bool`
**默认值**: `false`
**配置位置**: `spoke/Core/LLM/LLMSettings.swift:181`
**持久化**: UserDefaults (`llm.quickAskIncludeScreenshot`)

### 读取入口

**主要读取点**: `spoke/Services/QuickAskService.swift:192`

```swift
// QuickAskService.swift:190-197
// 获取截图（如果开启）
var screenshotImage: CGImage?
if settings.quickAskIncludeScreenshot {
    screenshotImage = await ScreenOCRService.shared.captureActiveWindow()
    if screenshotImage != nil {
        contextSources.append(.screenshot)
    }
}
```

### 写入入口

**UI 入口**: `spoke/UI/Settings/AISettingsCards.swift`

```swift
Toggle("包含应用截图（多模态）", isOn: $settings.quickAskIncludeScreenshot)
```

**响应逻辑**:
1. 用户在设置界面切换开关
2. SwiftUI 绑定自动更新 `LLMSettings.shared.quickAskIncludeScreenshot`
3. `didSet` 触发 `save()` 方法
4. 保存到 UserDefaults

### 生效时机

**即时生效** - 下次 Quick Ask 触发时立即生效

**生效流程**:
1. 用户按下 ⌥T 触发 Quick Ask
2. `QuickAskService.sendQuestion()` 被调用
3. 检查 `settings.quickAskIncludeScreenshot` 当前值
4. 如果为 `true`，调用 `ScreenOCRService.shared.captureActiveWindow()`
5. 如果为 `false`，跳过截图捕获

### 依赖与联动

**前置依赖**:
- `ScreenOCRService` 必须可用
- 屏幕录制权限（Screen Recording）必须已授权
- LLM 模型必须支持多模态（Vision）

**跨模块影响**:
- 影响 `QuickAskService.sendQuestion()` 的上下文收集逻辑
- 影响 `AnswerPanelView` 显示的上下文来源标记
- 截图传递给 `AnswerPanelManager` 用于 UI 显示，但当前 Quick Ask 走文本 chat（未注入 LLM）

**关联配置**:
- `quickAskIncludeOCR`: 通常一起使用（截图 + OCR）
- LLM Profile 必须支持 Vision（如 Gemini 2.0 Flash）

### 副作用与回退

**性能影响**:
- 开启时：每次 Quick Ask 触发会捕获截图（约 50-150ms）
- 关闭时：无截图开销

**UI 行为**:
- 开启时：Answer Panel 显示 "截图" 上下文来源标记
- 关闭时：不显示截图标记

**日志输出**:
```swift
// QuickAskService.swift:211-213
logger.info(
    "📤 Sending question: \(questionPreview, privacy: .public)... sources: \(sourceList, privacy: .public)"
)
```

**兼容性**:
- 无迁移逻辑（新增配置项）
- 默认值 `false`（避免意外开销）

### 验证方式

**最小复现步骤**:
1. 打开设置 → AI Processing
2. 开启 "包含应用截图（多模态）"
3. 打开任意应用（如 Safari）
4. 按下 ⌥T 触发 Quick Ask
5. 输入问题并发送

**证据路径**:
```bash
# 查看日志
log show --predicate 'subsystem == "com.spokeanywhere" AND category == "QuickAsk"' \
    --style syslog --last 1m | grep "sources:"
```

**预期结果**:
- 关闭时：`sources: []` 或不包含 "截图"
- 开启时：`sources: ["截图"]` 或包含 "截图"

---

## 3. quickAskIncludeClipboard

### 基本信息

**类型**: `Bool`
**默认值**: `true`
**配置位置**: `spoke/Core/LLM/LLMSettings.swift:186`
**持久化**: UserDefaults (`llm.quickAskIncludeClipboard`)

### 读取入口

**主要读取点**: `spoke/Services/QuickAskService.swift:buildPromptResult`

```swift
// QuickAskService.swift (buildPromptResult 方法)
if settings.quickAskIncludeClipboard {
    // 获取剪贴板历史（最近 5 项）
    let clipboardHistory = ClipboardHistoryService.shared.getHistoryForContext(limit: 5)
    // 添加到 prompt
}
```

### 写入入口

**UI 入口**: `spoke/UI/Settings/AISettingsCards.swift`

```swift
Toggle("包含剪贴板", isOn: $settings.quickAskIncludeClipboard)
```

**响应逻辑**:
1. 用户在设置界面切换开关
2. SwiftUI 绑定自动更新 `LLMSettings.shared.quickAskIncludeClipboard`
3. `didSet` 触发 `save()` 方法
4. 保存到 UserDefaults

### 生效时机

**即时生效** - 下次 Quick Ask 触发时立即生效

**生效流程**:
1. 用户按下 ⌥T 触发 Quick Ask
2. `QuickAskService.sendQuestion()` 被调用
3. 调用 `buildPromptResult()` 组装 prompt
4. 检查 `settings.quickAskIncludeClipboard` 当前值
5. 如果为 `true`，获取剪贴板历史并添加到 prompt
6. 如果为 `false`，跳过剪贴板上下文

### 依赖与联动

**前置依赖**:
- `ClipboardHistoryService` 必须可用（应用启动时自动启动）

**跨模块影响**:
- 影响 `QuickAskService.buildPromptResult()` 的 prompt 组装逻辑
- 影响 `AnswerPanelView` 显示的上下文来源标记

**关联配置**:
- `clipboardHistoryLimit`: 剪贴板历史保存条数（影响可用数据）

### 副作用与回退

**性能影响**:
- 开启时：每次 Quick Ask 触发会读取剪贴板历史（约 1-5ms）
- 关闭时：无剪贴板读取开销

**UI 行为**:
- 开启时：Answer Panel 显示 "剪贴板" 上下文来源标记
- 关闭时：不显示剪贴板标记

**日志输出**:
```swift
// QuickAskService.swift:211-213
logger.info(
    "📤 Sending question: \(questionPreview, privacy: .public)... sources: \(sourceList, privacy: .public)"
)
```

**兼容性**:
- 无迁移逻辑（新增配置项）
- 默认值 `true` 保持向后兼容

### 验证方式

**最小复现步骤**:
1. 打开设置 → AI Processing
2. 关闭 "包含剪贴板"
3. 复制一些文本到剪贴板
4. 按下 ⌥T 触发 Quick Ask
5. 输入问题并发送

**证据路径**:
```bash
# 查看日志
log show --predicate 'subsystem == "com.spokeanywhere" AND category == "QuickAsk"' \
    --style syslog --last 1m | grep "sources:"
```

**预期结果**:
- 关闭时：`sources: []` 或不包含 "剪贴板"
- 开启时：`sources: ["剪贴板"]` 或包含 "剪贴板"

---

## 4. quickAskIncludeLiveCaption

### 基本信息

**类型**: `Bool`
**默认值**: `false`
**配置位置**: `spoke/Core/LLM/LLMSettings.swift:191`
**持久化**: UserDefaults (`llm.quickAskIncludeLiveCaption`)

### 读取入口

**主要读取点**: `spoke/Services/QuickAskService.swift:buildPromptResult`

```swift
// QuickAskService.swift (buildPromptResult 方法)
if settings.quickAskIncludeLiveCaption {
    // 获取实时字幕历史
    let limit = settings.quickAskLiveCaptionLimit
    let captions = LiveCaptionManager.shared.getOriginalTextHistory(limit: limit)
    // 添加到 prompt
}
```

### 写入入口

**UI 入口**: `spoke/UI/Settings/AISettingsCards.swift`

```swift
Toggle("包含实时字幕上下文", isOn: $settings.quickAskIncludeLiveCaption)
```

**响应逻辑**:
1. 用户在设置界面切换开关
2. SwiftUI 绑定自动更新 `LLMSettings.shared.quickAskIncludeLiveCaption`
3. `didSet` 触发 `save()` 方法
4. 保存到 UserDefaults

### 生效时机

**即时生效** - 下次 Quick Ask 触发时立即生效

**生效流程**:
1. 用户按下 ⌥T 触发 Quick Ask
2. `QuickAskService.sendQuestion()` 被调用
3. 调用 `buildPromptResult()` 组装 prompt
4. 检查 `settings.quickAskIncludeLiveCaption` 当前值
5. 如果为 `true`，获取实时字幕历史并添加到 prompt
6. 如果为 `false`，跳过字幕上下文

### 依赖与联动

**前置依赖**:
- `LiveCaptionManager` 必须可用
- 实时字幕功能必须已启动（用户按下 ⌥S）

**跨模块影响**:
- 影响 `QuickAskService.buildPromptResult()` 的 prompt 组装逻辑
- 影响 `AnswerPanelView` 显示的上下文来源标记

**关联配置**:
- `quickAskLiveCaptionLimit`: 字幕历史数量限制（联动配置）
- Live Caption 相关配置（源语言、目标语言等）

### 副作用与回退

**性能影响**:
- 开启时：每次 Quick Ask 触发会读取字幕历史（约 1-10ms）
- 关闭时：无字幕读取开销

**UI 行为**:
- 开启时：Answer Panel 显示 "实时字幕" 上下文来源标记
- 关闭时：不显示字幕标记

**日志输出**:
```swift
// QuickAskService.swift:211-213
logger.info(
    "📤 Sending question: \(questionPreview, privacy: .public)... sources: \(sourceList, privacy: .public)"
)
```

**兼容性**:
- 无迁移逻辑（新增配置项）
- 默认值 `false`（避免意外开销）

### 验证方式

**最小复现步骤**:
1. 打开设置 → AI Processing
2. 开启 "包含实时字幕上下文"
3. 按下 ⌥S 启动实时字幕
4. 播放一些音频（让字幕有内容）
5. 按下 ⌥T 触发 Quick Ask
6. 输入问题并发送

**证据路径**:
```bash
# 查看日志
log show --predicate 'subsystem == "com.spokeanywhere" AND category == "QuickAsk"' \
    --style syslog --last 1m | grep "sources:"
```

**预期结果**:
- 关闭时：`sources: []` 或不包含 "实时字幕"
- 开启时：`sources: ["实时字幕"]` 或包含 "实时字幕"

---

## 5. quickAskLiveCaptionLimit

### 基本信息

**类型**: `Int`
**默认值**: `50`
**配置位置**: `spoke/Core/LLM/LLMSettings.swift:196`
**持久化**: UserDefaults (`llm.quickAskLiveCaptionLimit`)

### 读取入口

**主要读取点**: `spoke/Services/QuickAskService.swift:buildPromptResult`

```swift
// QuickAskService.swift (buildPromptResult 方法)
if settings.quickAskIncludeLiveCaption {
    let limit = settings.quickAskLiveCaptionLimit  // 读取限制
    let captions = LiveCaptionManager.shared.getOriginalTextHistory(limit: limit)
    // 添加到 prompt
}
```

### 写入入口

**UI 入口**: `spoke/UI/Settings/AISettingsCards.swift`

```swift
Picker("字幕历史数量", selection: $settings.quickAskLiveCaptionLimit) {
    Text("最近 50 条").tag(50)
    Text("全量").tag(0)
}
```

**响应逻辑**:
1. 用户在设置界面调整数值
2. SwiftUI 绑定自动更新 `LLMSettings.shared.quickAskLiveCaptionLimit`
3. `didSet` 触发 `save()` 方法
4. 保存到 UserDefaults

### 生效时机

**即时生效** - 下次 Quick Ask 触发时立即生效

**生效流程**:
1. 用户按下 ⌥T 触发 Quick Ask
2. `QuickAskService.sendQuestion()` 被调用
3. 调用 `buildPromptResult()` 组装 prompt
4. 读取 `settings.quickAskLiveCaptionLimit` 当前值
5. 传递给 `LiveCaptionManager.shared.getOriginalTextHistory(limit:)`
6. 获取指定数量的字幕历史

### 依赖与联动

**前置依赖**:
- `quickAskIncludeLiveCaption` 必须为 `true`（否则此配置无效）
- `LiveCaptionManager` 必须可用

**跨模块影响**:
- 影响 `QuickAskService.buildPromptResult()` 的字幕数量
- 影响 LLM prompt 的长度和 token 消耗

**关联配置**:
- `quickAskIncludeLiveCaption`: 字幕上下文总开关（前置依赖）

### 副作用与回退

**性能影响**:
- 数值越大：读取字幕越多，prompt 越长，LLM 处理时间越长
- 数值越小：上下文越少，可能影响 LLM 理解

**UI 行为**:
- 无直接 UI 影响（仅影响 prompt 内容）

**日志输出**:
- 无专门日志（包含在 Quick Ask 日志中）

**兼容性**:
- 无迁移逻辑（新增配置项）
- 默认值 `50`（平衡上下文和性能）
- 特殊值 `0` 表示全量（不限制）

### 验证方式

**最小复现步骤**:
1. 打开设置 → AI Processing
2. 开启 "包含实时字幕上下文"
3. 选择 "字幕历史数量" 为 "最近 50 条"（或 "全量"）
4. 按下 ⌥S 启动实时字幕
5. 播放音频（生成足够字幕）
6. 按下 ⌥T 触发 Quick Ask
7. 输入问题并发送

**证据路径**:
```bash
# 查看 LLM prompt（需要在代码中添加日志）
log show --predicate 'subsystem == "com.spokeanywhere" AND category == "LLMPipeline"' \
    --style syslog --last 1m | grep "prompt"
```

**预期结果**:
- 选择 "最近 50 条"：prompt 中包含最近 50 条字幕
- 选择 "全量"：prompt 中包含所有字幕

---

## 配置依赖关系图

```
Quick Ask 触发 (⌥T)
│
├─ quickAskIncludeOCR = true
│  └─ ScreenOCRService.getActiveWindowText(maxLength: 2000)
│     └─ 添加 "OCR" 到 contextSources
│
├─ quickAskIncludeScreenshot = true
│  └─ ScreenOCRService.captureActiveWindow()
│     └─ 添加 "截图" 到 contextSources
│
├─ quickAskIncludeClipboard = true
│  └─ ClipboardHistoryService.getHistoryForContext(limit: 5)
│     └─ 添加 "剪贴板" 到 contextSources
│
└─ quickAskIncludeLiveCaption = true
   └─ LiveCaptionManager.getOriginalTextHistory(limit: quickAskLiveCaptionLimit)
      └─ 添加 "实时字幕" 到 contextSources
```

---

## 常见问题

### Q1: 为什么 quickAskIncludeScreenshot 默认关闭？

**A**: 截图捕获有性能开销，且需要屏幕录制权限。默认关闭避免意外开销和权限请求。

### Q2: quickAskLiveCaptionLimit 设置为 0 会怎样？

**A**: 0 表示全量，不限制字幕数量。可能导致 prompt 过长，影响 LLM 性能。

### Q3: quickAskIncludeClipboard 依赖 clipboardHistoryEnabled 吗？

**A**: 不依赖。`ClipboardHistoryService` 在应用启动时自动启动，Quick Ask 直接读取历史，不检查 `clipboardHistoryEnabled` 开关。

### Q4: 多个上下文来源可以同时开启吗？

**A**: 可以。所有配置项独立，可以任意组合。

### Q5: 如何验证配置是否生效？

**A**: 查看日志中的 `sources:` 字段，或在 Answer Panel 查看上下文来源标记。

---

## 相关文档

- [配置索引](./configuration-index.md)
- [功能流视图](./ui-ux-optimization-feature-flow.md)
- [Quick Ask 设计文档](../design-quick-ask.md)
