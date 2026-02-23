# Shortcuts 配置详细文档

> 版本: v1.0
> 创建时间: 2026-02-23
> 用途: Shortcuts 功能的所有配置项详细说明
> 复核基准工作树: /Users/bigdan/Workspace/macos/spokeanywhere

---

## 配置项总览

Shortcuts 功能共有 10 个配置项，控制全局快捷键行为：

| setting_key | owner | read-path | write-path | 生效语义 | dependencies | side_effects |
|-------------|-------|-----------|------------|----------|--------------|-----------------|
| `shortcutKeyCode` | AppSettings.swift:118 | HotKeyService.swift:117, 136 | ShortcutsSettingsContent.swift:26 | 即时 | HotKeyService | NotificationCenter 通知 |
| `shortcutModifiers` | AppSettings.swift:123 | HotKeyService.swift:118, 136 | ShortcutsSettingsContent.swift:26 | 即时 | HotKeyService | NotificationCenter 通知 |
| `quickAskKeyCode` | AppSettings.swift:148 | HotKeyService.swift:119, 147 | ShortcutsSettingsContent.swift:38 | 即时 | HotKeyService | NotificationCenter 通知 |
| `quickAskModifiers` | AppSettings.swift:153 | HotKeyService.swift:120, 147 | ShortcutsSettingsContent.swift:38 | 即时 | HotKeyService | NotificationCenter 通知 |
| `messagePanelKeyCode` | AppSettings.swift:202 | HotKeyService.swift:121, 158 | N/A (UI 未实现) | 即时 | HotKeyService | NotificationCenter 通知 |
| `messagePanelModifiers` | AppSettings.swift:207 | HotKeyService.swift:122, 158 | N/A (UI 未实现) | 即时 | HotKeyService | NotificationCenter 通知 |
| `liveCaptionKeyCode` | AppSettings.swift:232 | HotKeyService.swift:123, 169 | N/A (UI 未实现) | 即时 | HotKeyService | NotificationCenter 通知 |
| `liveCaptionModifiers` | AppSettings.swift:237 | HotKeyService.swift:124, 169 | N/A (UI 未实现) | 即时 | HotKeyService | NotificationCenter 通知 |
| `screenshotKeyCode` | AppSettings.swift:262 | HotKeyService.swift:125, 180 | ShortcutsSettingsContent.swift:50 | 即时 | HotKeyService | NotificationCenter 通知 |
| `screenshotModifiers` | AppSettings.swift:267 | HotKeyService.swift:126, 180 | ShortcutsSettingsContent.swift:50 | 即时 | HotKeyService | NotificationCenter 通知 |

---

## 配置项详细说明

由于 Shortcuts 包含 10 个配置项（5 对快捷键），采用简化格式，重点说明关键信息。

### 1. shortcutKeyCode

**类型**: Int | **默认值**: 15 (kVK_ANSI_R) | **位置**: AppSettings.swift:118
**持久化**: UserDefaults (`ShortcutKeyCode`)

**读取入口**: HotKeyService.swift:117, 136

```swift
// HotKeyService.swift:117 - 初始化时加载
currentKeyCode = UInt32(settings.shortcutKeyCode)

// HotKeyService.swift:136 - 通知触发时重新加载
private func reloadShortcut() {
    let settings = AppSettings.shared
    currentKeyCode = UInt32(settings.shortcutKeyCode)
    // ...
}
```

**写入入口**: ShortcutsSettingsContent.swift:26

```swift
ShortcutRecorderButton(
    isRecording: $isRecordingShortcut,
    currentShortcut: appSettings.shortcutDisplayString,
    onShortcutCaptured: { keyCode, modifiers in
        appSettings.updateShortcut(keyCode: keyCode, modifiers: modifiers)
    }
)
```

**生效时机**: 即时生效 - didSet 触发 NotificationCenter 通知，HotKeyService 监听并重新加载

**依赖与联动**:
- 前置依赖: HotKeyService 必须已初始化
- 跨模块影响: 影响全局录音快捷键触发
- 联动配置: shortcutModifiers (必须配对使用)

**副作用与回退**:
- 修改后: 发送 `shortcutDidChangeNotification` 通知
- HotKeyService 接收通知后重新注册快捷键（unregister + register）
- 旧快捷键立即失效，新快捷键立即生效

