# LLM Settings 配置详细文档

> 版本: v1.0
> 创建时间: 2026-02-23
> 用途: LLM Settings 功能的所有配置项详细说明
> 复核基准工作树: /Users/bigdan/Workspace/macos/spokeanywhere

---

## 配置项总览

LLM Settings 功能共有 13 个配置项，控制 AI 处理的启用状态、Profile 配置和行为参数：

| setting_key | owner | read-path | write-path | 生效语义 | dependencies | side_effects |
|-------------|-------|-----------|------------|----------|--------------|--------------|
| `isEnabled` | LLMSettings.swift:84 | LLMSettings.swift:228, RecordingController.swift:209 | AISettingsContent.swift:31-36 | 即时 | 无 | LLM 处理总开关 |
| `profiles` | LLMSettings.swift:101 | LLMSettings.swift:58-104, WorkflowExecutor.swift:80-104 | AISettingsContent.swift:58-100 | 即时 | 无 | Profile 配置列表 |
| `selectedProfileId` | LLMSettings.swift:106 | LLMSettings.swift:111-113, WorkflowExecutor.swift:101-102 | AISettingsContent.swift:81 | 即时 | profiles | 默认 Profile |
| `systemPrompt` | LLMSettings.swift:122 | LLMSettings.swift:327 | AISettingsCards.swift:119-122 | 即时 | 无 | 系统提示词 |
| `includeClipboard` | LLMSettings.swift:127 | LLMSettings.swift:328 | AISettingsCards.swift:131-134 | 即时 | 无 | 上下文收集 |
| `includeActiveApp` | LLMSettings.swift:132 | RecordingController.swift:209 | AISettingsCards.swift:143-146 | 即时 | 无 | 上下文收集 |
| `temperature` | LLMSettings.swift:137 | N/A (运行时用 profile.temperature) | N/A (UI 未暴露/未接线) | 配置已定义 | 无 | 全局键（运行时未接线） |
| `timeout` | LLMSettings.swift:142 | N/A (硬编码 30 秒) | N/A (UI 未暴露/未接线) | 配置已定义 | 无 | 全局键（运行时未接线） |
| `aiGeneratedTitleEnabled` | LLMSettings.swift:147 | LLMSettings.swift:693 | AISettingsCards.swift:83-84 | 即时 | isEnabled | 标题生成开关 |
| `summaryAutoEnabled` | LLMSettings.swift:169 | MessagePanelState.swift:728 | AISettingsCards.swift:95-98 | 即时 | isEnabled | 自动摘要开关 |
| `transcriptionProfileId` | LLMSettings.swift:154 | N/A (当前未消费) | AISettingsContent.swift:84 | 配置已定义 | profiles | 转录专用 Profile（配置链路断裂） |
| `chatProfileId` | LLMSettings.swift:159 | WorkflowExecutor.swift:86-87, LLMSettings.swift:693 | AISettingsContent.swift:87 | 即时 | profiles | Workflow fast + AI 标题 |
| `summaryProfileId` | LLMSettings.swift:164 | LLMSettings.swift:213-215, WorkflowExecutor.swift:90-91, SummaryService.swift:207 | AISettingsContent.swift:90 | 即时 | profiles | 摘要专用 Profile |

---

## 配置项详细说明

由于 LLM Settings 包含 13 个配置项，采用简化格式，重点说明关键信息。

### 1. isEnabled

**类型**: Bool | **默认值**: false | **位置**: LLMSettings.swift:84
**持久化**: UserDefaults (`llm.isEnabled`)

**读取入口**:
- LLMSettings.swift:228 - isFullyConfigured 计算属性
- RecordingController.swift:209 - 录音后 LLM 处理判断

**写入入口**: AISettingsContent.swift:31-36

```swift
Toggle("", isOn: Binding(
    get: { llmSettings.isEnabled },
    set: { newValue in
        if newValue && appSettings.realtimeTypingEnabled {
            showConflictAlert = true
        } else {
            llmSettings.isEnabled = newValue
        }
    }
))
```

**生效时机**: 即时生效 - didSet 触发 save()，立即持久化到 UserDefaults

