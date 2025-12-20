# Mac App Store 上架风险深度审查报告

**项目**: SpokenAnyWhere
**BundleID**: app.spokenly
**审查日期**: 2025-12-20
**最低系统要求**: macOS 14.0

---

## 🚨 风险概览

| 风险级别 | 数量 | 说明 |
|----------|------|------|
| 🔴 **致命** (不可上架) | 3 | 必须移除或重构，否则审核100%被拒 |
| 🟠 **高风险** | 2 | 需要申请特殊权限或豁免 |
| 🟡 **中风险** | 4 | 可能被拒，需要充分说明理由 |
| 🟢 **低风险** | 3 | 注意事项，一般可通过 |

---

## 🔴 致命风险 (BLOCKER)

### 1. **私有API: MultitouchSupport.framework** ⛔️

**位置**: `Services/TrackpadGestureService.swift:62-63`

```swift
let frameworkPath = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
handle = dlopen(frameworkPath, RTLD_NOW)
```

**问题**:
- 使用 `dlopen` 动态加载 **私有框架** `MultitouchSupport.framework`
- 调用私有函数: `MTDeviceCreateList`, `MTRegisterContactFrameCallback`, `MTDeviceStart`, `MTDeviceStop`
- Apple 明确禁止在 App Store 应用中使用私有API

**审核拒绝依据**: App Store Review Guideline 2.5.1

**解决方案**:
1. **完全移除** TrackpadGestureService (推荐)
2. 改用 `NSEvent.addGlobalMonitorForEvents` 监听手势 (功能受限)
3. 使用 `NSGestureRecognizer` (无法监听系统级手势)

**工作量**: ~2h (移除) / ~8h (重构)

---

### 2. **沙盒兼容性: 应用未沙盒化** ⛔️

**问题**:
- 项目中 **没有 .entitlements 文件**
- Mac App Store **强制要求** App Sandbox
- 当前应用访问了多种需要沙盒权限的资源

**需要的权限声明** (entitlements):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    
    <!-- 麦克风 -->
    <key>com.apple.security.device.audio-input</key>
    <true/>
    
    <!-- 屏幕录制 (需要 Hardened Runtime Exception) -->
    <key>com.apple.security.temporary-exception.audio-video-bridging</key>
    <true/>
    
    <!-- 网络访问 (LLM API 调用) -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- Keychain 访问 -->
    <key>com.apple.security.keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)app.spokenly</string>
    </array>
    
    <!-- 用户选择的文件读取 -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
