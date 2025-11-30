# Message Panel 设计文档

> 📅 Created: 2025-11-30  
> 📝 Status: 概念讨论阶段

---

## 1. 定位与目标

### 1.1 产品定位

**Message Panel** 是 Spokenly 的 **核心交互界面**，作为辅助工具的主要信息展示窗口。

- **不是** 调试面板
- **是** 用户与应用沟通的消息中心
- **类似** macOS 通知中心，但从左侧滑出

### 1.2 核心价值

| 价值                | 说明                                     |
| ------------------- | ---------------------------------------- |
| **Pipeline 可视化** | 展示语音处理各阶段的输出（ASR → LLM）    |
| **历史回溯**        | 用户可像浏览 Timeline 一样查看历史记录   |
| **内容选择**        | 用户可选择任意阶段的内容进行复制         |
| **扩展入口**        | 未来承载 Todo、Notes、知识库、字典等功能 |

### 1.3 使用场景

- 用户想查看 ASR 原始转录 vs LLM 润色结果
- 用户更喜欢 ASR 原文，想直接复制
- 用户想将某个词汇保存到字典（用于后续 ASR 优化）
- 用户想回顾之前的语音交互历史

---

## 2. 样式设计

### 2.1 整体布局

```
┌─────────────────────────────────────┐
│           Message Panel             │
│         (固定宽度 ~360pt)            │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │ Welcome                         │ │
│ │ Apple Speech is coming!         │ │
│ └─────────────────────────────────┘ │
│ ┌─────────────────────────────────┐ │
│ │ ASR │ Apple Speech        14:32 │ │
│ │ ─────────────────────────────── │ │
│ │ 这一下像左边这种就是图片上...   │ │
│ │                            🔄  │ │
│ └─────────────────────────────────┘ │
│ ┌─────────────────────────────────┐ │
│ │ LLM │ Gemini              14:33 │ │
│ │ ─────────────────────────────── │ │
│ │ 左侧这种悬浮于整个屏幕的...     │ │
│ └─────────────────────────────────┘ │
│              ↓ 可滚动                │
├─────────────────────────────────────┤
│ [快捷输入框] (可选，后续功能)        │
└─────────────────────────────────────┘
```

### 2.2 视觉风格

| 元素     | 设计                                         |
| -------- | -------------------------------------------- |
| **背景** | 半透明深色 + 毛玻璃效果 (NSVisualEffectView) |
| **圆角** | 与 macOS 通知中心一致 (~12pt)                |
| **位置** | 屏幕左边缘，垂直居中或顶部对齐               |
| **宽度** | 固定 ~360pt                                  |
| **高度** | 自适应，最大不超过屏幕高度 80%               |

### 2.3 卡片设计

```
┌─────────────────────────────────────┐
│ [阶段标签] │ [模型名称]    [时间戳] │  ← 头部
├─────────────────────────────────────┤
│                                     │
│ [可选择的文本内容区域]               │  ← 内容（NSTextView）
│                                     │
│                              [🔄]   │  ← 操作图标（悬浮显示）
└─────────────────────────────────────┘
```

#### 阶段标签颜色

| 阶段    | 颜色建议 |
| ------- | -------- |
| Welcome | 灰色     |
| ASR     | 蓝色     |
| LLM     | 紫色     |
| Todo    | 绿色     |
| Note    | 黄色     |

---

## 3. 交互设计

### 3.1 唤出面板

| 方式           | 操作                        |
| -------------- | --------------------------- |
| **快捷键**     | `Option + P` (P = Pipeline) |
| **触控板手势** | 双指从左边缘向右滑动        |

### 3.2 收起面板

| 方式           | 操作                     |
| -------------- | ------------------------ |
| **触控板手势** | 双指向左滑动（任意位置） |
| **快捷键**     | `Option + P` 再次按下    |
| **点击外部**   | 点击面板外区域（可选）   |

### 3.3 卡片交互

| 操作           | 方式             | 说明                         |
| -------------- | ---------------- | ---------------------------- |
| **选择文本**   | 鼠标拖选         | 内容区支持文本选择           |
| **复制**       | 右键菜单 / Cmd+C | 选中后可复制                 |
| **保存到字典** | 右键菜单         | 选中文本后可保存（未来功能） |
| **重新润色**   | 点击 🔄 图标     | 使用其他 LLM 重新处理        |

### 3.4 动画效果

| 动画       | 说明                         |
| ---------- | ---------------------------- |
| **滑入**   | 从左边缘向右滑入，带弹性效果 |
| **滑出**   | 向左滑出，快速收起           |
| **新卡片** | 从顶部/底部淡入              |

---

## 4. 数据模型

### 4.1 消息卡片模型

```swift
struct MessageCard: Identifiable {
    let id: UUID
    let timestamp: Date
    let stage: MessageStage
    let content: String
    let metadata: MessageMetadata
}

enum MessageStage {
    case welcome
    case keyPress          // 按键事件
    case asr(model: String)  // Apple Speech / Whisper
    case llm(model: String)  // Gemini / GPT
    case todo              // 未来功能
    case note              // 未来功能
}

struct MessageMetadata {
    var keyPressDuration: TimeInterval?  // 按键时长
    var processingTime: TimeInterval?    // 处理耗时
    var modelVersion: String?            // 模型版本
}
```