**依赖与联动**:
- 前置依赖: 无
- 跨模块影响: 影响 RecordingController 是否执行 LLM 处理
- 联动配置: 与 realtimeTypingEnabled 冲突检测

**副作用与回退**:
- 开启时: 启用 LLM 处理流程
- 关闭时: 跳过 LLM 处理，仅输出原始转写
- 冲突检测: 与实时上屏功能冲突时显示警告

**验证方式**:
1. 打开设置 → AI Settings
2. 切换 "启用 AI 处理" 开关
3. 录音后观察是否执行 LLM 精炼

---

### 2. profiles

**类型**: [ProviderProfile] | **默认值**: [] | **位置**: LLMSettings.swift:101
**持久化**: UserDefaults (`llm.profiles`)

**读取入口**:
- LLMSettings.swift:58-104 - Profile 列表遍历
- WorkflowExecutor.swift:80-104 - 根据 modelHint 选择 Profile

**写入入口**: AISettingsContent.swift:58-100 - Profile 卡片列表

**生效时机**: 即时生效 - didSet 触发 save()，立即持久化到 UserDefaults

**依赖与联动**:
- 前置依赖: 无
- 跨模块影响: 影响所有 LLM Provider 创建
- 联动配置: selectedProfileId, transcriptionProfileId, chatProfileId, summaryProfileId

**副作用与回退**:
- 修改后: 所有依赖 Profile 的功能立即使用新配置
- 删除 Profile: 自动清除关联的 selectedProfileId

**验证方式**:
1. 打开设置 → AI Settings
2. 添加/编辑/删除 Profile
3. 观察 Profile 列表变化

---

### 3. selectedProfileId

**类型**: UUID? | **默认值**: nil | **位置**: LLMSettings.swift:106
**持久化**: UserDefaults (`llm.selectedProfileId`)

**读取入口**:
- LLMSettings.swift:111-113 - selectedProfile 计算属性
- WorkflowExecutor.swift:101-102 - 回退到默认 Profile

**写入入口**: AISettingsContent.swift:81

```swift
onSetActive: {
    llmSettings.selectedProfileId = profile.id
}
```

**生效时机**: 即时生效 - didSet 触发 save()，立即持久化到 UserDefaults

**依赖与联动**:
- 前置依赖: profiles 必须包含对应 Profile
- 跨模块影响: 影响默认 LLM Provider 选择
- 联动配置: profiles

**副作用与回退**:
- 修改后: 所有未指定 Profile 的 LLM 调用使用新 Profile
- Profile 被删除: 自动回退到 profiles.first

**验证方式**:
1. 打开设置 → AI Settings
2. 点击 Profile 卡片的 "设为默认" 按钮
3. 观察默认 Profile 标记变化

---

### 4. systemPrompt

**类型**: String | **默认值**: defaultSystemPrompt | **位置**: LLMSettings.swift:122
**持久化**: UserDefaults (`llm.systemPrompt`)

**读取入口**: LLMSettings.swift:327 - init 时加载

**写入入口**: AISettingsCards.swift:119-122

```swift
TextField("", text: Binding(
    get: { llmSettings.systemPrompt },
    set: { llmSettings.systemPrompt = $0 }
))
```

**生效时机**: 即时生效 - didSet 触发 save()，立即持久化到 UserDefaults

**依赖与联动**:
- 前置依赖: 无
- 跨模块影响: 影响所有 LLM 请求的系统提示词
- 联动配置: 无

**副作用与回退**:
- 修改后: 下次 LLM 调用使用新提示词
- 重置: 可通过 resetToDefaultPrompt() 恢复默认值

**验证方式**:
1. 打开设置 → AI Settings → 系统提示词
2. 修改提示词内容
3. 录音后观察 LLM 输出是否符合新提示词

---

### 5. includeClipboard

**类型**: Bool | **默认值**: false | **位置**: LLMSettings.swift:127
**持久化**: UserDefaults (`llm.includeClipboard`)

**读取入口**: LLMSettings.swift:328 - init 时加载

**写入入口**: AISettingsCards.swift:131-134

