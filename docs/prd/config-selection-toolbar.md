# Selection Toolbar 配置详细文档

> 版本: v1.0
> 创建时间: 2026-02-23
> 用途: Selection Toolbar 功能的所有配置项详细说明
> 复核基准工作树: /Users/bigdan/Workspace/macos/spokeanywhere

---

## 配置项总览

Selection Toolbar 功能共有 4 个配置项，控制选择工具栏的启用状态和行为：

| setting_key | owner | read-path | write-path | 生效语义 | dependencies | side_effects |
|-------------|-------|-----------|------------|----------|--------------|--------------|
| `selectionToolbarEnabled` | AppSettings.swift:178 | AppSettings.swift:180-189 (didSet), AppDelegate.swift:194, 335 | AppDelegate.swift:381 (菜单切换) | 即时 | SelectionToolbarManager | 启动/停止选择监听服务 |
| `selectionToolbarAutoHideDelay` | AppSettings.swift:191 | N/A (当前未消费) | N/A (UI 未暴露/未接线) | 配置已定义 | 无 | 配置链路断裂（loadConfig 未实现） |
| `selectionToolbarShowText` | AppSettings.swift:194 | N/A (当前未消费) | N/A (UI 未暴露/未接线) | 配置已定义 | 无 | 配置链路断裂（loadConfig 未实现） |
| `selectionToolbarOCRContext` | AppSettings.swift:197 | N/A (当前未消费) | N/A (UI 未暴露/未接线) | 配置已定义 | 无 | 配置链路断裂（loadConfig 未实现） |

---

## 配置项详细说明

### 1. selectionToolbarEnabled

**类型**: Bool | **默认值**: true | **位置**: AppSettings.swift:178
**持久化**: UserDefaults (`SelectionToolbarEnabled`)

**读取入口**: AppSettings.swift:180-189 (didSet)

```swift
// AppSettings.swift:180-189 - didSet 观察者
@AppStorage("SelectionToolbarEnabled") var selectionToolbarEnabled: Bool = true {
    didSet {
        Task { @MainActor in
            if selectionToolbarEnabled {
                SelectionToolbarManager.shared.start()
            } else {
                SelectionToolbarManager.shared.stop()
            }
        }
    }
}
```

**写入入口**: AppDelegate.swift:381 (菜单切换)

```swift
// AppDelegate.swift:381-382 - 菜单项切换
@objc func toggleSelectionToolbar() {
    AppSettings.shared.selectionToolbarEnabled.toggle()
    selectionToolbarMenuItem?.state = AppSettings.shared.selectionToolbarEnabled ? .on : .off
}
```

**配置接线说明**:
- `AppSettings.selectionToolbarEnabled` 是真正控制启停的配置键
- 设置页 `ToolbarSettingsView.swift:31` 的 Toggle 绑定的是 `ToolbarConfigService.isEnabled`（不同配置源）
- `ToolbarConfigService.isEnabled` 仅做配置持久化，未接入 SelectionToolbarManager 启停链路

**生效时机**: 即时生效 - didSet 观察者立即调用 SelectionToolbarManager.start()/stop()

**依赖与联动**:
- 前置依赖: SelectionToolbarManager 必须已初始化
- 跨模块影响: 影响 SelectionMonitorService 的启动/停止
- 联动配置: 无

**副作用与回退**:
- 开启时: 调用 SelectionToolbarManager.shared.start()，启动选择监听服务
- 关闭时: 调用 SelectionToolbarManager.shared.stop()，停止选择监听并隐藏工具栏
- 权限检查: start() 会检查辅助功能权限，未授权时显示权限提示

**验证方式**:
1. 通过菜单栏切换 "Selection Toolbar" 菜单项
2. 或通过 UserDefaults 修改配置：
   ```bash
   defaults write com.spokeanywhere SelectionToolbarEnabled -bool true
   ```
3. 选中任意文本，观察工具栏是否显示

---

### 2. selectionToolbarAutoHideDelay

**类型**: Double | **默认值**: 5.0 | **位置**: AppSettings.swift:191
**持久化**: UserDefaults (`SelectionToolbarAutoHideDelay`)

