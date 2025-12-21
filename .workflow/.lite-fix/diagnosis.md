# Bug Diagnosis: AI 增强图像偏移

## 症状
- AI 增强后的图片在 `imageView` 中显示时存在明显偏移
- 多次修复（CGContext替代CIFilter、scaleAxesIndependently、精确backingScale）均无效

## Red Team 分析结论

### 🚨 根因: 原图 NSImage.size 与实际像素不匹配

**问题链路**:
```
cropImage() 使用 lockFocus() → 创建 2x 像素位图
    ↓
saveImage() 通过 tiffRepresentation → NSBitmapImageRep → PNG
    ↓ ⚠️ DPI 信息可能丢失或不正确
loadImage() 通过 NSImage(contentsOf:)
    ↓ ⚠️ size 属性可能返回像素尺寸而非点尺寸
```

**验证数据 (2025-12-22 04:16)**:
```
inputPointSize  = 711.5 × 97.4   (original.size)
resultCGImage   = 5696 × 780     (AI 4x 输出像素)
```

验证: 711.5 × 8 = 5692 (接近 5696)
这说明 `original.size` 是**点尺寸**，AI 正确 4x 放大。

**但**: 如果原图的 `CGImage` 像素是 1423 × 195 (711.5×2, 97.4×2)，
那 AI 4x 放大应该是 5692 × 780。实际是 5696 × 780。

**关键问题**: 原图的像素/点比例是否正好是 2.0？

### 下一步
1. 在 enhance() 中添加日志，打印原图的 CGImage 像素尺寸
2. 确认 original.size × 2 = cgImage.width/height