```swift
Toggle("", isOn: Binding(
    get: { llmSettings.includeClipboard },
    set: { llmSettings.includeClipboard = $0 }
))
```

**生效时机**: 即时生效 - didSet 触发 save()，立即持久化到 UserDefaults

**依赖与联动**:
- 前置依赖: 无
- 跨模块影响: 影响 LLM 上下文收集
- 联动配置: 无

**副作用与回退**:
- 开启时: LLM 请求包含剪贴板内容作为上下文
- 关闭时: LLM 请求不包含剪贴板内容

**验证方式**:
1. 打开设置 → AI Settings
2. 切换 "包含剪贴板内容" 开关
3. 复制文本后录音，观察 LLM 是否使用剪贴板上下文

---

### 6. includeActiveApp

**类型**: Bool | **默认值**: true | **位置**: LLMSettings.swift:132
**持久化**: UserDefaults (`llm.includeActiveApp`)

**读取入口**: RecordingController.swift:209

```swift
if LLMSettings.shared.includeActiveApp {
    // 收集当前活跃 App 名称
}
```

**写入入口**: AISettingsCards.swift:143-146

```swift
Toggle("", isOn: Binding(
    get: { llmSettings.includeActiveApp },
    set: { llmSettings.includeActiveApp = $0 }
))
```

**生效时机**: 即时生效 - didSet 触发 save()，立即持久化到 UserDefaults

**依赖与联动**:
- 前置依赖: 无
- 跨模块影响: 影响 RecordingController 上下文收集
- 联动配置: 无

**副作用与回退**:
- 开启时: LLM 请求包含当前活跃 App 名称
- 关闭时: LLM 请求不包含活跃 App 信息

**验证方式**:
1. 打开设置 → AI Settings
2. 切换 "包含当前应用名称" 开关
3. 在不同应用中录音，观察 LLM 是否使用应用上下文

---

### 7. temperature

**类型**: Double | **默认值**: 0.3 | **位置**: LLMSettings.swift:137
**持久化**: UserDefaults (`llm.temperature`)

**读取入口**: N/A (运行时用 profile.temperature)

**配置链路断裂说明**:
- 全局 temperature 配置可持久化到 UserDefaults
- 运行时 Provider 使用 `profile.temperature`（OpenAICompatibleProvider.swift:37-39）
- 全局配置未接入运行时链路

```swift
// OpenAICompatibleProvider.swift:37-39
private var temperature: Double {
    profile?.temperature ?? 0.3
}
```

**写入入口**: N/A (UI 未暴露/未接线)

**生效时机**: 配置已定义 - 但运行时使用 Profile 级别配置，全局配置未接线

**依赖与联动**:
- 前置依赖: 无
- 跨模块影响: 无（当前未接入）
- 联动配置: 无

**副作用与回退**:
- 当前状态: 运行时使用 Profile 级别的 temperature
- 修改全局配置不会影响运行时行为

**验证方式**:
```bash
# 通过 UserDefaults 修改配置（当前无效）
defaults write com.spokeanywhere llm.temperature -float 0.8
# 重启应用
# 观察运行时仍使用 Profile 级别配置（全局配置未生效）
```

---

### 8. timeout

**类型**: TimeInterval | **默认值**: 30 | **位置**: LLMSettings.swift:142
**持久化**: UserDefaults (`llm.timeout`)

**读取入口**: N/A (硬编码 30 秒)

**配置链路断裂说明**:
- 全局 timeout 配置可持久化到 UserDefaults
- 运行时 Provider 使用硬编码值 30 秒（OpenAICompatibleProvider.swift:20）
- 全局配置未接入运行时链路

```swift
// OpenAICompatibleProvider.swift:20
private let timeout: TimeInterval = 30
```

**写入入口**: N/A (UI 未暴露/未接线)

**生效时机**: 配置已定义 - 但运行时使用硬编码值，全局配置未接线

**依赖与联动**:
- 前置依赖: 无
- 跨模块影响: 无（当前未接入）
- 联动配置: 无

**副作用与回退**:
- 当前状态: 运行时固定使用 30 秒超时
- 修改全局配置不会影响运行时行为