### 4.2 面板状态模型

```swift
class MessagePanelState: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var cards: [MessageCard] = []

    func addCard(_ card: MessageCard)
    func toggle()
    func show()
    func hide()
}
```

---

## 5. 技术实现要点

### 5.1 窗口层级

```swift
// 使用 NSPanel 实现悬浮窗口
let panel = NSPanel(
    contentRect: rect,
    styleMask: [.borderless, .nonactivatingPanel],
    backing: .buffered,
    defer: false
)
panel.level = .floating
panel.isMovableByWindowBackground = false
panel.backgroundColor = .clear
```

### 5.2 毛玻璃效果

```swift
let visualEffect = NSVisualEffectView()
visualEffect.material = .hudWindow
visualEffect.blendingMode = .behindWindow
visualEffect.state = .active
```

### 5.3 文本选择

```swift
// 使用 NSTextView 支持文本选择
let textView = NSTextView()
textView.isEditable = false
textView.isSelectable = true
textView.drawsBackground = false
```

### 5.4 触控板手势（待深入研究）

```swift
// 方案1: NSEvent 全局监听
NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { event in
    // 检测双指滑动方向
}

// 方案2: CGEvent Tap（需要辅助功能权限）
// 可以获取更精确的触控板信息
```

---

## 6. 开发阶段规划

### Phase 1: 基础面板 ✨

- [ ] NSPanel 悬浮窗口实现
- [ ] 基础样式（毛玻璃、圆角）
- [ ] `Option + P` 快捷键唤出/收起
- [ ] 滑入/滑出动画

### Phase 2: 卡片系统 🃏

- [ ] MessageCard 数据模型
- [ ] 卡片 UI 组件
- [ ] 可选择文本（NSTextView）
- [ ] 右键菜单（复制）
- [ ] 滚动查看历史

### Phase 3: Pipeline 集成 🔗

- [ ] 接入 ASR 输出
- [ ] 接入 LLM 输出
- [ ] 显示处理时长等元数据
- [ ] 重新润色功能（🔄 按钮）

### Phase 4: 手势支持 👆

- [ ] 研究触控板边缘手势实现
- [ ] 双指滑动唤出/收起

### Phase 5: 扩展功能 🚀

- [ ] 字典管理（保存词汇）
- [ ] Todo 集成
- [ ] Note 集成
- [ ] 知识库入口

---

## 7. 已确认问题 ✅

| 问题              | 决定                     |
| ----------------- | ------------------------ |
| **面板位置**      | 垂直居中 + 顶部对齐      |
| **最大高度**      | 100% 屏幕高度            |
| **Pipeline 区域** | 100% 面板高度            |
| **历史记录**      | 尽可能全保存，持久化存储 |
| **多显示器**      | 跟随鼠标所在屏幕         |

---

## 8. 参考资料

### 8.1 开源项目参考

| 项目                   | 说明                                        | 链接                                                        |
| ---------------------- | ------------------------------------------- | ----------------------------------------------------------- |
| **swiftDialog** ⭐     | macOS 对话框/通知工具，有完整的窗口定位实现 | [GitHub](https://github.com/swiftDialog/swiftDialog)        |
| **SystemNotification** | iOS/macOS 系统通知样式模拟 (631⭐)          | [GitHub](https://github.com/danielsaidi/SystemNotification) |
| **SimpleToast**        | SwiftUI Toast 库 (469⭐)                    | [GitHub](https://github.com/sanzaru/SimpleToast)            |
| **jamf/Notifier**      | macOS 通知工具                              | [GitHub](https://github.com/jamf/Notifier)                  |

### 8.2 关键代码参考 (swiftDialog)

**窗口定位函数** (`dialog/Extensions/NSWindow+Additions.swift`):

```swift
func placeWindow(_ window: NSWindow, size: CGSize? = nil,
                 vertical: NSWindow.Position.Vertical,
                 horozontal: NSWindow.Position.Horizontal,
                 offset: CGFloat) {
    let main = NSScreen.main!
    let visibleFrame = main.visibleFrame
    var windowSize = size ?? window.frame.size

    let windowX = calculateWindowXPos(screenWidth: visibleFrame.width - windowSize.width,
                                       position: horozontal, offset: offset)
    let windowY = calculateWindowYPos(screenHeight: visibleFrame.height - windowSize.height,
                                       position: vertical, offset: offset)

    let desiredOrigin = CGPoint(x: visibleFrame.origin.x + windowX,
                                 y: visibleFrame.origin.y + windowY)
    window.setContentSize(windowSize)
    window.setFrameOrigin(desiredOrigin)
}
```

**窗口层级与样式** (`dialogApp.swift`):

```swift
// 浮于顶层
window.level = .floating

// 隐藏标题栏按钮
window.standardWindowButton(.closeButton)?.isHidden = true

// 可在全屏模式上显示
window.collectionBehavior = [.canJoinAllSpaces]

// 登录窗口可见
window.canBecomeVisibleWithoutLogin = true
```

### 8.3 多显示器支持

获取鼠标所在屏幕：

```swift
func screenWithMouse() -> NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    return NSScreen.screens.first { screen in
        NSMouseInRect(mouseLocation, screen.frame, false)
    }
}
```

---

> 📝 下一步：开始 Phase 1 实现 - 基础面板框架
