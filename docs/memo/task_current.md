# Screenshot Window Resize Implementation Plan

## 1. 背景分析
### 当前问题
- 用户已能通过 `scrollWheel` 双指垂直滑动缩放窗口，但缺少桌面端应用标配的**边缘拖拽缩放 (Edge Resizing)**。
- 当前窗口 `styleMask: [.borderless]`，系统级 Resize 已被禁用，导致无法通过鼠标拖动边缘调整大小。
- 窗口移动逻辑目前在 `ScreenshotWindow.mouseDragged` 中手动实现，且与未来的 Resize 逻辑在事件上存在重叠（都是鼠标拖动）。

### 目标
- 实现**无边框窗口 (Borderless Window)** 的边缘拖拽缩放功能。
- 在 Window Frame 本身增加一条不可见的 "Resizing Border"（逻辑区域）。
- **保留** 窗口中央区域（点击空白处）的拖拽移动功能。
- 动态光标反馈：根据鼠标在边缘的位置显示 `resizeUpDown`, `resizeLeftRight`, `resizeDiagonal` 等光标。

## 2. 方案对比

| 方案 | 描述 | 优点 | 缺点 | 推荐度 |
|------|------|------|------|--------|
| **A. 系统级 Resize (`styleMask: .resizable`)** | 开启 `.resizable` 并让系统与 `styleMask: .borderless` 配合（不可用）。 | 系统原生体验。 | macOS 无边框窗口开启 Resizable 后系统并不提供边框 Handle，且会强制添加圆角/阴影，与我们要的极简风格冲突。 | ⭐ |
| **B. 内容视图边缘检测 (ContentView Edge Control)** | 在 `ScreenshotContentView` 中处理鼠标事件，检测边缘。 | 逻辑内聚在 View 层。 | 污染 View 代码（View 应该只负责渲染内容）；坐标转换复杂；容易被 `LiveTextOverlay` 覆盖吃掉事件。 | ⭐⭐ |
| **C. 窗口级边缘检测 (Window Edge Control)** | 在 `ScreenshotWindow` 覆写 `mouseDown/Dragged/Moved`，在 Window 坐标系下检测边缘。 | **解耦**：Window 负责 Frame 管理，View 负责内容；**层级高**：直接在 Window 层处理，不受 Subview 遮挡影响（需做 HitTest 或 Event 传递协同）；**性能好**。 | 需要手动计算 Frame Delta 和 Anchor Point。 | ⭐⭐⭐⭐⭐ |

### 推荐方案
**方案 C (Window Edge Control)**。这最符合 macOS AppKit 的底层机制，也符合 Clean Architecture 原则（Window 负责自身几何形态）。

## 3. 详细设计

### 3.1 文件变更
| 文件路径 | 操作 | 说明 |
|----------|------|------|
| `spoke/UI/Screenshot/ScreenshotWindow.swift` | 修改 | 重写 `mouseDown`, `mouseDragged`, `mouseUp`, `mouseMoved`；<br>添加 `ResizeEdge` 枚举、`currentOperation` 状态、`frameForEdge` 计算逻辑。 |

### 3.2 核心逻辑设计

#### 3.2.1 状态枚举
```swift
enum WindowOperation {
    case none
    case moving(initialLocation: NSPoint)
    case resizing(edge: ResizeEdge, initialLocation: NSPoint, originalFrame: CGRect)
}

struct ResizeEdge: OptionSet {
    let rawValue: Int
    static let top    = ResizeEdge(rawValue: 1 << 0)
    static let bottom = ResizeEdge(rawValue: 1 << 1)
    static let left   = ResizeEdge(rawValue: 1 << 2)
    static let right  = ResizeEdge(rawValue: 1 << 3)
    // 组合
    static let topLeft: ResizeEdge = [.top, .left]
    // ...
}
```

