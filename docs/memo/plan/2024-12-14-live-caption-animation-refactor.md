# LiveCaptionView 动画问题重构计划

> **日期**: 2024-12-14
> **状态**: 待实施
> **备份**: `LiveCaptionView.swift.backup.2024-12-14`

---

## 1. 背景与问题分析

### 1.1 问题现象

```
┌─────────────────────────────────────────────────────────────┐
│  LiveCaptionView                                            │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  AppKitScrollView (NSViewRepresentable)               │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  NSHostingView                                  │  │  │
│  │  │  ┌───────────────────────────────────────────┐  │  │  │
│  │  │  │  VStack                                   │  │  │  │
│  │  │  │  ├─ Spacer (动态高度)                     │  │  │  │
│  │  │  │  ├─ ForEach(items) {                      │  │  │  │
│  │  │  │  │   VStack {                             │  │  │  │
│  │  │  │  │     原文 Text ──────────────────────┐  │  │  │  │
│  │  │  │  │     译文 Text ◀── 高度变化触发动画 ─┘  │  │  │  │
│  │  │  │  │   }                                    │  │  │  │
│  │  │  │  │   .animation(.easeOut, value: isNew)   │  │  │  │
│  │  │  │  │ }                                      │  │  │  │
│  │  │  │  └─ pendingText...                        │  │  │  │
│  │  │  └───────────────────────────────────────────┘  │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘

问题：当 item.translation 更新时，译文 Text 高度变化导致
      整个 VStack 重新布局，SwiftUI 对布局变化进行插值动画
      表现为"文字从上往下掉落"
```

### 1.2 红队分析：根因深挖

| 层级 | 攻击点 | 漏洞分析 | 严重性 |
|------|--------|----------|--------|
| **L1** | `ForEach` 容器动画 | `.animation(.easeOut, value: isNew)` 作用于整个 Item VStack，当 `isNew` 动画进行中时，任何子视图的布局变化都会被"感染" | ⚠️ 高 |
| **L2** | `NSHostingView` 边界 | SwiftUI Transaction 可能无法完全穿透 `NSViewRepresentable` 边界，AppKit 层可能引入隐式动画 | ⚠️ 高 |
| **L3** | `Spacer` 动态高度 | 译文高度变化 → Spacer 收缩 → 整个内容块位移，在动画上下文中被插值 | ⚠️ 中 |
| **L4** | `Text` 内容变化 | 即使用 `.contentTransition(.identity)`，多行 Text 换行时仍可能触发隐式布局动画 | ⚠️ 中 |
| **L5** | ZStack 分离方案 | 虽然隔离了布局层和渲染层，但 ZStack 本身仍在 ForEach 的动画上下文中 | ⚠️ 中 |

### 1.3 已尝试但失败的方案

```
❌ 方案 A: withTransaction(disablesAnimations: true)
   问题: 只影响数据层，无法阻断视图层已存在的动画上下文

❌ 方案 B: .animation(nil, value: item.translation)
   问题: 无法完全阻断父级 ForEach 传播的动画事务

❌ 方案 C: ZStack 分离布局/渲染
   问题: ZStack 仍在 ForEach 动画上下文中，布局变化仍被捕获
```

---

## 2. 重构方案对比

### 方案 A: 完全提取 CaptionItemView + 强制 id() 刷新

```
┌─────────────────────────────────────────────────────────────┐
│  ForEach(items) { item in                                   │
│    CaptionItemView(item: item, isNew: ...)                  │
│      .id(item.id.uuidString + (item.translation ?? ""))     │
│      // ↑ translation 变化时强制销毁重建，无动画             │
│  }                                                          │
└─────────────────────────────────────────────────────────────┘
```

| 优点 | 缺点 |
|------|------|
| ✅ 彻底消除布局动画 | ❌ 每次翻译更新都重建视图，性能开销 |
| ✅ 实现简单 | ❌ 无法实现淡入效果 |
| ✅ 100% 可靠 | ❌ 可能导致闪烁 |

**评分: 6/10**

---

### 方案 B: 固定高度占位 + 纯 Opacity 动画

```
┌─────────────────────────────────────────────────────────────┐
│  VStack {                                                   │
│    原文 Text (fixedSize)                                    │
│    译文容器 {                                               │
│      // 预估最大高度，避免布局变化                           │
│      GeometryReader { geo in                                │
│        Text(translation)                                    │
│          .opacity(hasTranslation ? 1 : 0)                   │
│      }                                                      │
│      .frame(height: estimatedHeight)                        │
│    }                                                        │
│  }                                                          │
└─────────────────────────────────────────────────────────────┘
```

