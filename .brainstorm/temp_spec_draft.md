# Spec: Tiling Upscaling for AI Enhancement

## Overview

修复 `ImageEnhancementService` 的 AI 增强模式，实现正确的 Tiling Upscaling 算法，支持任意尺寸图像的 4x 超分辨率放大。

### 问题背景

当前 AI 模式效果差的根因：
1. **BGR 颜色空间未处理**: RealESRGAN 模型期望 BGR 输入，但当前实现传入 RGB
2. **Tiling 接缝问题**: 直接拼接 tiles 导致明显边界 artifacts
3. **Padding 策略不当**: 缺少 tile_pad 机制，边缘上下文丢失

## Requirements

### R1: BGR 颜色空间正确处理
- 输入图像 RGB → BGR 转换
- 输出结果 BGR → RGB 转换
- 使用 `kCVPixelFormatType_32BGRA` 格式的 CVPixelBuffer

### R2: Tile Padding 算法 (核心)
- 裁剪每个 tile 时，向外扩展 `tilePad` 像素 (推荐 10-32px)
- 处理后只保留有效区域，丢弃 padding 部分
- 确保相邻 tiles 的边缘上下文一致

### R3: 边缘处理
- 图像边缘无法扩展 padding 时，使用 reflect/replicate 填充
- 或者：边缘 tiles 特殊处理，padding 区域填 0

### R4: 小图直接处理
- 图像尺寸 ≤ 512x512 时，直接 pad 到 512x512 处理
- 处理后裁剪回原始尺寸 * 4

### R5: 性能优化 (可选)
- 复用 MLModel 实例 (已实现)
- 考虑并行处理多个 tiles (如果 Neural Engine 支持)

## Acceptance Criteria

### AC1: 视觉质量
- [ ] AI 增强后图像无明显色偏
- [ ] Tile 边界无可见接缝
- [ ] 细节清晰度优于 Basic (Lanczos) 模式

### AC2: 功能正确性
- [ ] 任意尺寸图像都能正确处理
- [ ] 小于 512x512 的图像正确处理
- [ ] 大于 512x512 的图像 tiling 正确

### AC3: 兼容性
- [ ] 保持 Basic 模式不变
- [ ] AI 失败时 fallback 到 Basic 模式
- [ ] 模型未下载时正常 fallback

## Out of Scope

- 不修改模型下载/编译逻辑
- 不添加新的 UI 控件
- 不支持其他超分模型 (仅 RealESRGAN 512)
- 不实现 alpha 通道处理 (截图通常是 RGB)

## Technical Design

### 算法伪代码

```
function enhanceAI(image, targetSize):
    cgImage = image.cgImage
    
    if cgImage.size <= 512x512:
        return processSingleTile(cgImage, targetSize)
    
    // Tiling 参数
    tileSize = 512
    tilePad = 32  // padding 像素数
    scale = 4
    
    outputCanvas = createCanvas(cgImage.size * scale)
    
    for each tile in tiles(cgImage, stride=tileSize):
        // 1. 裁剪 tile + padding
        paddedRect = tile.rect.expanded(by: tilePad)
        paddedRect = paddedRect.clamped(to: cgImage.bounds)
        paddedTile = cgImage.crop(paddedRect)
        
        // 2. Pad 到 512x512 (如果需要)
        if paddedTile.size < 512x512:
            paddedTile = padTo512(paddedTile)
        
        // 3. RGB → BGR 转换 + CoreML 处理
        bgrBuffer = createBGRPixelBuffer(paddedTile)
        output = model.prediction(bgrBuffer)
        
        // 4. 计算有效区域 (去掉 padding)
        validRect = calculateValidRect(tile, paddedRect, scale)
        
        // 5. 绘制到输出画布
        outputCanvas.draw(output, validRect)
    
    return scaleToTarget(outputCanvas, targetSize)
```

### 关键参数

| 参数 | 值 | 说明 |
|------|-----|------|
| tileSize | 512 | 模型固定输入尺寸 |
| tilePad | 32 | 边缘 padding，避免接缝 |
| scale | 4 | 模型放大倍数 |
| stride | 512 | tile 步进 = tileSize (无 overlap) |

### 坐标系注意

- CGImage: 左上角原点
- CGContext: 左下角原点 (需要 Y 翻转)
- CoreML: 取决于模型定义