**读取入口**: 当前未消费（配置链路断裂）

**配置链路断裂说明**:
- AppSettings 定义了此配置项并持久化到 UserDefaults
- SelectionToolbarState.config.autoHideDelay 使用硬编码默认值 5.0（SelectionToolbarState.swift:31）
- SelectionToolbarState.loadConfig() 标记为 TODO（SelectionToolbarState.swift:313-315），未实现从 AppSettings 加载配置
- SelectionToolbarManager.swift:483 读取的是 `state.config.autoHideDelay`，而非 AppSettings 中的值

**实际消费点**（使用硬编码默认值）:
```swift
// SelectionToolbarManager.swift:483 - 读取 state.config.autoHideDelay
autoHideTimer = Timer.scheduledTimer(withTimeInterval: state.config.autoHideDelay, repeats: false) { [weak self] _ in
    Task { @MainActor in
        self?.hide()
    }
}
```

**写入入口**: **UI 未实现**

**生效时机**: 配置已定义 - 但配置链路断裂，修改 UserDefaults 不会影响运行时行为

**依赖与联动**:
- 前置依赖: 无（配置链路断裂）
- 跨模块影响: 无（当前未接入）
- 说明: 需要实现 SelectionToolbarState.loadConfig() 才能生效

**副作用与回退**:
- 当前状态: 工具栏始终使用 5.0 秒自动隐藏延迟（硬编码默认值）
- 修改 UserDefaults 不会影响运行时行为

**验证方式**:
```bash
# 通过 UserDefaults 修改配置（当前无效）
defaults write com.spokeanywhere SelectionToolbarAutoHideDelay -float 10.0
# 重启应用
# 观察工具栏仍使用 5.0 秒延迟（配置未生效）
```

---

### 3. selectionToolbarShowText

**类型**: Bool | **默认值**: true | **位置**: AppSettings.swift:194
**持久化**: UserDefaults (`SelectionToolbarShowText`)

**读取入口**: 当前未消费（配置链路断裂）

**配置链路断裂说明**:
- AppSettings 定义了此配置项并持久化到 UserDefaults
- SelectionToolbarState.config.showButtonText 使用硬编码默认值 true（SelectionToolbarState.swift:34）
- SelectionToolbarState.loadConfig() 标记为 TODO（SelectionToolbarState.swift:313-315），未实现从 AppSettings 加载配置
- 当前代码中**未找到任何消费点**读取 config.showButtonText

**写入入口**: **UI 未实现**

**生效时机**: 配置已定义 - 但配置链路断裂且无消费点，完全未接入运行时

**依赖与联动**:
- 前置依赖: 无（配置链路断裂）
- 跨模块影响: 无（当前未接入）
- 说明: 需要实现 SelectionToolbarState.loadConfig() 并在 UI 中消费此配置

**副作用与回退**:
- 当前状态: 工具栏按钮始终显示文字（UI 未实现条件渲染）
- 修改 UserDefaults 不会影响运行时行为

**验证方式**:
```bash
# 通过 UserDefaults 修改配置（当前无效）
defaults write com.spokeanywhere SelectionToolbarShowText -bool false
# 重启应用
# 观察工具栏按钮仍显示文字（配置未生效）
```

---

### 4. selectionToolbarOCRContext

**类型**: Bool | **默认值**: true | **位置**: AppSettings.swift:197
**持久化**: UserDefaults (`SelectionToolbarOCRContext`)

**读取入口**: 当前未消费（配置链路断裂）

**配置链路断裂说明**:
- AppSettings 定义了此配置项并持久化到 UserDefaults
- SelectionToolbarState.config.enableOCRContext 使用硬编码默认值 true（SelectionToolbarState.swift:40）
- SelectionToolbarState.loadConfig() 标记为 TODO（SelectionToolbarState.swift:313-315），未实现从 AppSettings 加载配置
- SelectionActionService.swift:265 读取的是 `state.config.enableOCRContext`，而非 AppSettings 中的值

**实际消费点**（使用硬编码默认值）:
```swift
// SelectionActionService.swift:265 - 读取 state.config.enableOCRContext
if state.config.enableOCRContext {
    // 执行 OCR 上下文提取
}
```