**验证方式**:
1. 打开设置 → Shortcuts
2. 点击 "触发录音" 快捷键录制按钮
3. 按下新的快捷键组合
4. 测试新快捷键是否触发录音

---

### 2. shortcutModifiers

**类型**: Int | **默认值**: 524288 (NSEvent.ModifierFlags.option) | **位置**: AppSettings.swift:123
**持久化**: UserDefaults (`ShortcutModifiers`)

**读取入口**: HotKeyService.swift:118, 136

```swift
// HotKeyService.swift:118 - 初始化时加载
currentModifiers = NSEvent.ModifierFlags(rawValue: UInt(settings.shortcutModifiers))

// HotKeyService.swift:136 - 通知触发时重新加载
private func reloadShortcut() {
    let settings = AppSettings.shared
    currentModifiers = NSEvent.ModifierFlags(rawValue: UInt(settings.shortcutModifiers))
    // ...
}
```

**写入入口**: ShortcutsSettingsContent.swift:26 (与 shortcutKeyCode 同一控件)

**生效时机**: 即时生效 - didSet 触发 NotificationCenter 通知，HotKeyService 监听并重新加载

**依赖与联动**:
- 前置依赖: HotKeyService 必须已初始化
- 跨模块影响: 影响全局录音快捷键触发
- 联动配置: shortcutKeyCode (必须配对使用)

**副作用与回退**:
- 修改后: 发送 `shortcutDidChangeNotification` 通知
- HotKeyService 接收通知后重新注册快捷键（unregister + register）
- 旧快捷键立即失效，新快捷键立即生效

**验证方式**: 同 shortcutKeyCode

---

### 3. quickAskKeyCode

**类型**: Int | **默认值**: 17 (kVK_ANSI_T) | **位置**: AppSettings.swift:148
**持久化**: UserDefaults (`QuickAskKeyCode`)

**读取入口**: HotKeyService.swift:119, 147

```swift
// HotKeyService.swift:119 - 初始化时加载
quickAskKeyCode = UInt32(settings.quickAskKeyCode)

// HotKeyService.swift:147 - 通知触发时重新加载
private func reloadQuickAskShortcut() {
    let settings = AppSettings.shared
    quickAskKeyCode = UInt32(settings.quickAskKeyCode)
    // ...
}
```

**写入入口**: ShortcutsSettingsContent.swift:38

```swift
ShortcutRecorderButton(
    isRecording: $isRecordingQuickAskShortcut,
    currentShortcut: appSettings.quickAskShortcutDisplayString,
    onShortcutCaptured: { keyCode, modifiers in
        appSettings.updateQuickAskShortcut(keyCode: keyCode, modifiers: modifiers)
    }
)
```

**生效时机**: 即时生效 - didSet 触发 NotificationCenter 通知，HotKeyService 监听并重新加载

**依赖与联动**:
- 前置依赖: HotKeyService 必须已初始化
- 跨模块影响: 影响 Quick Ask 快捷键触发
- 联动配置: quickAskModifiers (必须配对使用)

**副作用与回退**:
- 修改后: 发送 `quickAskShortcutDidChangeNotification` 通知
- HotKeyService 接收通知后刷新绑定并即时生效
- 旧快捷键立即失效，新快捷键立即生效

**验证方式**:
1. 打开设置 → Shortcuts
2. 点击 "Quick Ask" 快捷键录制按钮
3. 按下新的快捷键组合
4. 测试新快捷键是否触发 Quick Ask

---

### 4. quickAskModifiers

**类型**: Int | **默认值**: 524288 (NSEvent.ModifierFlags.option) | **位置**: AppSettings.swift:153
**持久化**: UserDefaults (`QuickAskModifiers`)

**读取入口**: HotKeyService.swift:120, 147

```swift
// HotKeyService.swift:120 - 初始化时加载
quickAskModifiers = NSEvent.ModifierFlags(rawValue: UInt(settings.quickAskModifiers))

// HotKeyService.swift:147 - 通知触发时重新加载
private func reloadQuickAskShortcut() {
    let settings = AppSettings.shared
    quickAskModifiers = NSEvent.ModifierFlags(rawValue: UInt(settings.quickAskModifiers))
    // ...
}
```

**写入入口**: ShortcutsSettingsContent.swift:38 (与 quickAskKeyCode 同一控件)

