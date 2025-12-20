# App Store 审核合规矩阵

**最后更新**: 2025-12-21
**状态**: 🟡 存在待处理项 (阻断项已解决 1/2)

此文档详细梳理 SpokeAnywhere 功能与 App Store 审核规则的对应关系、权限需求及潜在风险。

---

## 🛑 1. 致命阻断项 (必须移除/重构)

| 功能模块 | 问题描述 | 违规条款 | 解决方案 | 状态 |
|---------|---------|---------|---------|------|
| **手势服务 (TrackpadGesture)** | ~~使用 `dlopen` 加载私有框架 `MultitouchSupport.framework`~~ | **2.5.1** (Private API) | ✅ 已改用 `TrackpadSwipeService`<br>使用 `NSEvent.addGlobalMonitor(.scrollWheel)` 公开 API<br>监听双指滑动触发 Pipeline | ✅ **已解决** |
| **沙盒 (Sandbox)** | 项目缺失 entitlements 文件，未开启 App Sandbox | **2.5.1** (Technical Requirements) | 创建 `SpokenAnyWhere.entitlements` 并配置最小权限集 | 🔴 待处理 |

---

## ⚠️ 2. 权限敏感功能 (需申请权限 & 详细说明)

这些功能可以使用，但在沙盒环境下受限，且在审核时必须提供令人信服的理由。

| 功能模块 | 权限需求 | 使用场景说明 (用于审核 & Privacy Usage Description) | 风险等级 |
|---------|---------|--------------------------------------------------|---------|
| **快捷键 (HotKeyService)** | **Accessibility** (辅助功能)<br>`CGEvent.tapCreate` | "我们需要监听特定的全局快捷键(如 ⌥R, ⌥T)来让用户能够随时触发语音录制或消息面板，即使应用在后台运行。" | 🟠 高<br>(需用户手动授权) |
| **划词工具栏 (SelectionToolbar)** | **Accessibility** (辅助功能)<br>`AXUIElement*` | "当用户选中文本时，我们需要读取选区位置和内容以显示辅助工具栏。此功能仅在用户明确交互时触发。" | 🟠 高<br>(需用户手动授权) |
| **截图上下文 (ScreenOCR)** | **Screen Recording** (屏幕录制)<br>`ScreenCaptureKit` | "应用需要截取当前活动窗口的快照，以便 AI 能够理解用户的视觉上下文（如屏幕上的文字），从而提供更准确的语音助手服务。截图仅在本地临时处理，不上传。" | 🟡 中<br>(系统级弹窗) |
| **实时字幕 (LiveCaption)** | **Screen Recording** (系统音频) | "应用需要捕获系统音频以实现实时字幕功能。音频数据仅在本地进行处理。" | 🟡 中 |
| **语音输入 (AudioRecorder)** | **Microphone** (麦克风) | "应用通过麦克风录制用户的语音指令，并转换为文本或执行相应操作。" | 🟢 低<br>(标准权限) |
| **模拟输入 (InputService)** | **Accessibility** (辅助功能)<br>`CGEventPost` | "将语音转换的文本自动输入到当前光标位置。" **建议：改为复制到剪贴板，降低风险。** | 🟡 中 |

---

## 🛡 3. 沙盒权限配置 (Entitlements)

为了满足 App Store 要求，必须配置以下 Entitlements：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- 基础沙盒开关 -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
    
    <!-- 硬件访问 -->
    <key>com.apple.security.device.audio-input</key>
    <true/> <!-- 麦克风 -->
    
    <!-- 网络访问 (LLM API) -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- 文件访问 -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/> <!-- 用户选择文件 -->
    <key>com.apple.security.files.downloads.read-write</key>
    <true/> <!-- 下载目录 (可选) -->
    
    <!-- 特殊例外 (慎用，审核难过) -->
    <!-- ScreenCaptureKit 通常不需要特殊 entitlement，但旧版 API 可能需要 -->
    <!-- Apple Events (控制其他应用) - 划词可能需要 -->
    <!-- <key>com.apple.security.temporary-exception.apple-events</key> -->
    <!-- <array><string>com.apple.systemevents</string></array> -->
</dict>
</plist>
```

---

## 📋 4. 上架风险自查清单

### A. 功能削减与调整策略
1.  **TrackpadGesture**: ✅ **已解决** - 改用公开 API
    *   *原问题*: 使用私有 `MultitouchSupport.framework`
    *   *解决方案*: 新建 `TrackpadSwipeService` 使用 `NSEvent.addGlobalMonitorForEvents(.scrollWheel)`
    *   *实现细节*: 累积 `deltaX` 检测双指水平滑动，阈值 300px
    *   *验证*: 2025-12-21 用户确认体验良好

2.  **模拟键盘输入**:
    *   *风险*: 被视为自动化/外挂。
    *   *建议*: 默认行为改为“复制到剪贴板并提示用户粘贴”。保留“模拟输入”作为高级选项，仅在用户授予辅助功能权限后开启。

### B. 审核材料准备
*   **演示视频**: 必须录制一段清晰的视频，演示为什么应用需要 Accessibility 权限（展示划词功能、快捷键功能），并在 App Store Connect 的“审核备注”中提供链接。
*   **隐私政策**: 明确说明截图、录音、Accessibility 数据的使用范围（仅本地/仅 LLM 上下文），不收集个人隐私。

---

## 📅 5. 执行路线图

1.  **Phase 1: Compliance Fix**
    *   ✅ ~~移除 `TrackpadGestureService`~~ → 改用 `TrackpadSwipeService` (公开 API)
    *   🔴 添加 `SpokenAnyWhere.entitlements`。
    *   确保 App 在沙盒模式下核心功能（录音、LLM请求）可用。
2.  **Phase 2: Permission UX**
    *   设计“首次启动向导” (Onboarding)。
    *   分步引导用户授予麦克风、Accessibility、屏幕录制权限。
    *   解释清楚为什么需要这些权限（Copywriting 优化）。
3.  **Phase 3: Beta & Review**
    *   内部测试沙盒兼容性（文件读写路径修正）。
    *   提交 TestFlight。