**写入入口**: **UI 未实现**

**生效时机**: 配置已定义 - 但配置链路断裂，修改 UserDefaults 不会影响运行时行为

**依赖与联动**:
- 前置依赖: 无（配置链路断裂）
- 跨模块影响: 无（当前未接入）
- 说明: 需要实现 SelectionToolbarState.loadConfig() 才能生效

**副作用与回退**:
- 当前状态: 工具栏动作始终启用 OCR 上下文（硬编码默认值 true）
- 修改 UserDefaults 不会影响运行时行为

**验证方式**:
```bash
# 通过 UserDefaults 修改配置（当前无效）
defaults write com.spokeanywhere SelectionToolbarOCRContext -bool false
# 重启应用
# 观察工具栏动作仍启用 OCR 上下文（配置未生效）
```

---

## 配置依赖关系图

```
Selection Toolbar 配置链路

selectionToolbarEnabled 变更
└─ didSet → SelectionToolbarManager.start()/stop()
   └─ 启动/停止 SelectionMonitorService
      └─ 监听文本选择事件

selectionToolbarAutoHideDelay 变更
└─ 保存到 UserDefaults
   └─ ❌ 配置链路断裂（loadConfig 未实现）
      └─ SelectionToolbarManager 使用硬编码默认值 5.0

selectionToolbarShowText 变更
└─ 保存到 UserDefaults
   └─ ❌ 配置链路断裂（loadConfig 未实现）
      └─ UI 未实现条件渲染

selectionToolbarOCRContext 变更
└─ 保存到 UserDefaults
   └─ ❌ 配置链路断裂（loadConfig 未实现）
      └─ SelectionActionService 使用硬编码默认值 true
```

---

## 常见问题

### Q1: 为什么 autoHideDelay/showText/OCRContext 配置项无法生效？

**A**: 这 3 个配置项存在配置链路断裂问题：
- AppSettings 定义并持久化到 UserDefaults
- SelectionToolbarState.loadConfig() 标记为 TODO（SelectionToolbarState.swift:313-315），未实现从 UserDefaults 加载配置
- 运行时使用的是 SelectionToolbarState.config 的硬编码默认值
- 需要实现 loadConfig() 方法才能打通配置链路

### Q2: 如何修复配置链路断裂问题？

**A**: 需要在 SelectionToolbarState.loadConfig() 中实现配置加载逻辑：
```swift
private func loadConfig() {
    let settings = AppSettings.shared
    config.autoHideDelay = settings.selectionToolbarAutoHideDelay
    config.showButtonText = settings.selectionToolbarShowText
    config.enableOCRContext = settings.selectionToolbarOCRContext
}
```

### Q3: selectionToolbarEnabled 为什么能正常工作？

**A**: 因为 selectionToolbarEnabled 使用了 didSet 观察者直接调用 SelectionToolbarManager 的方法，不依赖 SelectionToolbarState.config 的加载机制。

### Q4: 设置页的 Toggle 开关控制的是什么？

**A**: 设置页 `ToolbarSettingsView.swift:31` 的 Toggle 绑定的是 `ToolbarConfigService.isEnabled`，这是工具栏配置服务的全局开关，与 `AppSettings.selectionToolbarEnabled` 是不同的配置源。当前 `ToolbarConfigService.isEnabled` 仅做配置持久化，未接入 SelectionToolbarManager 的启停链路。

### Q5: 为什么没有 UI 控件配置这些选项？

**A**: 当前版本 ToolbarSettingsView.swift 的 UI 控件未接入 AppSettings 配置键。其他 3 个配置项（autoHideDelay/showText/OCRContext）的 UI 控件和配置接线将在后续版本中添加。

### Q6: 配置链路断裂是否影响功能使用？

**A**: 不影响基本功能使用，但用户无法自定义这些行为：
- 自动隐藏延迟固定为 5.0 秒
- 按钮文字始终显示
- OCR 上下文始终启用

---

## 相关文档

- [配置索引](./configuration-index.md)
- [功能流视图](./ui-ux-optimization-feature-flow.md)
- [General Settings 配置](./config-general.md)
- [Shortcuts 配置](./config-shortcuts.md)
