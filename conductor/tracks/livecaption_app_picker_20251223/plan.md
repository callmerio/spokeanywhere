# Plan: LiveCaption 应用选择器

## Track Info
- **ID**: livecaption_app_picker_20251223
- **Type**: Feature
- **Status**: [ ] Pending

---

## Phase 1: Core Service
- [ ] Task 1.1: 创建 `AppAudioCaptureService.swift`
  - 实现 `SCContentSharingPickerObserver` 协议
  - 配置 Picker (singleApplication 模式)
  - 处理用户选择/取消回调
  - 基于 `SCContentFilter` 创建 `SCStream`

---

## Phase 2: Manager Integration  
- [ ] Task 2.1: 修改 `LiveCaptionManager.swift`
  - 添加 `CaptureMode` 枚举
  - 添加 `@AppStorage("LiveCaptionCaptureMode")` 
  - 添加 `currentAppName` 属性
  - 修改 `start()` 根据模式选择捕获服务
  - 添加 `reselectApp()` 方法

---

## Phase 3: Settings UI
- [ ] Task 3.1: 修改 `SettingsView.swift`
  - 添加"音频捕获模式"选项
  - RadioGroup: 全局模式 / 应用选择模式
  - macOS 14+ 可用性检查

---

## Phase 4: Toolbar UI
- [ ] Task 4.1: 修改 `LiveCaptionToolbar.swift`
  - 应用模式时显示当前应用名
  - 点击可重新选择应用

---

## Phase 5: Verification
- [ ] Task 5.1: 功能测试
  - macOS 14+ 应用选择模式
  - macOS < 14 回退到全局模式
  - 用户取消时不启动
  - 切换应用功能
