# Pipeline 来源应用 + Clipboard 节点设计

> 创建时间: 2025-12-09
> 状态: 设计中

## 需求概述

1. **来源应用图标** - 每个 Pipeline 卡片显示来源应用图标（左上角）
2. **光晕颜色区分** - 转录(蓝) / 润色(紫) / 粘贴(橙) 用不同光晕颜色
3. **Clipboard 节点** - 新增从剪贴板读取内容的 Pipeline 来源

## UI 设计

```
Pipeline 卡片结构:
┌─────────────────────────────────────────────────────────────┐
│  [App Icon]  转录 · Apple Speech    10:30:25    [⟳] [×]    │
│  ├─ 光晕颜色: 蓝色 (转录)                                   │
│                                                             │
│  这是转录的文本内容...                                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘

光晕颜色方案:
┌────────────┬────────────┬────────────────────────┐
│ 类型       │ 颜色       │ 说明                    │
├────────────┼────────────┼────────────────────────┤
│ 转录 (ASR) │ 蓝色       │ 语音识别原始结果        │
│ 润色 (LLM) │ 紫色       │ AI 润色处理结果         │
│ 粘贴 (Clip)│ 橙色       │ 从剪贴板读取的内容      │
└────────────┴────────────┴────────────────────────┘
```

## 数据模型

### SourceAppInfo (新增)

```swift
/// 来源应用信息（用于 Pipeline 卡片显示）
struct SourceAppInfo: Codable, Equatable {
    let bundleId: String
    let name: String

    /// 运行时从 bundleId 获取应用图标（不持久化）
    var icon: NSImage? {
        guard let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleId
        ) else { return nil }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }

    /// 从 NSRunningApplication 创建
    static func from(_ app: NSRunningApplication) -> SourceAppInfo {
        SourceAppInfo(
            bundleId: app.bundleIdentifier ?? "unknown",
            name: app.localizedName ?? "Unknown"
        )
    }

    /// 从当前聚焦应用创建
    static func fromFrontmost() -> SourceAppInfo? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return nil
        }
        return from(app)
    }
}
```

### MessageStage 扩展

```swift
enum MessageStage: Equatable, Codable {
    case welcome(String)
    case keyPress(duration: TimeInterval)
    case asr(model: String)      // 转录
    case llm(model: String)      // 润色
    case clipboard               // 新增: 剪贴板来源
    case system(String)

    var color: Color {
        switch self {
        case .asr: return .blue
        case .llm: return .purple
        case .clipboard: return .orange  // 新增
        // ...
        }
    }

    var glowColor: Color {
        // 光晕颜色（更柔和）
        color.opacity(0.6)
    }
}
```

### MessageCard 扩展

```swift
struct MessageCard {
    // ... 现有属性

    /// 来源应用信息
    var sourceApp: SourceAppInfo?
}
```

## 来源应用获取逻辑

```
┌─────────────────────────────────────────────────────────────────┐
│                      来源应用获取时机                            │
├─────────────────────────────────────────────────────────────────┤
│  转录 (ASR):                                                    │
│    - 时机: 录音开始时 (startRecordingSession)                   │
│    - 来源: ContextService.getCurrentTargetApp()                 │
│    - 备注: 录音时的目标应用                                      │
│                                                                 │
│  润色 (LLM):                                                    │
│    - 时机: LLM 处理完成时                                       │
│    - 来源: 继承 ASR 的来源应用（同一次录音会话）                  │
│    - 备注: 转录和润色来自同一个应用                              │
│                                                                 │
│  粘贴 (Clipboard):                                              │
│    - 时机: 触发 Clipboard Pipeline 时                           │
│    - 来源: 当前聚焦应用 (NSWorkspace.frontmostApplication)      │
│    - 备注: 粘贴操作发生时的前台应用                              │
└─────────────────────────────────────────────────────────────────┘
```

## Clipboard Pipeline 流程

```
用户操作: ⌥V (或其他快捷键)
         ↓
┌─────────────────────────────────────────────────────────────────┐
│  1. 读取剪贴板内容 (NSPasteboard.general)                       │
│  2. 获取当前聚焦应用作为来源                                     │
│  3. 创建 MessageCard (stage: .clipboard)                        │
│  4. 可选: 通过 LLM Pipeline 处理                                │
│  5. 显示在 MessagePanel                                         │
└─────────────────────────────────────────────────────────────────┘
```

## UI 实现

### 光晕效果

```swift
/// 卡片光晕视图
struct CardGlowView: View {
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(color, lineWidth: 2)
            .blur(radius: 4)
            .opacity(0.6)
    }
}
```

### 来源图标显示

```swift
/// 卡片头部（带来源应用图标）
private var headerView: some View {
    HStack {
        // 来源应用图标
        if let sourceApp = card.sourceApp {
            SourceAppIconView(sourceApp: sourceApp, glowColor: card.stage.color)
        }

        // 阶段标签
        HStack(spacing: 4) {
            Circle()
                .fill(card.stage.color)
                .frame(width: 6, height: 6)
            Text(card.stage.displayName)
                .font(.system(size: 11, weight: .medium))
        }

        Spacer()

        // 时间戳 + 操作按钮
        // ...
    }
}

/// 来源应用图标视图（带光晕）
struct SourceAppIconView: View {
    let sourceApp: SourceAppInfo
    let glowColor: Color

    var body: some View {
        ZStack {
            // 光晕效果
            Circle()
                .fill(glowColor.opacity(0.3))
                .frame(width: 28, height: 28)
                .blur(radius: 4)

            // 应用图标
            if let icon = sourceApp.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
}
```

## 实现优先级

### P0 (核心)

1. [x] 设计文档
2. [ ] SourceAppInfo 数据模型
3. [ ] MessageCard.sourceApp 字段
4. [ ] MessageStage.clipboard 类型
5. [ ] MessageCardView 图标 + 光晕 UI
6. [ ] RecordingController 集成来源应用

### P1 (增强)

- [ ] Clipboard Pipeline 快捷键触发
- [ ] Clipboard 内容通过 LLM 处理
- [ ] 来源应用点击跳转

## 兼容性

- 旧数据 `sourceApp` 为 nil，正常显示（无图标）
- `MessageCard.init(from:)` 使用 `decodeIfPresent` 兼容

## 风险评估

| 风险             | 概率 | 影响 | 缓解措施                  |
| ---------------- | ---- | ---- | ------------------------- |
| 应用图标获取失败 | 低   | 低   | fallback 显示通用图标     |
| 剪贴板内容过大   | 中   | 中   | 限制最大长度 (10000 字符) |
| 光晕效果性能     | 低   | 低   | 使用简单 blur + opacity   |
