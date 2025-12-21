# 截图功能重构方案

## 目标
1. ✅ 修复截图错位问题（精确获取选区坐标）
2. ✅ 支持 Pin 图边角拖动缩放
3. ✅ 截图时支持标注功能

## 架构设计

### 新增文件
```
spoke/
├── UI/Screenshot/
│   ├── RegionSelectionWindow.swift    # 全屏选区覆盖窗口
│   ├── RegionSelectionView.swift      # 选区交互视图（框选+标注）
│   ├── AnnotationToolbar.swift        # 标注工具栏
│   ├── AnnotationCanvasView.swift     # 标注画布
│   └── ResizeHandleView.swift         # 边角缩放手柄
├── Core/Screenshot/
│   └── ScreenshotAnnotation.swift     # 标注数据模型
```

### 修改文件
```
- ScreenshotManager.swift       # 使用新选区 UI 替代 screencapture -i
- ScreenshotWindow.swift        # 添加边角缩放手柄
- ScreenshotContentView.swift   # 集成缩放手柄
```

---

## Phase 1: 修复截图错位 + 自建选区 UI

### 1.1 RegionSelectionWindow
```swift
/// 全屏透明窗口，覆盖所有屏幕
final class RegionSelectionWindow: NSPanel {
    // - level = .screenSaver (最高层级)
    // - backgroundColor = .clear
    // - isOpaque = false
    // - styleMask = [.borderless, .nonactivatingPanel]
    // - collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    // - 覆盖所有屏幕的 union frame
}
```

### 1.2 RegionSelectionView
```swift
/// 选区交互视图
final class RegionSelectionView: NSView {
    // 状态
    var selectionRect: CGRect = .zero
    var isSelecting: Bool = false
    var startPoint: CGPoint = .zero
    
    // 鼠标事件
    override func mouseDown(with event: NSEvent)    // 记录起点
    override func mouseDragged(with event: NSEvent) // 更新选区
    override func mouseUp(with event: NSEvent)      // 完成选区
    
    // 绘制
    override func draw(_ dirtyRect: NSRect) {
        // 1. 半透明遮罩覆盖全屏
        // 2. 选区内部透明（挖空效果）
        // 3. 选区边框高亮（蓝色/白色）
        // 4. 显示尺寸标签（如 "606 × 255 pt"）
    }
    
    // 键盘
    override func keyDown(with event: NSEvent) {
        // ESC 取消
        // Enter 确认
    }
    
    // 回调
    var onComplete: ((CGRect, NSImage) -> Void)?
    var onCancel: (() -> Void)?
}
```

### 1.3 修改 ScreenshotManager.captureRegion()
```swift
func captureRegion() async {
    // 1. 先用 ScreenCaptureKit 截取全屏
    let fullScreenImage = await captureAllScreens()
    
    // 2. 显示选区 UI
    let selectionWindow = RegionSelectionWindow()
    selectionWindow.setImage(fullScreenImage) // 作为背景
    
    // 3. 等待用户选择
    await withCheckedContinuation { continuation in
        selectionWindow.onComplete = { rect, croppedImage in
            // rect 就是精确的选区坐标！
            self.createScreenshotItem(image: croppedImage, frame: rect)
            continuation.resume()
        }
        selectionWindow.onCancel = {
            continuation.resume()
        }
    }
}
```

---

## Phase 2: 边角拖动缩放

### 2.1 ResizeHandleView
```swift
/// 边角缩放手柄
final class ResizeHandleView: NSView {
    enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    let corner: Corner
    
    // 手柄样式：8x8 白色圆点，hover 时放大
    // 鼠标拖动时通知父视图调整 frame
    
    var onResize: ((CGSize) -> Void)?
}
```

### 2.2 修改 ScreenshotContentView
```swift
// 添加四个角的缩放手柄
private var resizeHandles: [ResizeHandleView] = []

private func setupResizeHandles() {
    for corner in ResizeHandleView.Corner.allCases {
        let handle = ResizeHandleView(corner: corner)
        handle.onResize = { [weak self] delta in
            self?.handleResize(corner: corner, delta: delta)
        }
        addSubview(handle)
        resizeHandles.append(handle)
    }
}

// Hover 时显示手柄
func updateHandlesVisibility(isHovered: Bool) {
    resizeHandles.forEach { $0.isHidden = !isHovered }
}
```

---

## Phase 3: 标注功能

### 3.1 AnnotationToolbar（参考图二）
工具按钮：
- 📷 区域选择（重新选区）
- 〰️ 曲线/自由画笔
- ✏️ 直线
- ❌ 橡皮擦
- 📦 矩形/椭圆
- 🔤 文字
- 🔲 马赛克
- ↩️ 撤销
- ↪️ 重做
- 💾 保存
- 📋 复制
- ✅ 确认

### 3.2 AnnotationCanvasView
```swift
/// 标注画布（覆盖在截图上）
final class AnnotationCanvasView: NSView {
    var annotations: [ScreenshotAnnotation] = []
    var currentTool: AnnotationTool = .arrow
    
    // 绘制所有标注
    override func draw(_ dirtyRect: NSRect) {
        for annotation in annotations {
            annotation.draw(in: self)
        }
    }
}
```

### 3.3 ScreenshotAnnotation 数据模型
```swift
struct ScreenshotAnnotation: Codable {
    let id: UUID
    let type: AnnotationType
    let points: [CGPoint]
    let color: NSColor
    let strokeWidth: CGFloat
    let text: String?  // 文字标注
}

enum AnnotationType: String, Codable {
    case arrow, line, rectangle, ellipse, freehand, text, mosaic
}
```

---

## 实现顺序

| 步骤 | 任务 | 预计时间 |
|------|------|----------|
| 1 | RegionSelectionWindow + View | 30min |
| 2 | 集成到 ScreenshotManager | 15min |
| 3 | 测试选区精确性 | 10min |
| 4 | ResizeHandleView | 20min |
| 5 | 集成到 ScreenshotContentView | 15min |
| 6 | AnnotationToolbar | 30min |
| 7 | AnnotationCanvasView | 45min |

---

## 风险与备选

1. **ScreenCaptureKit 权限**：需要屏幕录制权限，已有检查逻辑
2. **多显示器**：选区窗口需要跨越所有屏幕
3. **性能**：全屏截图作为背景可能有性能问题 → 使用 CALayer 优化
4. **App Store 合规**：ScreenCaptureKit 是公开 API ，合规

---

## 待确认

请确认是否开始实现？回复：
- **'go'** - 开始按顺序实现
- **'adjust'** - 需要调整方案
