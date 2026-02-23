# General Settings 配置详细文档

> 版本: v1.0
> 创建时间: 2026-02-23
> 用途: General Settings 功能的所有配置项详细说明
> 复核基准工作树: /Users/bigdan/Workspace/macos/spokeanywhere

---

## 配置项总览

General Settings 功能共有 10 个配置项，控制应用启动行为、UI 显示、录音交互、音频设置等：

| setting_key | owner | read-path | write-path | 生效语义 | dependencies | side_effects |
|-------------|-------|-----------|------------|----------|--------------|--------------|
| `startAtLogin` | AppSettings.swift:57 | AppSettings.swift:58-66 (didSet) | GeneralSettingsContent.swift:22 | 即时 | SMAppService | 登录项注册/注销 |
| `showInDock` | AppSettings.swift:69 | AppSettings.swift:70-77 (didSet) | GeneralSettingsContent.swift:30 | 即时 | NSApp.setActivationPolicy | Dock 图标显示/隐藏 |
| `showInMenuBar` | AppSettings.swift:79 | 当前未消费 | GeneralSettingsContent.swift:38 | 配置已定义 | 无 | 菜单栏图标显示/隐藏（UI 可配置，运行时未接入） |
| `pressEscToCancel` | AppSettings.swift:80 | 当前未消费 | GeneralSettingsContent.swift:46 | 配置已定义 | 无 | Esc 键取消录音（UI 可配置，运行时未接入） |
| `playSoundEffect` | AppSettings.swift:81 | 当前未消费 | GeneralSettingsContent.swift:54 | 配置已定义 | 无 | 音效播放（UI 可配置，运行时未接入） |
| `recordingMode` | AppSettings.swift:82 | 当前未消费 | ShortcutsSettingsContent.swift:70 | 配置已定义 | 无 | 录音触发模式（UI 可配置，运行时未接入） |
| `realtimeTypingEnabled` | AppSettings.swift:88 | RecordingController.swift:137, 247 | ShortcutsSettingsContent.swift:91 + AISettingsContent.swift:46 | 即时 | InputService | 实时打字输出 |
| `clipboardHistoryEnabled` | AppSettings.swift:93 | 当前未消费 | **UI 未实现** | 配置已定义 | 无 | 剪贴板历史记录（服务无条件启动） |
| `clipboardHistoryLimit` | AppSettings.swift:96 | ClipboardHistoryService.swift:141 | **UI 未实现** | 即时 | clipboardHistoryEnabled | 历史条数限制 |
| `startupDiagnosticsEnabled` | AppSettings.swift:102 | AppDelegate.swift:51 | **UI 未实现** | 重启 | 无 | 启动诊断日志 |

---

## 配置项详细说明

由于 General Settings 包含 10 个配置项，完整文档较长。本文档采用简化格式，重点说明关键信息。


### 1. startAtLogin

**类型**: Bool | **默认值**: false | **位置**: AppSettings.swift:57
**持久化**: UserDefaults (`StartAtLogin`)

**读取入口**: AppSettings.swift:58-66 (didSet)
```swift
didSet {
    if #available(macOS 13.0, *) {
        if startAtLogin {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }
}
```

**写入入口**: GeneralSettingsContent.swift:22
```swift
Toggle("", isOn: $appSettings.startAtLogin)
```

**生效时机**: 即时生效 - Toggle 切换后立即注册/注销登录项

**依赖与联动**:
- 前置依赖: SMAppService (macOS 13.0+)
- 跨模块影响: 系统登录项设置

**副作用与回退**:
- 开启: 注册到系统登录项
- 关闭: 从系统登录项注销
- 兼容性: macOS 13.0+ 支持

**验证方式**:
1. 打开设置 → General
2. 切换 "开机自动启动"
3. 检查系统偏好设置 → 用户与群组 → 登录项

---

### 2. showInDock

**类型**: Bool | **默认值**: true | **位置**: AppSettings.swift:69
**持久化**: UserDefaults (`ShowInDock`)

**读取入口**: AppSettings.swift:70-77 (didSet)
```swift
didSet {
    if showInDock {
        NSApp.setActivationPolicy(.regular)
    } else {
        NSApp.setActivationPolicy(.accessory)
    }
}
```

**写入入口**: GeneralSettingsContent.swift:30
```swift
Toggle("", isOn: $appSettings.showInDock)
```

**生效时机**: 即时生效 - Toggle 切换后立即显示/隐藏 Dock 图标

**依赖与联动**:
- 前置依赖: NSApp.setActivationPolicy
- 跨模块影响: Dock 图标显示状态

**副作用与回退**:
- 开启: Dock 显示图标 (.regular)
- 关闭: Dock 隐藏图标 (.accessory)