**验证方式**:
```bash
# 通过 UserDefaults 修改配置（当前无效）
defaults write com.spokeanywhere llm.timeout -float 60
# 重启应用
# 观察运行时仍使用 30 秒超时（全局配置未生效）
```

---

### 9. aiGeneratedTitleEnabled

**类型**: Bool | **默认值**: false | **位置**: LLMSettings.swift:147
**持久化**: UserDefaults (`llm.aiGeneratedTitleEnabled`)

**读取入口**: LLMSettings.swift:693 - generateTitle 方法

```swift
guard aiGeneratedTitleEnabled,
      let profile = chatProfile ?? selectedProfile,
      let provider = createProvider(for: profile) else {
    return nil
}
```

**写入入口**: AISettingsCards.swift:83-84

```swift
Toggle("", isOn: Binding(
    get: { llmSettings.aiGeneratedTitleEnabled },
    set: { llmSettings.aiGeneratedTitleEnabled = $0 }
))
```

**生效时机**: 即时生效 - didSet 触发 save()，立即持久化到 UserDefaults

**依赖与联动**:
- 前置依赖: isEnabled 必须为 true
- 跨模块影响: 影响历史记录标题生成
- 联动配置: chatProfile, selectedProfile

**副作用与回退**:
- 开启时: 历史记录使用 AI 生成标题
- 关闭时: 历史记录使用默认标题（时间戳）

**验证方式**:
1. 打开设置 → AI Settings
2. 切换 "AI 生成标题" 开关
3. 录音后观察历史记录标题是否为 AI 生成

---

### 10. summaryAutoEnabled

**类型**: Bool | **默认值**: true | **位置**: LLMSettings.swift:169
**持久化**: UserDefaults (`llm.summaryAutoEnabled`)

**读取入口**: MessagePanelState.swift:728 - 切换记录类型时检查

```swift
// MessagePanelState.swift:728
let shouldAutoSummary = autoSummary ?? LLMSettings.shared.summaryAutoEnabled
```

**写入入口**: AISettingsCards.swift:95-98

```swift
Toggle("", isOn: Binding(
    get: { llmSettings.summaryAutoEnabled },
    set: { llmSettings.summaryAutoEnabled = $0 }
))
```

**生效时机**: 即时生效 - didSet 触发 save()，立即持久化到 UserDefaults

**依赖与联动**:
- 前置依赖: isEnabled 必须为 true
- 跨模块影响: 影响自动摘要生成
- 联动配置: summaryProfile, selectedProfile

**副作用与回退**:
- 开启时: 切换到 todo/note 时自动生成摘要
- 关闭时: 不自动生成摘要

**验证方式**:
1. 打开设置 → AI Settings
2. 切换 "自动生成摘要" 开关
3. 录音后切换到 todo/note，观察是否自动生成摘要

---

### 11. transcriptionProfileId

**类型**: UUID? | **默认值**: nil | **位置**: LLMSettings.swift:154
**持久化**: UserDefaults (`llm.transcriptionProfileId`)

**读取入口**: N/A (当前未消费)

**配置链路断裂说明**:
- LLMSettings.swift:201-203 定义了 transcriptionProfile 计算属性
- 当前代码中**未找到任何消费点**读取此配置
- UI 可设置 transcriptionProfileId，但运行时未使用

**写入入口**: AISettingsContent.swift:84

```swift
onSetTranscription: {
    llmSettings.transcriptionProfileId = profile.id
}
```

**生效时机**: 配置已定义 - 但配置链路断裂，修改 UserDefaults 不会影响运行时行为

**依赖与联动**:
- 前置依赖: profiles 必须包含对应 Profile
- 跨模块影响: 无（当前未接入）
- 联动配置: profiles

**副作用与回退**:
- 当前状态: 配置可持久化但运行时未消费
- 修改 UserDefaults 不会影响运行时行为

**验证方式**:
```bash
# 通过 UserDefaults 修改配置（当前无效）
defaults write com.spokeanywhere llm.transcriptionProfileId -string "UUID"
# 重启应用
# 观察运行时未使用此配置（配置未生效）
```

---