**生效时机**: 即时生效 - didSet 触发 NotificationCenter 通知，HotKeyService 监听并重新加载

**依赖与联动**:
- 前置依赖: HotKeyService 必须已初始化
- 跨模块影响: 影响 Quick Ask 快捷键触发
- 联动配置: quickAskKeyCode (必须配对使用)

**副作用与回退**:
- 修改后: 发送 `quickAskShortcutDidChangeNotification` 通知
- HotKeyService 接收通知后刷新绑定并即时生效
- 旧快捷键立即失效，新快捷键立即生效

**验证方式**: 同 quickAskKeyCode

---

### 5. messagePanelKeyCode

**类型**: Int | **默认值**: 35 (kVK_ANSI_P) | **位置**: AppSettings.swift:202
**持久化**: UserDefaults (`MessagePanelKeyCode`)

**读取入口**: HotKeyService.swift:121, 158

```swift
// HotKeyService.swift:121 - 初始化时加载
messagePanelKeyCode = UInt32(settings.messagePanelKeyCode)

// HotKeyService.swift:158 - 通知触发时重新加载
private func reloadMessagePanelShortcut() {
    let settings = AppSettings.shared
    messagePanelKeyCode = UInt32(settings.messagePanelKeyCode)
    // ...
}
```

**写入入口**: N/A (UI 未实现)

**生效时机**: 即时生效 - didSet 触发 NotificationCenter 通知，HotKeyService 监听并重新加载

**依赖与联动**:
- 前置依赖: HotKeyService 必须已初始化
- 跨模块影响: 影响 Message Panel 快捷键触发
- 联动配置: messagePanelModifiers (必须配对使用)

**副作用与回退**:
- 修改后: 发送 `messagePanelShortcutDidChangeNotification` 通知
- HotKeyService 接收通知后刷新绑定并即时生效
- 旧快捷键立即失效，新快捷键立即生效

**验证方式**:
```bash
# 通过 UserDefaults 修改配置
defaults write com.spokeanywhere MessagePanelKeyCode -int 35
# 重启应用
# 测试快捷键是否触发 Message Panel
```

---

### 6. messagePanelModifiers

**类型**: Int | **默认值**: 524288 (NSEvent.ModifierFlags.option) | **位置**: AppSettings.swift:207
**持久化**: UserDefaults (`MessagePanelModifiers`)

**读取入口**: HotKeyService.swift:122, 158

```swift
// HotKeyService.swift:122 - 初始化时加载
messagePanelModifiers = NSEvent.ModifierFlags(rawValue: UInt(settings.messagePanelModifiers))

// HotKeyService.swift:158 - 通知触发时重新加载
private func reloadMessagePanelShortcut() {
    let settings = AppSettings.shared
    messagePanelModifiers = NSEvent.ModifierFlags(rawValue: UInt(settings.messagePanelModifiers))
    // ...
}
```

**写入入口**: N/A (UI 未实现)

**生效时机**: 即时生效 - didSet 触发 NotificationCenter 通知，HotKeyService 监听并重新加载

**依赖与联动**:
- 前置依赖: HotKeyService 必须已初始化
- 跨模块影响: 影响 Message Panel 快捷键触发
- 联动配置: messagePanelKeyCode (必须配对使用)

**副作用与回退**:
- 修改后: 发送 `messagePanelShortcutDidChangeNotification` 通知
- HotKeyService 接收通知后刷新绑定并即时生效
- 旧快捷键立即失效，新快捷键立即生效

**验证方式**: 同 messagePanelKeyCode

---

### 7. liveCaptionKeyCode

**类型**: Int | **默认值**: 1 (kVK_ANSI_S) | **位置**: AppSettings.swift:232
**持久化**: UserDefaults (`LiveCaptionKeyCode`)

**读取入口**: HotKeyService.swift:123, 169

```swift
// HotKeyService.swift:123 - 初始化时加载
liveCaptionKeyCode = UInt32(settings.liveCaptionKeyCode)

// HotKeyService.swift:169 - 通知触发时重新加载
private func reloadLiveCaptionShortcut() {
    let settings = AppSettings.shared
    liveCaptionKeyCode = UInt32(settings.liveCaptionKeyCode)
    // ...
}
```

**写入入口**: N/A (UI 未实现)