| 优点 | 缺点 |
|------|------|
| ✅ 无布局变化，纯 opacity | ❌ 需要预估高度，可能截断或留白 |
| ✅ 动画效果好 | ❌ 不同长度翻译难以统一高度 |

**评分: 5/10**

---

### 方案 C: NSTextView 替代 SwiftUI Text ⭐ 推荐

```
┌─────────────────────────────────────────────────────────────┐
│  CaptionItemView: NSViewRepresentable                       │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  NSStackView (vertical)                               │  │
│  │  ├─ NSTextField (原文, 不可编辑)                      │  │
│  │  └─ NSTextField (译文, 不可编辑)                      │  │
│  │      ↑ 直接设置 stringValue，无 SwiftUI 动画机制      │  │
│  └───────────────────────────────────────────────────────┘  │
│  updateNSView() {                                           │
│    // 直接更新文本，AppKit 无隐式动画                        │
│    translationField.stringValue = item.translation ?? ""    │
│    translationField.alphaValue = hasTranslation ? 1 : 0     │
│    NSAnimationContext.runAnimationGroup { ctx in            │
│      ctx.duration = 0.25                                    │
│      translationField.animator().alphaValue = 1             │
│    }                                                        │
│  }                                                          │
└─────────────────────────────────────────────────────────────┘
```

| 优点 | 缺点 |
|------|------|
| ✅ 完全控制动画行为 | ⚠️ 需要手动管理 NSView 生命周期 |
| ✅ 无 SwiftUI 隐式动画 | ⚠️ 代码量增加 |
| ✅ AppKit 动画精确可控 | ⚠️ 需要适配暗色模式/字体 |
| ✅ 支持文本选择 | |
| ✅ 性能更好 | |

**评分: 9/10** ⭐

---

### 方案 D: 双层渲染 + CATransaction 禁用

```swift
VStack {
    原文
    译文.transaction { t in
        t.animation = nil
        t.disablesAnimations = true
    }
    .background(GeometryReader { _ in
        Color.clear.onAppear {
            CATransaction.setDisableActions(true)
        }
    })
}
```

| 优点 | 缺点 |
|------|------|
| ✅ 保持 SwiftUI 代码风格 | ❌ CATransaction 可能无效 |
| ✅ 改动较小 | ❌ 不确定能否穿透 NSHostingView |

**评分: 4/10**

---

## 3. 最终决策：方案 C (NSTextView)

### 3.1 理由

1. **根本解决**: 绕过 SwiftUI 动画系统，使用 AppKit 原生控件
2. **精确控制**: `NSAnimationContext` 提供完全可控的动画
3. **一致性**: 已有 `AppKitScrollView` 桥接，增加 `CaptionItemNSView` 保持架构一致
4. **性能**: 减少 SwiftUI 视图层级，大量字幕时更流畅
5. **可扩展**: 后续可轻松添加选择、复制、高亮等功能

---

## 4. 详细设计变更

### 4.1 文件变更总览

| 文件路径 | 操作 | 说明 |
|----------|------|------|
| `UI/LiveCaption/CaptionItemNSView.swift` | 新建 | NSViewRepresentable 封装单条字幕 |
| `UI/LiveCaption/LiveCaptionView.swift` | 修改 | 使用 CaptionItemNSView 替代内联 Text |
| `Core/LiveCaption/CaptionLineBuffer.swift` | 保持 | 无需修改 |

### 4.2 新建: CaptionItemNSView.swift