### 12. chatProfileId

**类型**: UUID? | **默认值**: nil | **位置**: LLMSettings.swift:159
**持久化**: UserDefaults (`llm.chatProfileId`)

**读取入口**:
- WorkflowExecutor.swift:86-87 - modelHint.fast 时选择
- LLMSettings.swift:693 - generateTitle 方法（AI 标题生成）

```swift
// WorkflowExecutor.swift:86-87
case .fast:
    if let id = llmSettings.chatProfileId {
        return llmSettings.profiles.first { $0.id == id }
    }

// LLMSettings.swift:693
guard aiGeneratedTitleEnabled,
      let profile = chatProfile ?? selectedProfile,
      let provider = createProvider(for: profile) else {
    return nil
}
```

**写入入口**: AISettingsContent.swift:87

**生效时机**: 即时生效 - didSet 触发 save()，立即持久化到 UserDefaults

**依赖与联动**:
- 前置依赖: profiles 必须包含对应 Profile
- 跨模块影响: 影响 Workflow fast 模型选择和 AI 标题生成
- 联动配置: profiles
- 说明: Quick Ask 主链路使用 selectedProfile（LLMPipeline.swift:52 → LLMSettings.swift:561）

**副作用与回退**:
- 修改后: Workflow fast 任务和 AI 标题生成使用新 Profile
- Profile 被删除: 回退到 selectedProfile

**验证方式**:
1. 打开设置 → AI Settings
2. 点击 Profile 卡片的 "设为对话模型" 按钮
3. 执行 Workflow fast 任务或生成 AI 标题，观察是否使用指定 Profile

---

### 13. summaryProfileId

**类型**: UUID? | **默认值**: nil | **位置**: LLMSettings.swift:164
**持久化**: UserDefaults (`llm.summaryProfileId`)

**读取入口**:
- LLMSettings.swift:213-215 - summaryProfile 计算属性
- WorkflowExecutor.swift:90-91 - modelHint.advanced 时选择
- SummaryService.swift:207 - 总结任务时选择

```swift
guard let profile = settings.summaryProfile ?? settings.selectedProfile,
      let provider = settings.createProvider(for: profile) else {
    return nil
}
```

**写入入口**: AISettingsContent.swift:90

```swift
onSetSummary: {
    llmSettings.summaryProfileId = profile.id
}
```

**生效时机**: 即时生效 - didSet 触发 save()，立即持久化到 UserDefaults

**依赖与联动**:
- 前置依赖: profiles 必须包含对应 Profile
- 跨模块影响: 影响摘要生成和 Workflow 高级模型选择
- 联动配置: profiles

**副作用与回退**:
- 修改后: 摘要任务和高级任务使用新 Profile
- Profile 被删除: 回退到 selectedProfile

**验证方式**:
1. 打开设置 → AI Settings
2. 点击 Profile 卡片的 "设为总结模型" 按钮
3. 生成摘要，观察是否使用指定 Profile

---

## 配置依赖关系图

```
LLM Settings 配置链路

isEnabled 变更
└─ didSet → save() → UserDefaults
   └─ RecordingController 检查 isEnabled
      └─ 决定是否执行 LLM 处理

profiles 变更
└─ didSet → save() → UserDefaults
   └─ 所有 Profile 引用立即更新
      ├─ selectedProfile
      ├─ transcriptionProfile
      ├─ chatProfile
      └─ summaryProfile

selectedProfileId 变更
└─ didSet → save() → UserDefaults
   └─ selectedProfile 计算属性更新
      └─ WorkflowExecutor 回退逻辑使用

transcriptionProfileId 变更
└─ didSet → save() → UserDefaults
   └─ transcriptionProfile 计算属性更新
      └─ ❌ 配置链路断裂（当前未消费）

chatProfileId 变更
└─ didSet → save() → UserDefaults
   └─ chatProfile 计算属性更新
      ├─ WorkflowExecutor.fast 模型选择
      └─ LLMSettings.generateTitle() AI 标题生成

summaryProfileId 变更
└─ didSet → save() → UserDefaults
   └─ summaryProfile 计算属性更新
      ├─ WorkflowExecutor.advanced 模型选择
      └─ SummaryService 摘要生成

systemPrompt/includeClipboard/includeActiveApp 变更
└─ didSet → save() → UserDefaults
   └─ 下次 LLM 调用使用新配置

temperature/timeout 变更
└─ didSet → save() → UserDefaults
   └─ ❌ 配置链路断裂（运行时用 profile.temperature 和硬编码 timeout=30）

aiGeneratedTitleEnabled 变更
└─ didSet → save() → UserDefaults
   └─ LLMSettings.generateTitle() 检查
      └─ 决定是否生成 AI 标题

summaryAutoEnabled 变更
└─ didSet → save() → UserDefaults
   └─ 切换到 todo/note 时检查
      └─ 决定是否自动生成摘要
```