**生效时机**: 即时生效 - didSet 触发 NotificationCenter 通知，HotKeyService 监听并重新加载

**依赖与联动**:
- 前置依赖: HotKeyService 必须已初始化
- 跨模块影响: 影响 Live Caption 快捷键触发
- 联动配置: liveCaptionModifiers (必须配对使用)

**副作用与回退**:
- 修改后: 发送 `liveCaptionShortcutDidChangeNotification` 通知
- HotKeyService 接收通知后刷新绑定并即时生效
- 旧快捷键立即失效，新快捷键立即生效

**验证方式**:
```bash
# 通过 UserDefaults 修改配置
defaults write com.spokeanywhere LiveCaptionKeyCode -int 1
# 重启应用
# 测试快捷键是否触发 Live Caption
```

---

### 8. liveCaptionModifiers

**类型**: Int | **默认值**: 524288 (NSEvent.ModifierFlags.option) | **位置**: AppSettings.swift:237
**持久化**: UserDefaults (`LiveCaptionModifiers`)

**读取入口**: HotKeyService.swift:124, 169

```swift
// HotKeyService.swift:124 - 初始化时加载
liveCaptionModifiers = NSEvent.ModifierFlags(rawValue: UInt(settings.liveCaptionModifiers))

// HotKeyService.swift:169 - 通知触发时重新加载
private func reloadLiveCaptionShortcut() {
    let settings = AppSettings.shared
    liveCaptionModifiers = NSEvent.ModifierFlags(rawValue: UInt(settings.liveCaptionModifiers))
    // ...
}
```

**写入入口**: N/A (UI 未实现)

**生效时机**: 即时生效 - didSet 触发 NotificationCenter 通知，HotKeyService 监听并重新加载

**依赖与联动**:
- 前置依赖: HotKeyService 必须已初始化
- 跨模块影响: 影响 Live Caption 快捷键触发
- 联动配置: liveCaptionKeyCode (必须配对使用)

**副作用与回退**:
- 修改后: 发送 `liveCaptionShortcutDidChangeNotification` 通知
- HotKeyService 接收通知后刷新绑定并即时生效
- 旧快捷键立即失效，新快捷键立即生效

**验证方式**: 同 liveCaptionKeyCode

---

### 9. screenshotKeyCode

**类型**: Int | **默认值**: 0 (kVK_ANSI_A) | **位置**: AppSettings.swift:262
**持久化**: UserDefaults (`ScreenshotKeyCode`)

**读取入口**: HotKeyService.swift:125, 180

```swift
// HotKeyService.swift:125 - 初始化时加载
screenshotKeyCode = UInt32(settings.screenshotKeyCode)

// HotKeyService.swift:180 - 通知触发时重新加载
private func reloadScreenshotShortcut() {
    let settings = AppSettings.shared
    screenshotKeyCode = UInt32(settings.screenshotKeyCode)
    // ...
}
```

**写入入口**: ShortcutsSettingsContent.swift:50

```swift
ShortcutRecorderButton(
    isRecording: $isRecordingScreenshotShortcut,
    currentShortcut: appSettings.screenshotShortcutDisplayString,
    onShortcutCaptured: { keyCode, modifiers in
        appSettings.updateScreenshotShortcut(keyCode: keyCode, modifiers: modifiers)
    }
)
```

**生效时机**: 即时生效 - didSet 触发 NotificationCenter 通知，HotKeyService 监听并重新加载

**依赖与联动**:
- 前置依赖: HotKeyService 必须已初始化
- 跨模块影响: 影响区域截图快捷键触发
- 联动配置: screenshotModifiers (必须配对使用)

**副作用与回退**:
- 修改后: 发送 `screenshotShortcutDidChangeNotification` 通知
- HotKeyService 接收通知后刷新绑定并即时生效
- 旧快捷键立即失效，新快捷键立即生效

**验证方式**:
1. 打开设置 → Shortcuts
2. 点击 "区域截图" 快捷键录制按钮
3. 按下新的快捷键组合
4. 测试新快捷键是否触发截图

---

### 10. screenshotModifiers

**类型**: Int | **默认值**: 524288 (NSEvent.ModifierFlags.option) | **位置**: AppSettings.swift:267
**持久化**: UserDefaults (`ScreenshotModifiers`)

