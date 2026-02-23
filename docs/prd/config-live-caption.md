# Live Caption 配置详细文档

> 版本: v1.0
> 创建时间: 2026-02-23
> 用途: Live Caption 功能的所有配置项详细说明
> 复核基准工作树: /Users/bigdan/Workspace/macos/spokeanywhere

---

## 配置项总览

Live Caption 功能共有 4 个配置项，控制实时字幕的语言和显示行为：

| setting_key | owner | read-path | write-path | 生效语义 | dependencies | side_effects |
|-------------|-------|-----------|------------|----------|--------------|--------------|
| `liveCaptionTargetLanguage` | AppSettings.swift:292 | N/A (当前未消费) | N/A (UI 未暴露/未接线) | 配置已定义 | 无 | 配置链路断裂（LiveCaptionManager 使用独立配置） |
| `liveCaptionSourceLanguage` | AppSettings.swift:295 | N/A (当前未消费) | N/A (UI 未暴露/未接线) | 配置已定义 | 无 | 配置链路断裂（LiveCaptionManager 使用独立配置） |
| `liveCaptionShowOriginal` | AppSettings.swift:298 | N/A (当前未消费) | N/A (UI 未暴露/未接线) | 配置已定义 | 无 | 配置链路断裂（LiveCaptionManager 使用独立配置） |
| `liveCaptionTranslationEnabled` | AppSettings.swift:301 | N/A (当前未消费) | N/A (UI 未暴露/未接线) | 配置已定义 | 无 | 配置链路断裂（LiveCaptionManager 使用独立配置） |

---

## 配置项详细说明

### 1. liveCaptionTargetLanguage

**类型**: String | **默认值**: "zh-Hans" | **位置**: AppSettings.swift:292
**持久化**: UserDefaults (`LiveCaptionTargetLanguage`)

**读取入口**: 当前未消费（配置链路断裂）

**配置链路断裂说明**:
- AppSettings 定义了此配置项并持久化到 UserDefaults
- LiveCaptionManager 使用独立的 @AppStorage 配置项 `LiveCaptionLocale`（LiveCaptionManager.swift:70）
- LiveCaptionManager 未读取 AppSettings 中的 `liveCaptionTargetLanguage`
- 当前代码中**未找到任何消费点**读取此配置

**写入入口**: **UI 未实现**

**生效时机**: 配置已定义 - 但配置链路断裂且无消费点，完全未接入运行时

**依赖与联动**:
- 前置依赖: 无（配置链路断裂）
- 跨模块影响: 无（当前未接入）
- 说明: LiveCaptionManager 使用 `LiveCaptionLocale` 作为源语言配置

**副作用与回退**:
- 当前状态: LiveCaptionManager 使用 `LiveCaptionLocale` 配置（默认 "en-US"）
- 修改 UserDefaults 不会影响运行时行为

**验证方式**:
```bash
# 通过 UserDefaults 修改配置（当前无效）
defaults write com.spokeanywhere LiveCaptionTargetLanguage -string "ja-JP"
# 重启应用
# 观察 LiveCaptionManager 仍使用 LiveCaptionLocale 配置（配置未生效）
```

---

### 2. liveCaptionSourceLanguage

**类型**: String | **默认值**: "en-US" | **位置**: AppSettings.swift:295
**持久化**: UserDefaults (`LiveCaptionSourceLanguage`)

**读取入口**: 当前未消费（配置链路断裂）

**配置链路断裂说明**:
- AppSettings 定义了此配置项并持久化到 UserDefaults
- LiveCaptionManager 使用独立的 @AppStorage 配置项 `LiveCaptionLocale`（LiveCaptionManager.swift:70）
- LiveCaptionManager 未读取 AppSettings 中的 `liveCaptionSourceLanguage`
- 当前代码中**未找到任何消费点**读取此配置

**写入入口**: **UI 未实现**

**生效时机**: 配置已定义 - 但配置链路断裂且无消费点，完全未接入运行时

**依赖与联动**:
- 前置依赖: 无（配置链路断裂）
- 跨模块影响: 无（当前未接入）
- 说明: LiveCaptionManager 使用 `LiveCaptionLocale` 作为源语言配置

**副作用与回退**:
- 当前状态: LiveCaptionManager 使用 `LiveCaptionLocale` 配置（默认 "en-US"）
- 修改 UserDefaults 不会影响运行时行为

**验证方式**:
```bash
# 通过 UserDefaults 修改配置（当前无效）
defaults write com.spokeanywhere LiveCaptionSourceLanguage -string "zh-Hans"
# 重启应用
# 观察 LiveCaptionManager 仍使用 LiveCaptionLocale 配置（配置未生效）
```

---

### 3. liveCaptionShowOriginal

**类型**: Bool | **默认值**: true | **位置**: AppSettings.swift:298
**持久化**: UserDefaults (`LiveCaptionShowOriginal`)