**验证方式**:
1. 打开设置 → General
2. 切换 "在程序坞中显示"
3. 观察 Dock 图标变化

---

### 3. showInMenuBar

**类型**: Bool | **默认值**: true | **位置**: AppSettings.swift:79
**持久化**: UserDefaults (`ShowInMenuBar`)

**读取入口**: 当前未消费（配置已定义，运行时未接入）

**写入入口**: GeneralSettingsContent.swift:38
```swift
Toggle("", isOn: $appSettings.showInMenuBar)
```

**生效时机**: 配置已定义 - UI 可配置但运行时未接入消费链路

**依赖与联动**:
- 前置依赖: 无
- 跨模块影响: 无（当前未接入）
- 说明: AppDelegate.swift:308 创建状态栏项路径未检查此开关

**副作用与回退**:
- 当前状态: 菜单栏图标始终显示（未受此配置控制）

**验证方式**:
1. 打开设置 → General
2. 切换 "在菜单栏中显示图标"
3. 观察配置已保存但菜单栏图标不变化（当前未接入）

---

### 4. pressEscToCancel

**类型**: Bool | **默认值**: true | **位置**: AppSettings.swift:80
**持久化**: UserDefaults (`PressEscToCancel`)

**读取入口**: 当前未消费（配置已定义，运行时未接入）

**写入入口**: GeneralSettingsContent.swift:46
```swift
Toggle("", isOn: $appSettings.pressEscToCancel)
```

**生效时机**: 配置已定义 - UI 可配置但运行时未接入消费链路

**依赖与联动**:
- 前置依赖: 无
- 跨模块影响: 无（当前未接入）

**副作用与回退**:
- 当前状态: 配置可保存但未影响录音取消行为

**验证方式**:
1. 打开设置 → General
2. 切换 "按 ESC 键取消录音"
3. 观察配置已保存但行为未变化（当前未接入）

---

### 5. playSoundEffect

**类型**: Bool | **默认值**: true | **位置**: AppSettings.swift:81
**持久化**: UserDefaults (`PlaySoundEffect`)

**读取入口**: 当前未消费（配置已定义，运行时未接入）

**写入入口**: GeneralSettingsContent.swift:54
```swift
Toggle("", isOn: $appSettings.playSoundEffect)
```

**生效时机**: 配置已定义 - UI 可配置但运行时未接入消费链路

**依赖与联动**:
- 前置依赖: 无
- 跨模块影响: 无（当前未接入）

**副作用与回退**:
- 当前状态: 配置可保存但未影响音效播放行为

**验证方式**:
1. 打开设置 → General
2. 切换 "播放提示音效"
3. 观察配置已保存但行为未变化（当前未接入）

---

### 6. recordingMode

**类型**: RecordingMode (enum) | **默认值**: .mixed | **位置**: AppSettings.swift:82
**持久化**: UserDefaults (`RecordingMode`)

**读取入口**: 当前未消费（配置已定义，运行时未接入）

**写入入口**: ShortcutsSettingsContent.swift:70
```swift
Picker("", selection: $appSettings.recordingMode) {
    ForEach(AppSettings.RecordingMode.allCases) { mode in
        Text(mode.displayName).tag(mode)
    }
}
```

**生效时机**: 配置已定义 - UI 可配置但运行时未接入消费链路

**依赖与联动**:
- 前置依赖: 无
- 跨模块影响: 无（当前未接入）
- 说明: 仅定义、UI 绑定和测试，无运行时消费点

**副作用与回退**:
- 当前状态: 配置可保存但未影响录音触发模式

**验证方式**:
1. 打开设置 → Shortcuts（注意：不在 General）
2. 选择录音模式
3. 观察配置已保存但行为未变化（当前未接入）

---

### 7. realtimeTypingEnabled

**类型**: Bool | **默认值**: false | **位置**: AppSettings.swift:88
**持久化**: UserDefaults (`RealtimeTypingEnabled`)

**读取入口**: RecordingController.swift:137, 247

```swift
// RecordingController.swift:137 - 录音过程中实时打字
if self.settings.realtimeTypingEnabled {
    self.inputService.typeWithStabilityDetection(
        finalizedText: result.finalizedText,
        volatileText: result.volatileText
    )
}

// RecordingController.swift:247 - 录音结束时刷新待输入文本
if settings.realtimeTypingEnabled {
    inputService.flushPendingText()
}
```

**写入入口**: ShortcutsSettingsContent.swift:91 + AISettingsContent.swift:46（冲突回写）
```swift
// ShortcutsSettingsContent.swift:91
Toggle("", isOn: $appSettings.realtimeTypingEnabled)

// AISettingsContent.swift:46 - 冲突检测逻辑
if appSettings.realtimeTypingEnabled {
    // 回写关闭以避免冲突
}
```