#### 3.2.2 边缘检测逻辑 (`mouseMoved` & `mouseDown`)
- 定义 `borderWidth = 6.0`。
- 获取 `event.locationInWindow`。
- 判断点是否在矩形的 `borderWidth` 范围内：
  - `x < borderWidth` -> Left
  - `x > width - borderWidth` -> Right
  - `y < borderWidth` -> Bottom (AppKit y 向上，但 locationInWindow y=0 是底部) -> **Wait**, AppKit `locationInWindow` 原点在窗口左下角。 `y < borderWidth` is Bottom.
  - `y > height - borderWidth` -> Top。

#### 3.2.3 拖拽计算 (`mouseDragged`)
- **Move**: `window.setFrameOrigin(current + delta)`。
- **Resize**:
  - 计算 `delta = currentLocation - initialLocation`。
  - 根据 `ResizeEdge` 修改 `frame`：
    - `.right`: `width += delta.x`
    - `.left`: `origin.x += delta.x`, `width -= delta.x`
    - `.top`: `height += delta.y`
    - `.bottom`: `origin.y += delta.y`, `height -= delta.y`
  - **约束**: `minSize` (e.g. 100x100) 和 `maxSize`。保持 `aspectRatio`？
    - **决策**: 自由拉伸还是保持比例？
    - 现有逻辑 `scrollWheel` 是保持比例的。
    - 边缘拖拽通常允许自由拉伸，但对于截图来说，拉伸会导致图片变形（View 是 `.scaleToFit`）或留白。
    - **改进**: 边缘拖拽应**保持长宽比** (Aspect Ratio Locked)，否则图片会有黑边或裁剪。
    - **逻辑**: 如果拖动 Right 边缘，`newWidth` 变了，`newHeight` 必须根据 `imageAspectRatio` 同步变化。

### 3.3 数据流图
```mermaid
graph TD
    A[User Mouse Event] --> B{ScreenshotWindow}
    B -- mouseMoved --> C[Update Cursor (Resize/Arrow)]
    B -- mouseDown --> D[Determine Operation]
    D -- On Edge --> E[Status = Resizing(Edge)]
    D -- On Content --> F[Status = Moving]
    
    B -- mouseDragged --> G{Status?}
    G -- Resizing --> H[Calculate new Frame (Keep Aspect Ratio)]
    G -- Moving --> I[Set Frame Origin]
    
    H --> J[Set Window Frame]
    I --> J
    J --> K[View Redraws]
```

## 4. 测试计划
- [ ] **光标测试**: 鼠标悬停在四边和四角，光标应变为对应的双向箭头。
- [ ] **拖拽测试**:
  - 拖动 Right 边缘：宽度增加，高度按比例增加，左上位置不变。
  - 拖动 Left 边缘：宽度增加，高度按比例增加，**右侧**位置不变（Origin X 变化）。
  - 拖动 Corner：同理。
- [ ] **移动测试**: 点击中间区域拖动，窗口整体移动，大小不变。
- [ ] **冲突测试**: Live Text 覆盖区域是否还能拖动？（Window 层级优先，应该没问题，除非 LiveText 吃掉了事件）。如果吃掉事件，则需要 LiveTextOverlay 穿透。
- [ ] **最小尺寸**: 无法缩小到小于 `padding + 40`。

## 5. 风险评估
| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| **ContentView 事件拦截** | ContentView 如果有 `mouseDown` 且不调 super，Window 接收不到。 | 确认 `ScreenshotContentView` 的 `mouseDown` 逻辑；甚至可以将拖拽逻辑 "下沉" 到 ContentView 中做，或者让 View 忽略背景点击。但目前方案是在 Window 层截获。如果 View 填满 Window，View 会先收到。**修正**: 在 `ScreenshotWindow` 中使用 `sendEvent` 截获，或者在 View 中把未处理事件传给 Window。最稳妥是：View 不处理 `mouseDown` (或者 `return super.mouseDown`)。 |
| **Resize 颤动** | 计算逻辑频繁更新 Frame 导致 UI 闪烁。 | `setFrame(..., animate: false)`；保持比例计算要精确。 |
| **坐标系混淆** | 屏幕坐标 vs 窗口坐标。 | 统一使用 `window.convert(toScreen:)` 或保持在 Window 坐标系计算 Delta。 |

## 6. 当前进度
- [x] 设计完成
- [ ] 实现完成
- [ ] 验证通过