**读取入口**: 当前未消费（配置链路断裂）

**配置链路断裂说明**:
- AppSettings 定义了此配置项并持久化到 UserDefaults
- LiveCaptionManager 使用 @Published 属性 `showOriginal`（LiveCaptionManager.swift:63）
- `showOriginal` 是运行时状态，未持久化到 UserDefaults
- LiveCaptionManager 未读取 AppSettings 中的 `liveCaptionShowOriginal`
- 当前代码中**未找到任何消费点**读取此配置

**写入入口**: **UI 未实现**

**生效时机**: 配置已定义 - 但配置链路断裂且无消费点，完全未接入运行时

**依赖与联动**:
- 前置依赖: 无（配置链路断裂）
- 跨模块影响: 无（当前未接入）
- 说明: LiveCaptionManager 使用 @Published 属性 `showOriginal`（未持久化）

**副作用与回退**:
- 当前状态: LiveCaptionManager 使用 @Published 属性 `showOriginal`（默认 true，每次启动重置）
- 修改 UserDefaults 不会影响运行时行为

**验证方式**:
```bash
# 通过 UserDefaults 修改配置（当前无效）
defaults write com.spokeanywhere LiveCaptionShowOriginal -bool false
# 重启应用
# 观察 LiveCaptionManager 仍使用 @Published 属性默认值 true（配置未生效）
```

---

### 4. liveCaptionTranslationEnabled

**类型**: Bool | **默认值**: true | **位置**: AppSettings.swift:301
**持久化**: UserDefaults (`LiveCaptionTranslationEnabled`)

**读取入口**: 当前未消费（配置链路断裂）

**配置链路断裂说明**:
- AppSettings 定义了此配置项并持久化到 UserDefaults
- LiveCaptionManager 使用 @Published 属性 `translationEnabled`（LiveCaptionManager.swift:66）
- `translationEnabled` 是运行时状态，未持久化到 UserDefaults
- LiveCaptionManager 未读取 AppSettings 中的 `liveCaptionTranslationEnabled`
- 当前代码中**未找到任何消费点**读取此配置

**写入入口**: **UI 未实现**

**生效时机**: 配置已定义 - 但配置链路断裂且无消费点，完全未接入运行时

**依赖与联动**:
- 前置依赖: 无（配置链路断裂）
- 跨模块影响: 无（当前未接入）
- 说明: LiveCaptionManager 使用 @Published 属性 `translationEnabled`（未持久化）

**副作用与回退**:
- 当前状态: LiveCaptionManager 使用 @Published 属性 `translationEnabled`（默认 true，每次启动重置）
- 修改 UserDefaults 不会影响运行时行为

**验证方式**:
```bash
# 通过 UserDefaults 修改配置（当前无效）
defaults write com.spokeanywhere LiveCaptionTranslationEnabled -bool false
# 重启应用
# 观察 LiveCaptionManager 仍使用 @Published 属性默认值 true（配置未生效）
```

---

## 配置依赖关系图

```
Live Caption 配置链路（当前状态）

AppSettings 配置（未消费）
├─ liveCaptionTargetLanguage
├─ liveCaptionSourceLanguage
├─ liveCaptionShowOriginal
└─ liveCaptionTranslationEnabled
   └─ ❌ 配置链路断裂（未被 LiveCaptionManager 读取）

LiveCaptionManager 实际使用的配置
├─ LiveCaptionLocale (@AppStorage)
│  └─ 持久化到 UserDefaults ("LiveCaptionLocale")
├─ LiveCaptionCaptureMode (@AppStorage)
│  └─ 持久化到 UserDefaults ("LiveCaptionCaptureMode")
├─ showOriginal (@Published)
│  └─ 运行时状态，未持久化
└─ translationEnabled (@Published)
   └─ 运行时状态，未持久化
```

---

## 运行时实际配置（LiveCaptionManager）

**说明**: 以下配置项是 LiveCaptionManager 实际使用的配置，与 AppSettings 中定义的配置项独立。

### LiveCaptionLocale

**类型**: String | **默认值**: "en-US" | **位置**: LiveCaptionManager.swift:70
**持久化**: UserDefaults (`LiveCaptionLocale`)

**读取入口**: LiveCaptionManager.swift:92-94 (sourceLanguage 计算属性)

```swift
// LiveCaptionManager.swift:92-94
var sourceLanguage: String {
    captionLocale
}
```

**实际消费点**: LiveCaptionManager.swift:326-328

**写入入口**: LiveCaptionToolbar.swift:92-94

**生效时机**: 即时生效 - @AppStorage 自动同步到 UserDefaults

**验证方式**:
```bash
# 通过 UserDefaults 修改配置
defaults write com.spokeanywhere LiveCaptionLocale -string "zh-Hans"
# 重启应用
# 观察 LiveCaptionManager 使用新的语言配置
```

---