```

**解决方案**:
1. 创建 `SpokenAnyWhere.entitlements` 文件
2. 启用 App Sandbox
3. 声明所需权限
4. 测试所有功能在沙盒下正常工作

**工作量**: ~4-8h (需要全面测试)

---

### 3. **全局键盘事件监听: CGEvent.tapCreate** ⚠️⛔️

**位置**: `Services/HotKeyService.swift:233-247`

```swift
guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(eventMask),
    callback: { ... },
    userInfo: ...
) else { ... }
```

**问题**:
- `CGEvent.tapCreate` 需要 **辅助功能权限** (Accessibility)
- 沙盒应用 **无法自动获取** 辅助功能权限
- 用户必须手动在 **系统设置 > 隐私与安全 > 辅助功能** 中授权

**审核风险**: 
- Apple 会质疑为什么需要监听全局键盘事件
- 需要在审核说明中详细解释用途
- 可能被要求提供视频演示

**解决方案**:
1. 在应用内提供清晰的**权限请求说明**和**引导流程**
2. 使用 `AXIsProcessTrustedWithOptions` 检查和请求权限 ✅ (已有)
3. 准备审核说明文档，解释快捷键功能的必要性
4. 考虑使用 `NSEvent.addGlobalMonitorForEvents` 替代 (限制: 无法阻止事件传递)

**审核通过可能性**: 60-70% (需要充分说明)

---

## 🟠 高风险

### 4. **Accessibility API 大量使用**

**位置**: `Services/SelectionMonitorService.swift`

```swift
AXIsProcessTrusted()
kAXSelectedTextChangedNotification
kAXFocusedApplicationAttribute
kAXSelectedTextAttribute
kAXBoundsForRangeParameterizedAttribute
// ... 20+ 处 AX API 调用
```

**功能**: 划词工具栏 (SelectionToolbar)

**风险**:
- 辅助功能权限在沙盒下获取困难
- 用户体验: 第一次使用需要手动授权
- 审核时需要解释为什么需要读取其他应用的选中文本

**解决方案**:
1. 突出划词功能的价值 (查词、翻译、AI 总结)
2. 提供完善的权限引导 UI
3. 审核说明中强调隐私保护措施

---

### 5. **屏幕录制权限: ScreenCaptureKit**

**位置**: 多处使用
- `Services/ScreenOCRService.swift`
- `Core/LiveCaption/SystemAudioCaptureService.swift`
- `Core/Screenshot/ScreenshotManager.swift`

**功能**:
- 实时字幕 (捕获系统音频)
- 截图功能
- OCR 识别

**风险**:
- 屏幕录制是**敏感权限**
- 审核团队会仔细审查使用场景
- 需要 `NSScreenCaptureUsageDescription` ✅ (已有)

**解决方案**:
1. Info.plist 中的说明要**具体且诚实** ✅
2. 审核说明中详细解释每个使用场景
3. 确保只在必要时请求权限

---

## 🟡 中风险

### 6. **CGEvent 输入模拟**

**位置**: `Services/InputService.swift:188-223`

```swift
let source = CGEventSource(stateID: .hidSystemState)
guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else { ... }
keyDown.keyboardSetUnicodeString(...)
keyDown.post(tap: .cghidEventTap)
```

**功能**: 语音转文字后模拟键盘输入

**风险**:
- 模拟键盘输入被视为"自动化"行为
- 需要辅助功能权限
- 审核可能质疑安全性

**解决方案**:
1. 考虑使用 **粘贴板** 方案替代模拟输入
2. 提供用户选项: "直接输入" vs "复制到剪贴板"
3. 审核说明强调这是用户主动触发的行为

---

### 7. **LSUIElement = true (隐藏 Dock 图标)**

**位置**: `Info.plist:21-22`

```xml
<key>LSUIElement</key>
<true/>
```

**影响**:
- 应用不在 Dock 中显示
- 只有菜单栏图标

**风险**:
- Apple 可能询问为什么隐藏 Dock 图标
- 需要在应用描述中说明这是"菜单栏工具"

**解决方案**: 在 App Store 描述中明确说明应用类型

---

### 8. **网络请求: API 调用安全性**

**位置**: `Core/LLM/OpenAICompatibleProvider.swift`

**功能**: 调用 OpenAI/Gemini 等 LLM API

**风险**:
- 用户 API Key 存储安全性 (使用 Keychain ✅)
- 网络请求是否加密 (HTTPS ✅)
- 是否收集用户数据 (需要隐私政策)

**解决方案**:
1. 准备**隐私政策**页面
2. 在 App Store 页面说明数据使用方式
3. 确保所有请求使用 HTTPS

---

### 9. **文件系统访问范围**

**位置**: 多处 `FileManager.default.urls(...)`

**当前行为**:
- 访问 `~/Library/Application Support/Spoke/`
- 保存历史记录、词典、标签等

**风险**:
- 沙盒下只能访问 Container 目录
- 现有路径可能与沙盒冲突

**解决方案**:
1. 使用 `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`
2. 或使用 `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)` (沙盒会自动重定向)

---

## 🟢 低风险

### 10. **Translation API (macOS 15+)**

**位置**: `Core/LiveCaption/TranslationService.swift`

**状态**: 使用 Apple 官方 Translation 框架 ✅

**注意**: 需要声明网络权限

---

### 11. **Speech Recognition API**

**位置**: `SFSpeechRecognizer`, `SpeechAnalyzer`

**状态**: 使用 Apple 官方 API ✅
  
**权限**: `NSSpeechRecognitionUsageDescription` ✅ (已有)

---

### 12. **Keychain 使用**

**位置**: `Core/LLM/KeychainService.swift`

**状态**: 标准 Keychain API ✅

**注意**: 需要在 entitlements 中声明 Keychain Access Groups

---

## 📋 上架前必做清单

### 🔴 P0 (阻断项)

- [ ] **移除 TrackpadGestureService** 或禁用私有 API 调用
- [ ] **创建 .entitlements 文件** 并启用 App Sandbox
- [ ] **全面测试** 沙盒下所有功能

### 🟠 P1 (高优先级)

- [ ] 准备**权限请求引导 UI** (首次启动流程)
- [ ] 编写**审核说明文档** (为什么需要辅助功能权限)
- [ ] 准备**功能演示视频** (2-3分钟)

### 🟡 P2 (提交前)

- [ ] 创建**隐私政策**页面
- [ ] 创建**App Store 描述**文案
- [ ] 准备**App 预览截图** (5 张以上)
- [ ] 设置**App Store Connect** 元数据
- [ ] Archive 并上传 TestFlight 测试

---

## 🎯 综合评估

| 维度 | 评分 | 说明 |
|------|------|------|
| **当前可上架性** | ⭐ (1/5) | 存在致命阻断项 |
| **修复后可上架性** | ⭐⭐⭐⭐ (4/5) | 修复后高概率通过 |
| **所需工作量** | 2-3 周 | 包含测试和审核准备 |
| **审核通过概率** (修复后) | 70-80% | 取决于辅助功能的说明质量 |

### 主要风险总结

1. **致命问题**: 私有 API + 未沙盒化 → **必须修复**
2. **辅助功能**: 需要详细说明使用场景 → **可通过**
3. **屏幕录制**: 功能合理，说明清晰 → **可通过**

### 建议路线

1. **Phase 1** (1周): 移除私有 API + 创建沙盒配置
2. **Phase 2** (3天): 权限引导 UI + 测试
3. **Phase 3** (3天): 准备审核材料
4. **Phase 4**: 提交，等待审核，可能需要 2-3 轮沟通

---

## 📎 参考资源

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App Sandbox Design Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/AppSandboxDesignGuide/)
- [Configuring the macOS App Sandbox](https://developer.apple.com/documentation/security/app_sandbox/configuring_the_macos_app_sandbox)
- [Accessibility Permission Guide](https://developer.apple.com/documentation/applicationservices/kaxattribute)

---

*Generated by CCW Review Workflow*
