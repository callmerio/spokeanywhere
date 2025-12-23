# Spec: LiveCaption 应用选择器 (SCContentSharingPicker)

## Overview

为实时字幕功能添加 **应用选择模式**，使用 macOS 14+ 的 `SCContentSharingPicker` API，让用户可以选择特定应用进行字幕，避免全局录屏图标。

---

## 问题背景

当前实现使用 `SCStream` 捕获全屏音频，会触发：
1. 需要"屏幕录制"权限
2. 右上角显示"正在录制屏幕"图标（无法隐藏）

使用 `SCContentSharingPicker` 可以：
- 让用户明确选择要捕获的应用
- 系统级 UI，权限处理更自然
- 可能减少用户对"录屏"的疑虑

---

## Requirements

### 功能需求

| ID | 需求 | 优先级 |
|----|------|-------|
| R1 | 支持 macOS 14+ 的应用选择器模式 | P0 |
| R2 | 保留现有"全局模式"作为默认选项 | P0 |
| R3 | 用户可在设置中选择默认捕获模式 | P1 |
| R4 | 字幕工具栏显示当前捕获的应用名称 | P1 |
| R5 | 支持运行中切换/重选应用 | P2 |

### 入口方案设计

**方案对比：**

| 方案 | 描述 | 优点 | 缺点 |
|------|------|------|------|
| **A. 设置页选择模式** | 设置中选择"全局"或"应用选择"，开启时自动弹出 Picker | 一次设置，后续自动 | 切换应用需进设置 |
| **B. 开启时弹菜单** | 每次开启时弹出菜单让用户选 | 灵活 | 每次都要选，繁琐 |
| **C. 工具栏按钮** | 字幕工具栏添加"选择应用"按钮 | 随时可切换 | 按钮可能太多 |
| **D. 混合方案** ⭐ | 设置选模式 + 工具栏可切换 | 兼顾便利和灵活 | 实现稍复杂 |

**推荐：方案 D（混合方案）**

```
设置页:
┌─────────────────────────────────────────┐
│ 实时字幕                                  │
├─────────────────────────────────────────┤
│ 音频捕获模式:                             │
│   ○ 全局模式 (捕获所有系统音频)            │
│   ● 应用选择模式 (每次选择特定应用) ⚡      │
│     └─ macOS 14+ 可用，隐私更友好          │
└─────────────────────────────────────────┘

字幕工具栏 (应用模式时):
┌─────────────────────────────────────────┐
│ 🎧 Safari ▾  │ 🌐 EN │ ⚙️ │ ✕           │
└─────────────────────────────────────────┘
     ↑ 点击可重新选择应用
```

---

## 技术设计

### 1. 新增文件

```
Core/LiveCaption/
├── AppAudioCaptureService.swift    # 新增：基于 Picker 的音频捕获
└── SystemAudioCaptureService.swift # 现有：全局音频捕获
```

### 2. 核心 API 使用

```swift
@available(macOS 14.0, *)
class AppAudioCaptureService: NSObject, SCContentSharingPickerObserver {
    
    private let picker = SCContentSharingPicker.shared
    private var stream: SCStream?
    
    // 配置 Picker
    func configurePicker() {
        var config = SCContentSharingPickerConfiguration()
        config.allowedPickerModes = [.singleApplication]  // 只允许选单个应用
        config.allowsChangingSelectedContent = true
        picker.defaultConfiguration = config
        picker.add(self)
        picker.isActive = true
    }
    
    // 显示选择器
    func presentPicker() {
        picker.present()
    }
    
    // Observer: 用户选择了内容
    func contentSharingPicker(_ picker: SCContentSharingPicker, 
                              didUpdateWith filter: SCContentFilter, 
                              for stream: SCStream?) {
        Task {
            await startCapture(with: filter)
        }
    }
    
    // Observer: 用户取消
    func contentSharingPickerDidCancel(_ picker: SCContentSharingPicker, 
                                        for stream: SCStream?) {
        // 处理取消
    }
}
```

### 3. LiveCaptionManager 修改

```swift
enum CaptureMode: String, CaseIterable {
    case global = "global"           // 全局模式 (现有)
    case appPicker = "appPicker"     // 应用选择模式 (新增)
}

@MainActor
final class LiveCaptionManager: ObservableObject {
    
    @AppStorage("LiveCaptionCaptureMode") var captureMode: String = "global"
    
    /// 当前捕获的应用名称 (应用模式时)
    @Published var currentAppName: String?
    
    func start() async throws {
        if captureMode == CaptureMode.appPicker.rawValue {
            if #available(macOS 14.0, *) {
                try await startWithAppPicker()
            } else {
                // 回退到全局模式
                try await startWithGlobalCapture()
            }
        } else {
            try await startWithGlobalCapture()
        }
    }
    
    @available(macOS 14.0, *)
    private func startWithAppPicker() async throws {
        let appCapture = AppAudioCaptureService.shared
        appCapture.onFilterSelected = { [weak self] filter, appName in
            self?.currentAppName = appName
            // 开始捕获...
        }
        appCapture.presentPicker()
    }
}
```

### 4. UI 修改

**设置页 (SettingsView.swift):**
```swift
Section("实时字幕") {
    Picker("音频捕获模式", selection: $captureMode) {
        Text("全局模式").tag("global")
        if #available(macOS 14.0, *) {
            Text("应用选择模式").tag("appPicker")
        }
    }
    .pickerStyle(.radioGroup)
    
    if captureMode == "appPicker" {
        Text("每次开启时选择要捕获的应用，隐私更友好")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}
```

**字幕工具栏 (LiveCaptionToolbar.swift):**
```swift
if manager.captureMode == "appPicker", 
   let appName = manager.currentAppName {
    Button(action: { manager.reselectApp() }) {
        HStack(spacing: 4) {
            Image(systemName: "app.fill")
            Text(appName)
            Image(systemName: "chevron.down")
        }
    }
    .help("点击重新选择应用")
}
```

---

## Acceptance Criteria

| ID | 验收标准 | 测试方法 |
|----|---------|---------|
| AC1 | macOS 14+ 可在设置中看到"应用选择模式"选项 | 手动验证 |
| AC2 | 选择应用模式后，开启字幕时弹出系统 Picker | 手动验证 |
| AC3 | 选择应用后，只捕获该应用的音频 | 播放视频测试 |
| AC4 | 工具栏显示当前应用名，点击可重选 | 手动验证 |
| AC5 | macOS < 14 自动回退到全局模式 | 编译检查 |
| AC6 | 用户取消选择时，不启动字幕 | 手动验证 |

---

## Out of Scope

1. ~~多应用同时捕获~~ - 复杂度高，后续考虑
2. ~~自动检测前台应用~~ - 需要额外权限
3. ~~记住上次选择的应用~~ - Picker 不支持预选

---

## 实现计划

| Phase | 任务 | 预估 |
|-------|------|------|
| 1 | 创建 AppAudioCaptureService + Picker 集成 | 2h |
| 2 | 修改 LiveCaptionManager 支持双模式 | 1h |
| 3 | 设置页 UI | 0.5h |
| 4 | 工具栏 UI | 0.5h |
| 5 | 测试 + 调试 | 1h |

**Total: ~5h**