**读取入口**: HotKeyService.swift:126, 180

```swift
// HotKeyService.swift:126 - 初始化时加载
screenshotModifiers = NSEvent.ModifierFlags(rawValue: UInt(settings.screenshotModifiers))

// HotKeyService.swift:180 - 通知触发时重新加载
private func reloadScreenshotShortcut() {
    let settings = AppSettings.shared
    screenshotModifiers = NSEvent.ModifierFlags(rawValue: UInt(settings.screenshotModifiers))
    // ...
}
```

**写入入口**: ShortcutsSettingsContent.swift:50 (与 screenshotKeyCode 同一控件)

**生效时机**: 即时生效 - didSet 触发 NotificationCenter 通知，HotKeyService 监听并重新加载

**依赖与联动**:
- 前置依赖: HotKeyService 必须已初始化
- 跨模块影响: 影响区域截图快捷键触发
- 联动配置: screenshotKeyCode (必须配对使用)

**副作用与回退**:
- 修改后: 发送 `screenshotShortcutDidChangeNotification` 通知
- HotKeyService 接收通知后刷新绑定并即时生效
- 旧快捷键立即失效，新快捷键立即生效

**验证方式**: 同 screenshotKeyCode

---

## 配置依赖关系图

```
快捷键配置变更
│
├─ shortcutKeyCode/Modifiers 变更
│  └─ didSet → shortcutDidChangeNotification
│     └─ HotKeyService.reloadShortcut()
│        └─ 重新注册录音快捷键
│
├─ quickAskKeyCode/Modifiers 变更
│  └─ didSet → quickAskShortcutDidChangeNotification
│     └─ HotKeyService.reloadQuickAskShortcut()
│        └─ 刷新 Quick Ask 快捷键绑定
│
├─ messagePanelKeyCode/Modifiers 变更
│  └─ didSet → messagePanelShortcutDidChangeNotification
│     └─ HotKeyService.reloadMessagePanelShortcut()
│        └─ 刷新 Message Panel 快捷键绑定
│
├─ liveCaptionKeyCode/Modifiers 变更
│  └─ didSet → liveCaptionShortcutDidChangeNotification
│     └─ HotKeyService.reloadLiveCaptionShortcut()
│        └─ 刷新 Live Caption 快捷键绑定
│
└─ screenshotKeyCode/Modifiers 变更
   └─ didSet → screenshotShortcutDidChangeNotification
      └─ HotKeyService.reloadScreenshotShortcut()
         └─ 刷新区域截图快捷键绑定
```

---

## 常见问题

### Q1: 为什么 messagePanelKeyCode/Modifiers 和 liveCaptionKeyCode/Modifiers 没有 UI 控件？

**A**: 当前版本 ShortcutsSettingsContent.swift 仅实现了 3 个快捷键的 UI 控件（录音、Quick Ask、区域截图）。Message Panel 和 Live Caption 的快捷键配置已定义并可通过 UserDefaults 修改，UI 控件将在后续版本中添加。

### Q2: keyCode 和 modifiers 必须同时修改吗？

**A**: 是的。快捷键由 keyCode（按键）和 modifiers（修饰键）组成，两者必须配对使用。UI 控件（ShortcutRecorderButton）会同时捕获并更新两个值。

### Q3: 修改快捷键后需要重启应用吗？

**A**: 不需要。所有快捷键配置都是即时生效的。didSet 观察者会立即发送 NotificationCenter 通知，HotKeyService 接收通知后立即刷新绑定并生效。

### Q4: 如何验证快捷键是否冲突？

**A**: 应用不会自动检测快捷键冲突。如果设置的快捷键与系统或其他应用冲突，可能导致快捷键无法触发。建议使用 Option (⌥) 作为修饰键以减少冲突。

### Q5: NotificationCenter 通知机制的优势是什么？

**A**: 使用 NotificationCenter 解耦了配置存储（AppSettings）和消费者（HotKeyService）。这样可以：
- 支持多个监听者同时响应配置变更
- 避免循环依赖
- 便于测试和维护

---

## 相关文档

- [配置索引](./configuration-index.md)
- [功能流视图](./ui-ux-optimization-feature-flow.md)
- [General Settings 配置](./config-general.md)
- [HotKeyService 设计文档](../design-hotkey.md)（如存在）
