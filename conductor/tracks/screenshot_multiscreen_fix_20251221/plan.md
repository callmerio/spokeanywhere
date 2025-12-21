# Plan: Multi-Screen Screenshot Bugs Fix

**Track ID**: screenshot_multiscreen_fix_20251221  
**Type**: Bug Fix  
**Estimated**: 1-2h

## Phase 1: Fix Screenshot Blur (Bug 2) [Completed]
> Commit: 033dd11

### Task 1.1: 修复 ScreenCaptureService
- [x] 修改 `captureScreen()` 方法
- [x] 计算正确的点尺寸: `pixelSize / backingScaleFactor`
- [x] 验证 NSImage 保留正确的分辨率信息

**修复方案**:
```swift
// 获取屏幕的 backingScaleFactor
let scaleFactor = screen.backingScaleFactor
let pointSize = NSSize(
    width: CGFloat(scDisplay.width) / scaleFactor,
    height: CGFloat(scDisplay.height) / scaleFactor
)
let image = NSImage(cgImage: cgImage, size: pointSize)
```

## Phase 2: Fix Screenshot Offset (Bug 1) [Completed]
> Commit: 033dd11

### Task 2.1: 修复 RegionSelectionView.getAnnotatedImage()
- [x] 使用 CGImage 实际像素尺寸计算 scale
- [x] 验证 Y 坐标翻转计算正确

**修复方案**:
```swift
// 从 CGImage 获取实际像素尺寸
let imagePixelWidth = CGFloat(cgImage.width)
let imagePixelHeight = CGFloat(cgImage.height)

// 计算实际 scale (像素/点)
let scaleX = imagePixelWidth / bounds.width
let scaleY = imagePixelHeight / bounds.height
let scale = scaleX // 假设 X/Y scale 一致

// 像素级裁剪区域
let pixelRect = CGRect(
    x: selectionRect.origin.x * scale,
    y: (bounds.height - selectionRect.maxY) * scale,
    width: selectionRect.width * scale,
    height: selectionRect.height * scale
)
```

## Phase 3: Verification

- [ ] Task 3.1: 测试上方屏幕截图（应保持清晰）
- [ ] Task 3.2: 测试下方屏幕截图（应不再模糊）
- [ ] Task 3.3: 测试截图位置（应与选区一致）
- [ ] Task 3.4: 测试大图 AI 增强

## Files to Modify

| File | Changes |
|------|---------|
| `ScreenCaptureService.swift` | 修复 NSImage 尺寸计算 |
| `RegionSelectionView.swift` | 修复裁剪坐标计算 |

## Rollback Plan

```bash
git checkout -- spoke/Core/Attachment/ScreenCaptureService.swift
git checkout -- spoke/UI/Screenshot/RegionSelectionView.swift
```