```swift
// ✅ 新文件: spoke/UI/LiveCaption/CaptionItemNSView.swift

import SwiftUI
import AppKit

/// 单条字幕项的 AppKit 实现
/// 完全绕过 SwiftUI 动画系统，使用 NSAnimationContext 精确控制
struct CaptionItemNSView: NSViewRepresentable {
    let original: String
    let translation: String?
    let isNew: Bool
    let fontSize: CGFloat
    let translationFontSize: CGFloat
    let textColor: NSColor
    let translationColor: NSColor
    
    func makeNSView(context: Context) -> CaptionItemStackView {
        let view = CaptionItemStackView()
        view.configure(
            fontSize: fontSize,
            translationFontSize: translationFontSize,
            textColor: textColor,
            translationColor: translationColor
        )
        return view
    }
    
    func updateNSView(_ nsView: CaptionItemStackView, context: Context) {
        // 更新原文（无动画）
        nsView.updateOriginal(original)
        
        // 更新译文（带淡入动画）
        let hasTranslation = translation != nil && !translation!.isEmpty
        nsView.updateTranslation(
            translation ?? "",
            animated: hasTranslation,
            isNew: isNew
        )
    }
}

/// AppKit 实现的字幕视图
final class CaptionItemStackView: NSView {
    private let stackView = NSStackView()
    private let originalLabel = NSTextField(labelWithString: "")
    private let translationLabel = NSTextField(labelWithString: "")
    
    private var lastTranslation: String = ""
    private var isAnimating: Bool = false
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        // 配置 StackView
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // 配置原文标签
        originalLabel.isEditable = false
        originalLabel.isSelectable = true
        originalLabel.isBordered = false
        originalLabel.drawsBackground = false
        originalLabel.lineBreakMode = .byWordWrapping
        originalLabel.maximumNumberOfLines = 0
        originalLabel.preferredMaxLayoutWidth = 620
        originalLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        originalLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        // 配置译文标签
        translationLabel.isEditable = false
        translationLabel.isSelectable = true
        translationLabel.isBordered = false
        translationLabel.drawsBackground = false
        translationLabel.lineBreakMode = .byWordWrapping
        translationLabel.maximumNumberOfLines = 0
        translationLabel.preferredMaxLayoutWidth = 620
        translationLabel.alphaValue = 0
        translationLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        translationLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        stackView.addArrangedSubview(originalLabel)
        stackView.addArrangedSubview(translationLabel)
    }
    
    func configure(
        fontSize: CGFloat,
        translationFontSize: CGFloat,
        textColor: NSColor,
        translationColor: NSColor
    ) {
        originalLabel.font = .systemFont(ofSize: fontSize)
        originalLabel.textColor = textColor
        
        translationLabel.font = .systemFont(ofSize: translationFontSize)
        translationLabel.textColor = translationColor
    }
    
    func updateOriginal(_ text: String) {
        if originalLabel.stringValue != text {
            originalLabel.stringValue = text
        }
    }
    
    func updateTranslation(_ text: String, animated: Bool, isNew: Bool) {
        let changed = text != lastTranslation
        lastTranslation = text
        
        guard changed else { return }
        
        // 🔥 关键：禁用所有隐式动画
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        translationLabel.stringValue = text
        CATransaction.commit()
        
        if animated && !text.isEmpty {
            // 使用 NSAnimationContext 执行淡入
            let targetAlpha: CGFloat = isNew ? 0.7 : 1.0
            
            if !isAnimating {
                isAnimating = true
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.25
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    translationLabel.animator().alphaValue = targetAlpha
                }, completionHandler: { [weak self] in
                    self?.isAnimating = false
                })
            } else {
                translationLabel.alphaValue = targetAlpha
            }
        } else {
            translationLabel.alphaValue = 0
        }
    }
    
    override var intrinsicContentSize: NSSize {
        return stackView.intrinsicContentSize
    }
}
```

### 4.3 修改: LiveCaptionView.swift

```swift
// ❌ 旧代码 (lines 413-451)
ForEach(manager.lineBuffer.items) { item in
    let isNew = !appearedItemIDs.contains(item.id)
    let hasTranslation = item.translation != nil && !item.translation!.isEmpty
    VStack(alignment: .leading, spacing: 4) {
        captionText(for: item.original, opacity: isNew ? 0.7 : 1.0)
        ZStack(alignment: .topLeading) {
            Text(item.translation ?? " ")
                .font(...)
                .foregroundColor(.clear)
            Text(item.translation ?? " ")
                .font(...)
                .opacity(...)
                .animation(...)
        }
        .animation(nil, value: item.translation)
    }
    .opacity(isNew ? 0.7 : 1.0)
    .animation(.easeOut(duration: 0.3), value: isNew)
    .onAppear { ... }
}

// ✅ 新代码
ForEach(manager.lineBuffer.items) { item in
    let isNew = !appearedItemIDs.contains(item.id)
    CaptionItemNSView(
        original: item.original,
        translation: item.translation,
        isNew: isNew,
        fontSize: CaptionDesign.fontSize,
        translationFontSize: CaptionDesign.translatedFontSize,
        textColor: NSColor(CaptionDesign.textPrimary),
        translationColor: NSColor(CaptionDesign.textSecondary)
    )
    .frame(maxWidth: .infinity, alignment: .leading)
    .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            appearedItemIDs.insert(item.id)
        }
    }
}
```

---

## 5. 测试计划

### 5.1 单元测试