### LiveCaptionCaptureMode

**类型**: String | **默认值**: "global" | **位置**: LiveCaptionManager.swift:75
**持久化**: UserDefaults (`LiveCaptionCaptureMode`)

**读取入口**: LiveCaptionManager.swift:75

**实际消费点**:
- LiveCaptionManager.swift:222 - 启动音频捕获
- LiveCaptionManager.swift:463 - 切换捕获模式
- LiveCaptionManager.swift:490 - 应用选择器

**写入入口**: TranscriptionModelSettingsView.swift:146-163

**生效时机**: 重启实时字幕后生效 - 配置变更后需重新启动 Live Caption 才会应用新的捕获模式

**说明**: 设置页明确提示"切换模式后需重新启动实时字幕生效"（TranscriptionModelSettingsView.swift:180）。captureMode 在启动路径选择捕获模式（LiveCaptionManager.swift:222），非热切换。

**验证方式**:
```bash
# 通过 UserDefaults 修改配置
defaults write com.spokeanywhere LiveCaptionCaptureMode -string "appPicker"
# 重启应用或重新启动实时字幕
# 观察 LiveCaptionManager 使用新的捕获模式
```

---

### showOriginal

**类型**: Bool | **默认值**: true | **位置**: LiveCaptionManager.swift:63
**持久化**: 无（@Published 属性，运行时状态）

**读取入口**: 当前未检出有效消费点

**写入入口**: N/A (UI 未暴露/未接线)

**生效时机**: 运行时内存态 - 每次启动重置为默认值

**说明**: 此配置项定义为 @Published 属性，未持久化到 UserDefaults，每次启动重置为 true

---

### translationEnabled

**类型**: Bool | **默认值**: true | **位置**: LiveCaptionManager.swift:66
**持久化**: 无（@Published 属性，运行时状态）

**读取入口**:
- LiveCaptionManager.swift:689 - 翻译逻辑
- LiveCaptionManager.swift:714 - 翻译逻辑
- LiveCaptionView.swift:130 - UI 显示
- LiveCaptionView.swift:161 - UI 显示

**写入入口**: N/A (UI 未暴露/未接线)

**生效时机**: 运行时内存态 - 每次启动重置为默认值

**说明**: 此配置项定义为 @Published 属性，未持久化到 UserDefaults，每次启动重置为 true

---

## 常见问题

### Q1: 为什么 AppSettings 中的 Live Caption 配置项无法生效？

**A**: 这 4 个配置项存在配置链路断裂问题：
- AppSettings 定义并持久化到 UserDefaults
- LiveCaptionManager 使用自己的独立配置项（`LiveCaptionLocale`, `LiveCaptionCaptureMode`, `showOriginal`, `translationEnabled`）
- 运行时完全不读取 AppSettings 中的配置
- 需要重构 LiveCaptionManager 以使用 AppSettings 配置

### Q2: LiveCaptionManager 实际使用的配置是什么？

**A**: LiveCaptionManager 使用以下独立配置：
- `LiveCaptionLocale` (@AppStorage) - 源语言配置，持久化到 UserDefaults
- `LiveCaptionCaptureMode` (@AppStorage) - 音频捕获模式，持久化到 UserDefaults
- `showOriginal` (@Published) - 是否显示原文，运行时状态（未持久化）
- `translationEnabled` (@Published) - 是否启用翻译，运行时状态（未持久化）

### Q3: 如何修复配置链路断裂问题？

**A**: 需要重构 LiveCaptionManager 以使用 AppSettings 配置：
```swift
// LiveCaptionManager.swift 中
private let settings = AppSettings.shared

// 替换独立配置
var sourceLanguage: String {
    settings.liveCaptionSourceLanguage
}

var targetLanguage: String {
    settings.liveCaptionTargetLanguage
}

var showOriginal: Bool {
    get { settings.liveCaptionShowOriginal }
    set { settings.liveCaptionShowOriginal = newValue }
}

var translationEnabled: Bool {
    get { settings.liveCaptionTranslationEnabled }
    set { settings.liveCaptionTranslationEnabled = newValue }
}
```

### Q4: 为什么没有 UI 控件配置这些选项？

**A**: 当前版本未实现 Live Caption 专用的设置视图。配置项已定义但 UI 控件和配置接线将在后续版本中添加。

### Q5: 配置链路断裂是否影响功能使用？

**A**: 不影响基本功能使用，但用户无法持久化某些配置：
- 源语言配置可通过 `LiveCaptionLocale` 持久化
- 音频捕获模式可通过 `LiveCaptionCaptureMode` 持久化
- 显示原文和翻译开关每次启动重置为默认值（true）

---

## 相关文档

- [配置索引](./configuration-index.md)
- [功能流视图](./ui-ux-optimization-feature-flow.md)
- [General Settings 配置](./config-general.md)
- [Shortcuts 配置](./config-shortcuts.md)
