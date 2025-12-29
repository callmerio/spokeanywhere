# Architect Analysis: 无感截图与窗口吸附技术实现

## Architecture Overview
本阶段涉及 UI 渲染层（RegionSelectionWindow）与底层捕获层（ScreenCaptureKit/Accessibility）的深度交互。核心在于“高性能绘制”与“实时元数据获取”。

## Component Design

### 1. 透明选区窗口 (Transparent Overlay)
- **实现原理**: `NSWindow` 设置 `backgroundColor = .clear`, `isOpaque = false`, `hasShadow = false`。
- **绘制逻辑**:
  - 移除所有半透明遮罩 (`drawOverlay` 逻辑)。
  - 仅绘制 1px 边框与控制点。
  - **关键点**: 必须确保 `ignoresMouseEvents = false`，但视觉上不可见。
- **状态指示**: 需增强鼠标光标（Cursor）的视觉反馈，因为没有全局遮罩了。

### 2. 窗口吸附引擎 (Snapping Engine)
- **技术选型**:
  - **Plan A (ScreenCaptureKit)**: `SCShareableContent` 提供所有窗口的 Frame 和元数据。
    - *优点*: 性能极高，无权限焦虑（已授权）。
    - *缺点*: 只能获取 Window 级别，无法获取 Button/Panel 级别。
    - *刷新率*: 需测试高频调用 `current` 的开销，可能需要缓存+四叉树检索。
  - **Plan B (Accessibility API)**: `AXUIElement`。
    - *优点*: 可获取 DOM 级别的 UI 元素。
    - *缺点*: 性能差，需开启辅助功能权限（用户门槛高）。
  - **Plan C (Quartz Window Services)**: `CGWindowListCopyWindowInfo`。
    - *缺点*: 旧 API，逐渐被 SCK 取代。
- **推荐方案**: **Plan A (SCK)** 作为主力。因为产品需求是“监控窗口”，SCK 足以覆盖 Top-level Windows。

## Tech Stack & Data Flow

### 实时吸附流 (Snapping Flow)
1. **Init**: 截图开始时，一次性获取 `SCShareableContent`（已在 Phase 1 缓存）。
2. **Indexing**: 将所有窗口 Frame 构建为 **R-Tree** 或简单的 **Grid Index**，用于 O(1) 命中测试。
3. **Loop**: `mouseMoved` 事件 -> 查索引 -> 获取高亮 Frame -> 绘制“内发光”层。
4. **Render**: 使用 `CAShapeLayer` 绘制高亮框，性能优于 `drawRect`。

## Risk Assessment

### 1. 视觉混淆 (Visual Confusion)
- **风险**: 用户可能分不清“这是桌面上的真窗口”还是“截图工具的高亮框”。
- **缓解**: 高亮框必须有独特的视觉特征（如呼吸灯效果，或明显的 Tint Color）。

### 2. 性能抖动 (Jank)
- **风险**: 鼠标快速划过大量窗口时，频繁重绘可能导致掉帧。
- **缓解**: 添加 `Debounce` (如 16ms) 或仅在鼠标停顿微小阈值后触发高亮。

### 3. 多屏坐标系 (Coordinate Hell)
- **风险**: SCK 返回的坐标是 Global Space，需准确映射到 `RegionSelectionWindow` 的 Local Space。
- **缓解**: 统一使用 `CGWindowList` 的坐标系，并在 Window 内部做 convert。