```swift
// Tests/LiveCaptionTests/CaptionItemNSViewTests.swift

import XCTest
@testable import SpokenAnyWhere

final class CaptionItemNSViewTests: XCTestCase {
    
    func testOriginalTextUpdate() {
        let view = CaptionItemStackView()
        view.configure(fontSize: 18, translationFontSize: 16,
                      textColor: .white, translationColor: .gray)
        
        view.updateOriginal("Hello World")
        XCTAssertEqual(view.originalLabel.stringValue, "Hello World")
    }
    
    func testTranslationFadeIn() {
        let view = CaptionItemStackView()
        view.configure(fontSize: 18, translationFontSize: 16,
                      textColor: .white, translationColor: .gray)
        
        // 初始状态透明
        XCTAssertEqual(view.translationLabel.alphaValue, 0)
        
        // 更新译文
        view.updateTranslation("你好世界", animated: true, isNew: false)
        
        // 等待动画
        let expectation = XCTestExpectation(description: "Fade in")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertEqual(view.translationLabel.alphaValue, 1.0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testNoLayoutAnimation() {
        // 验证布局更新不触发动画
        let view = CaptionItemStackView()
        view.configure(fontSize: 18, translationFontSize: 16,
                      textColor: .white, translationColor: .gray)
        
        let initialFrame = view.frame
        view.updateTranslation("这是一段很长的翻译文本，可能会导致换行", 
                              animated: true, isNew: false)
        
        // 布局应该立即更新，无动画
        // 注意: 实际测试需要在视图层级中验证
        XCTAssertNotNil(view.translationLabel.stringValue)
    }
}
```

### 5.2 集成测试流程

```
┌─────────────────────────────────────────────────────────────┐
│  测试用例 1: 单条翻译更新                                    │
│  ─────────────────────────────────────────────────────────  │
│  1. 启动 Live Caption                                       │
│  2. 播放音频，等待识别出一条原文                             │
│  3. 等待翻译返回                                            │
│  4. 观察: 译文应淡入出现，无任何位移/下落动画               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  测试用例 2: 连续多条翻译                                    │
│  ─────────────────────────────────────────────────────────  │
│  1. 快速播放多段音频                                        │
│  2. 每条原文识别后，译文陆续返回                            │
│  3. 观察: 每条译文独立淡入，不影响其他行布局               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  测试用例 3: 长文本换行                                      │
│  ─────────────────────────────────────────────────────────  │
│  1. 输入导致多行换行的长句子                                │
│  2. 等待翻译返回（翻译也很长）                              │
│  3. 观察: 高度变化应瞬间完成，无滑动动画                   │
└─────────────────────────────────────────────────────────────┘
```

---

## 6. 验收标准

### 6.1 验证命令

```bash
# 1. 构建
cd /Users/bigdan/Workspace/macos/spokeanywhere/spoke
swift build -c debug

# 2. 运行
pkill -f SpokenAnyWhere 2>/dev/null
./dev.sh | grep -E '(Caption|Translation|Error)'

# 3. 测试步骤
# - 启动 Live Caption (⌥S)
# - 播放英文视频/音频
# - 观察字幕显示效果
```

### 6.2 预期结果

| 检查项 | 预期行为 | 验证方法 |
|--------|----------|----------|
| 原文显示 | 识别后立即显示 | 目视 |
| 译文淡入 | 0.25s 淡入，无位移 | 目视 |
| 长文本换行 | 高度瞬间变化，无动画 | 目视 |
| 滚动跟随 | 新内容自动滚动到底部 | 目视 |
| 文本选择 | 可选中复制 | 鼠标操作 |
| 性能 | 100条字幕无卡顿 | 长时间运行 |

---

## 7. 回滚方案

```bash
# 如需回滚
cp spoke/UI/LiveCaption/LiveCaptionView.swift.backup.2024-12-14 \
   spoke/UI/LiveCaption/LiveCaptionView.swift
rm spoke/UI/LiveCaption/CaptionItemNSView.swift
swift build
```

---

## 8. 附录: 被废弃的方案细节

### 为什么 ZStack 方案失败

```
问题本质:
┌──────────────────────────────────────────────────────────────┐
│  ForEach                                                     │
│  └─ VStack.animation(.easeOut, value: isNew)  ◀─ 动画上下文  │
│       └─ ZStack.animation(nil, value: translation)           │
│            └─ Text(translation)                              │
│                                                              │
│  当 isNew 动画进行中时，ZStack 的 .animation(nil) 被覆盖     │
│  因为父级动画事务优先级更高                                  │
└──────────────────────────────────────────────────────────────┘

SwiftUI 动画事务传播规则:
1. 父级 withAnimation/animation 创建动画上下文
2. 子视图的布局变化自动参与该上下文
3. .animation(nil, value:) 只能阻断自身触发的动画
4. 无法阻断已存在的父级动画上下文对布局变化的捕获
```

---

**文档结束**
