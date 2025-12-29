# Brainstorm Synthesis: 无感截图与智能吸附

## Aligned Decisions
1. **遮罩策略 (Hole-Punching)**:
   - 保持半透明黑色背景遮罩。
   - 选区区域完全透明（挖空），利用明暗对比显示范围。
   - **移除**所有显性的边框线。

2. **光标与放大镜 (Cursor & Loupe)**:
   - **隐藏系统光标**。
   - 手动绘制**自定义小十字**。
   - 实现**实时放大镜**：跟随鼠标，显示当前像素细节，辅助精准裁剪。

3. **技术路线 (App Store Safe)**:
   - 窗口吸附使用 **ScreenCaptureKit (SCK)**。
   - **合规性确认**: SCK 是 Apple 官方推荐的 macOS 12.3+ API，完全符合沙盒机制和 App Store 审核标准，无风险。

## Conflicts Identified
- **Conflict 1**: 放大镜的性能开销。
  - **Resolution**: 直接从已缓存的 `backgroundImage` 采样，不做实时屏幕捕获，性能开销极低（GPU 纹理采样）。

## Unified Proposal

### Phase 1: 交互视觉重构 (Immediate)
- **Action**:
  1. **RegionSelectionView**:
     - `drawOverlay`: 确保挖空逻辑正确，移除边框绘制代码。
     - `drawMagnifier`: 新增放大镜绘制逻辑（圆形/圆角矩形，3x-4x 放大）。
     - `drawCursor`: 绘制自定义小十字。
  2. **Cursor Hiding**: 在视图内隐藏系统光标。

### Phase 2: 窗口智能吸附 (Feasibility)
- 使用 `SCShareableContent` 获取窗口 Frame。
- 鼠标悬停时，若检测到窗口边缘，自动吸附（Snap）。
- **合规性**: 100% 合规。

## 代码修改清单 (Phase 1)
| 文件 | 修改点 | 说明 |
|------|--------|------|
| `UI/Screenshot/RegionSelectionView.swift` | `draw` | 1. 移除边框绘制 2. 添加放大镜绘制 3. 绘制自定义光标 |
| `UI/Screenshot/RegionSelectionView.swift` | `mouseMoved` | 强制重绘以更新放大镜和光标位置 |
| `UI/Screenshot/RegionSelectionWindow.swift` | `cursor` | `NSCursor.hide()` |