---

## 常见问题

### Q1: Profile 系统与旧版配置的关系？

**A**: LLMSettings 同时维护新版 Profile 系统和旧版配置（providerConfigs）以保持向后兼容：
- 新版: profiles (数组) + selectedProfileId/transcriptionProfileId/chatProfileId/summaryProfileId
- 旧版: providerConfigs (字典) + selectedProviderType
- 迁移: init 时自动调用 migrateToProfiles() 将旧配置迁移到新 Profile 系统
- 推荐: 使用新版 Profile 系统，旧版 API 已标记为 deprecated

### Q2: 为什么有 3 个角色专用 Profile（transcription/chat/summary）？

**A**: 不同任务对 LLM 的要求不同：
- transcriptionProfileId: 配置已定义但当前未接入运行时（配置链路断裂）
- chatProfileId: Workflow fast 模型选择 + AI 标题生成（Quick Ask 使用 selectedProfile）
- summaryProfileId: 摘要生成，需要理解能力和简洁性
- 回退机制: 如果角色 Profile 未设置，自动回退到 selectedProfile

### Q3: temperature 和 timeout 配置如何生效？

**A**: 这两个全局配置存在配置链路断裂问题：
- temperature: 全局配置可持久化，但运行时使用 `profile.temperature`（OpenAICompatibleProvider.swift:37-39）
- timeout: 全局配置可持久化，但运行时使用硬编码值 30 秒（OpenAICompatibleProvider.swift:20）
- 当前状态: 全局配置未接入运行时链路
- 建议: 使用 Profile 级别的 temperature 配置；timeout 需要代码修改才能生效

### Q4: aiGeneratedTitleEnabled 和 summaryAutoEnabled 的区别？

**A**: 两者控制不同的 AI 功能：
- aiGeneratedTitleEnabled: 控制历史记录标题是否使用 AI 生成（默认 false）
- summaryAutoEnabled: 控制切换到 todo/note 时是否自动生成摘要（默认 true）
- 依赖: 两者都依赖 isEnabled = true
- Profile: aiGeneratedTitleEnabled 使用 chatProfile，summaryAutoEnabled 使用 summaryProfile

### Q5: 如何验证 Profile 配置是否正确？

**A**: LLMSettings 提供 isFullyConfigured 计算属性检查配置完整性：
- 检查 isEnabled = true
- 检查 selectedProfile 存在
- 检查 Profile 的 baseURL 和 modelName 非空
- 检查需要 API Key 的 Provider 是否已设置 API Key
- 使用: 在 UI 中显示配置状态，阻止未配置时的 LLM 调用

### Q6: includeClipboard 和 includeActiveApp 如何影响 LLM 上下文？

**A**: 这两个配置控制 LLM 请求的上下文收集：
- includeClipboard: 开启时，LLM 请求包含剪贴板内容作为上下文（用于术语消歧义）
- includeActiveApp: 开启时，LLM 请求包含当前活跃 App 名称（用于上下文感知）
- 实现: RecordingController 在录音后根据配置收集上下文
- 隐私: 用户可关闭这些选项以保护隐私

---

## 相关文档

- [配置索引](./configuration-index.md)
- [功能流视图](./ui-ux-optimization-feature-flow.md)
- [General Settings 配置](./config-general.md)
- [Shortcuts 配置](./config-shortcuts.md)