**生效时机**: 即时生效 - 录音过程中实时检查此配置

**依赖与联动**:
- 前置依赖: InputService 必须可用
- 跨模块影响: 影响 RecordingController 的实时打字行为
- 说明: 录音过程中每次收到部分结果时检查此开关

**副作用与回退**:
- 开启时: 录音过程中实时输入稳定文本，录音结束时刷新待输入文本
- 关闭时: 不执行实时打字，仅在录音结束后输入完整文本

**验证方式**:
1. 打开设置 → Shortcuts（注意：不在 General）
2. 开启 "边说边打字"
3. 按下录音快捷键并说话
4. 观察文本实时输入到当前应用

---

### 8. clipboardHistoryEnabled

**类型**: Bool | **默认值**: false | **位置**: AppSettings.swift:93
**持久化**: UserDefaults (`ClipboardHistoryEnabled`)

**读取入口**: 当前未消费（配置已定义，运行时未接入）

**写入入口**: **UI 未实现**

**生效时机**: 配置已定义 - 但 UI 未暴露且运行时未接入消费链路

**依赖与联动**:
- 前置依赖: 无
- 跨模块影响: 无（当前未接入）
- 说明: ClipboardHistoryService 在 AppDelegate.swift:72 无条件启动，不检查此开关

**副作用与回退**:
- 当前状态: 剪贴板服务始终启动（未受此配置控制）

**验证方式**:
```bash
# 通过 UserDefaults 修改配置
defaults write com.spokeanywhere ClipboardHistoryEnabled -bool true
# 重启应用
# 观察服务仍无条件启动（当前未接入）
```

---

### 9. clipboardHistoryLimit

**类型**: Int | **默认值**: 30 | **位置**: AppSettings.swift:96
**持久化**: UserDefaults (`ClipboardHistoryLimit`)

**读取入口**: ClipboardHistoryService.swift:141

```swift
// ClipboardHistoryService.swift:141 - 添加剪贴板项时限制条数
let limit = AppSettings.shared.clipboardHistoryLimit
if history.count > limit {
    history = Array(history.prefix(limit))
}
```

**写入入口**: **UI 未实现**

**生效时机**: 即时生效 - 每次添加剪贴板项时检查并裁剪

**依赖与联动**:
- 前置依赖: ClipboardHistoryService 必须已启动
- 跨模块影响: 影响剪贴板历史记录的最大保留数量

**副作用与回退**:
- 数值越小: 保留历史越少，内存占用越小
- 数值越大: 保留历史越多，内存占用越大

**验证方式**:
```bash
# 通过 UserDefaults 修改配置
defaults write com.spokeanywhere ClipboardHistoryLimit -int 5
# 重启应用
# 复制多个文本项（超过 5 个）
# 检查剪贴板历史仅保留最新 5 条
```

---

### 10. startupDiagnosticsEnabled

**类型**: Bool | **默认值**: false | **位置**: AppSettings.swift:102
**持久化**: UserDefaults (`StartupDiagnosticsEnabled`)

**读取入口**: AppDelegate.swift:51

```swift
// AppDelegate.swift:51 - 启动阶段读取开关控制日志输出
let envEnabled = ProcessInfo.processInfo.environment["SPOKE_STARTUP_LOG"] == "1"
let settingsEnabled = AppSettings.shared.startupDiagnosticsEnabled

if envEnabled || settingsEnabled {
    let totalTime = (CFAbsoluteTimeGetCurrent() - launchStart) * 1000
    logger.info("🚀 \(name) [\(String(format: "%.0f", totalTime))ms]")
}
```

**写入入口**: **UI 未实现**

**生效时机**: 重启生效 - 应用启动时读取此配置控制诊断日志输出

**依赖与联动**:
- 前置依赖: 无
- 跨模块影响: 影响应用启动阶段的日志输出详细程度

**副作用与回退**:
- 开启时: 启动阶段输出详细的步骤耗时日志（🚀 Step X [Xms]）
- 关闭时: 不输出启动诊断日志（除非环境变量 SPOKE_STARTUP_LOG=1）

**验证方式**:
```bash
# 通过 UserDefaults 修改配置
defaults write com.spokeanywhere StartupDiagnosticsEnabled -bool true
# 重启应用
# 查看日志确认启动诊断信息
log show --predicate 'subsystem == "com.spokeanywhere" AND category == "Launch"' \
    --style syslog --last 1m | grep "🚀"
```

---

## 相关文档

- [配置索引](./configuration-index.md)
- [功能流视图](./ui-ux-optimization-feature-flow.md)
- [History Cleanup 配置](./config-history.md)
- [Quick Ask 配置](./config-quickask.md)

