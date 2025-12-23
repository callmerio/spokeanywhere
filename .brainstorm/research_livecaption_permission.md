# Research Summary: LiveCaption 屏幕录制权限问题

## 🎯 用户问题
LiveCaptionView 需要"屏幕录制"权限，右上角显示"正在截取屏幕"图标。其他应用的实时字幕功能似乎不需要这个权限，为什么？

---

## 📁 Code Context (当前实现分析)

### 1. `SystemAudioCaptureService.swift` - 核心问题所在
- 使用 **ScreenCaptureKit** (`SCStream`) 捕获系统音频
- 需要 `SCShareableContent` 权限检查
- `config.capturesAudio = true` 启用音频捕获
- **必须创建屏幕捕获流才能获取音频**，即使只需要音频

### 2. `LiveCaptionManager.swift`
- 依赖 `SystemAudioCaptureService.shared.startCapture()`
- 错误处理明确指出："需要屏幕录制权限才能捕获系统音频"

### 3. 权限流程
```
用户启动实时字幕 
  → LiveCaptionManager.start() 
  → SystemAudioCaptureService.startCapture() 
  → SCShareableContent.excludingDesktopWindows() [需要权限]
  → SCStream + SCContentFilter [创建屏幕捕获流]
  → 右上角显示"正在录制屏幕"图标
```

---

## 📜 Memory Context (历史记录)

- `memory.csv:86-91` 记录了实时字幕功能的设计和实现
- 明确记录使用 `ScreenCaptureKit.capturesAudio=true` 捕获系统音频
- macOS 26 上 `SCShareableContent` 可能触发 TCC 崩溃（已记录解决方案）

---

## 🌐 External Research (核心发现)

### 发现 1: macOS 系统音频捕获的唯一官方途径
- **ScreenCaptureKit 是 macOS 12.3+ 唯一官方的系统音频捕获 API**
- Apple 设计上将"系统音频"视为"屏幕内容的一部分"
- 没有独立的"仅音频"权限，音频捕获与屏幕录制权限绑定

### 发现 2: 为什么 Apple 原生 Live Captions 不需要权限？
- **Apple 的 Live Captions 是系统级功能**，运行在特权进程中
- 使用私有 API 和系统级权限，第三方应用无法访问
- 这不是公开 API，无法复制

### 发现 3: 其他应用的替代方案

| 方案 | 描述 | 是否需要屏幕权限 | 缺点 |
|------|------|-----------------|------|
| **ScreenCaptureKit** | 我们当前使用的方案 | ✅ 需要 | 右上角显示图标 |
| **虚拟音频设备** (BlackHole/Loopback) | 用户安装虚拟音频驱动，手动路由音频 | ❌ 不需要 | 需要用户额外安装软件、手动配置 |
| **麦克风捕获** | 用麦克风录制扬声器播放的声音 | ❌ 不需要 | 音质差、有回音、不可靠 |
| **特定应用音频** (macOS 14+) | `SCContentSharingPicker` 让用户选择特定应用 | ⚠️ 需要用户选择 | 每次需要用户手动选择，不能捕获"所有"音频 |

### 发现 4: GitHub 开源项目分析
- **BasedHardware/omi** - 使用 AVAudioEngine + 麦克风，不捕获系统音频
- **argmaxinc/WhisperKit** - 使用 AudioProcessor，同样依赖麦克风输入
- **lihaoyun6/QuickRecorder** - 使用 ScreenCaptureKit，同样需要屏幕录制权限
- **RecapAI/Recap** - 使用 CoreAudio API，但仍需权限

### 发现 5: "正在录制屏幕"图标的触发条件
- macOS 会在 **任何使用 ScreenCaptureKit 的应用活动时** 显示此图标
- 无论是否实际捕获视频帧，只要 `SCStream.startCapture()` 被调用就会显示
- 这是 **系统级安全提示**，无法绕过或隐藏

### 发现 6: macOS 14+ 的 SCContentSharingPicker
- macOS 14 引入 `SCContentSharingPicker`，允许用户选择共享特定应用/窗口
- 可以只请求音频，但：
  - 用户每次需要手动选择
  - 只能捕获选中应用的音频，不能捕获"所有系统音频"
  - 仍然属于屏幕共享范畴

---

## 💡 Key Takeaways

### 结论：我们的实现路径是正确的

1. **没有"免权限"的官方方案** - 捕获系统音频在 macOS 上必须通过 ScreenCaptureKit，必须获得屏幕录制权限

2. **Apple Live Captions 不可复制** - Apple 使用私有 API，第三方应用无法获得相同的无权限体验

3. **其他"不需要权限"的应用** 可能是：
   - 只录麦克风（不是真正的系统音频）
   - 要求用户安装虚拟音频驱动
   - 使用 `SCContentSharingPicker` 让用户选择特定应用

4. **右上角图标无法隐藏** - 这是 macOS 的安全设计，保护用户隐私

---

## 🔧 可选优化方案

### 方案 A: 保持现状（推荐）
- 继续使用 ScreenCaptureKit
- 向用户清晰解释为什么需要此权限
- 优化权限引导 UI

### 方案 B: 虚拟音频设备集成
- 提供安装 BlackHole 等虚拟音频驱动的引导
- 让用户在系统音频设置中手动路由
- 缺点：用户体验差，增加配置复杂度

### 方案 C: SCContentSharingPicker（macOS 14+）
- 让用户选择特定应用进行字幕
- 缺点：每次需要手动选择，无法捕获全局音频

### 方案 D: 仅麦克风模式（降级方案）
- 提供"麦克风模式"，录制扬声器播放的声音
- 缺点：音质差，需要扬声器播放

---

## 📚 参考资源

1. [Apple ScreenCaptureKit Documentation](https://developer.apple.com/documentation/screencapturekit)
2. [Apple Forum - Audio capture permission](https://developer.apple.com/forums/thread/807898)
3. [TN3127 - Inside Code Signing Requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)
4. [GitHub - lihaoyun6/QuickRecorder](https://github.com/lihaoyun6/QuickRecorder) - 同样使用 ScreenCaptureKit
5. [GitHub - RecapAI/Recap](https://github.com/RecapAI/Recap) - macOS 会议录音应用
