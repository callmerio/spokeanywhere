# 系统级文本选择工具栏设计文档

## 概述

实现类似 PopClip 的系统级悬浮工具栏，当用户在任意应用中选择文本时自动出现，提供快捷操作。

```
┌─────────────────────────────────────────────────────────────┐
│  用户选择文本 → 工具栏自动出现 → 点击按钮执行操作           │
└─────────────────────────────────────────────────────────────┘

工具栏 UI:
┌──────────────────────────────────────────────────────────────┐
│  🔊 朗读  │  🔍 查询  │  📖 翻译  │  📝 总结  │  ⋯  更多     │
└──────────────────────────────────────────────────────────────┘
```

## 第一版按钮功能

| 按钮    | 功能               | 实现                            |
| ------- | ------------------ | ------------------------------- |
| 🔊 朗读 | TTS 朗读选中文本   | EdgeTTSService (后续支持豆包等) |
| 🔍 查询 | 联网搜索 + AI 解释 | Firecrawl 搜索 + LLM Pipeline   |
| 📖 翻译 | 翻译选中文本       | Apple Translation API           |
| 📝 总结 | AI 总结长文本      | LLM Pipeline                    |

### 查询功能详细设计

```
┌─────────────────────────────────────────────────────────────────┐
│                        查询流程                                  │
├─────────────────────────────────────────────────────────────────┤
│  1. 获取选中文本 (selectedText)                                 │
│  2. OCR 当前应用窗口获取上下文 (contextText)                    │
│  3. 联网搜索 (Firecrawl/Perplexity API)                         │
│  4. 构建 Prompt: "根据搜索结果和上下文,解释: {selectedText}"   │
│  5. LLM 生成解释,显示在 AnswerPanel                            │
└─────────────────────────────────────────────────────────────────┘
```

## 技术架构

### 核心组件

```
Services/
├── SelectionMonitorService.swift   # 监听全局文本选择
├── SelectionToolbarManager.swift   # 工具栏窗口管理
└── SearchService.swift             # 联网搜索服务

Core/SelectionToolbar/
├── SelectionToolbarState.swift     # 状态管理
└── SelectionToolbarAction.swift    # 按钮动作定义

UI/SelectionToolbar/
├── SelectionToolbarView.swift      # 工具栏 UI
└── SelectionToolbarWindow.swift    # 悬浮窗口
```

### 全局文本选择监听方案

**方案比较**:

| 方案              | 优点           | 缺点                 | 复杂度 |
| ----------------- | -------------- | -------------------- | ------ |
| AXObserver        | 实时、准确     | 需要辅助功能权限     | 高     |
| CGEventTap        | 监听键鼠事件   | 无法直接获取选中文本 | 中     |
| 定时轮询剪贴板    | 简单           | 延迟、不精确         | 低     |
| NSPasteboard 监听 | 只响应复制操作 | 需要用户按 Cmd+C     | 低     |

**推荐方案**: AXObserver + NSAccessibility

- 监听 `AXSelectedTextChanged` 通知
- 通过 `AXUIElementCopyAttributeValue` 获取选中文本和位置
- 需要辅助功能权限 (`NSAppleEventsUsageDescription`)

### 窗口定位策略

```swift
// 获取选中文本的屏幕位置
func getSelectionBounds() -> CGRect? {
    guard let element = AXUIElementCreateSystemWide() else { return nil }
    var focusedApp: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXFocusedApplicationAttribute, &focusedApp)
    // ... 获取 kAXSelectedTextRangeAttribute 和 kAXBoundsForRangeParameterizedAttribute
}

// 工具栏定位
// - 默认显示在选中文本下方 8px
// - 如果空间不足,显示在上方
// - 避免超出屏幕边界
```

## 权限要求

```xml
<!-- Info.plist -->
<key>NSAppleEventsUsageDescription</key>
<string>监听文本选择以提供快捷操作</string>

<!-- entitlements -->
<key>com.apple.security.automation.apple-events</key>
<true/>
```

用户需要在系统偏好设置 → 安全性与隐私 → 辅助功能 中授权。

## 状态机

```
┌─────────┐  选择文本   ┌──────────┐  点击按钮  ┌───────────┐
│  idle   │ ─────────▶ │ showing  │ ─────────▶ │ executing │
└─────────┘            └──────────┘            └───────────┘
     ▲                      │                       │
     │    点击外部/ESC       │      完成/取消        │
     └──────────────────────┴───────────────────────┘
```

## UI 设计

参考 Apple HIG + 图片样式:

- 圆角胶囊形状 (`cornerRadius: 8`)
- 毛玻璃背景 (`.ultraThinMaterial`)
- 图标 + 文字按钮
- Hover 效果: 背景变亮
- 点击效果: 按压动画

```swift
// 配色
struct ToolbarColors {
    static let background = Color.black.opacity(0.6)
    static let buttonHover = Color.white.opacity(0.1)
    static let separator = Color.white.opacity(0.2)
    static let text = Color.white
    static let icon = Color.white.opacity(0.9)
}
```

## 实现优先级

### P0 (MVP)

1. [x] 基础架构搭建
2. [ ] 辅助功能权限请求
3. [ ] 文本选择监听
4. [ ] 工具栏 UI
5. [ ] 朗读功能 (EdgeTTS)
6. [ ] 查询功能 (搜索 + LLM)

### P1 (增强)

- [ ] 翻译功能
- [ ] 总结功能
- [ ] 自定义按钮顺序
- [ ] 快捷键触发

### P2 (优化)

- [ ] 更多 TTS 提供商 (豆包等)
- [ ] 搜索引擎切换 (Perplexity/Firecrawl/Google)
- [ ] 按钮插件系统

## 风险评估

| 风险                  | 概率 | 影响 | 缓解措施           |
| --------------------- | ---- | ---- | ------------------ |
| 辅助功能权限被拒      | 中   | 高   | 提供清晰的权限说明 |
| 某些应用不支持 AX API | 中   | 中   | 降级为剪贴板监听   |
| 工具栏定位不准确      | 低   | 低   | 提供固定位置选项   |
| AppStore 审核         | 中   | 高   | 准备功能说明       |

## 参考

- PopClip: https://pilotmoon.com/popclip/
- Apple Accessibility: https://developer.apple.com/documentation/accessibility
- AXUIElement: https://developer.apple.com/documentation/applicationservices/axuielement_h
