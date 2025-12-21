# Spec: Tiling Upscaling for AI Enhancement

**Track ID**: tiling_upscaling_20251221  
**Type**: Bug Fix / Feature Enhancement  
**Priority**: P1

## Overview

修复 `ImageEnhancementService` 的 AI 增强模式，实现正确的 Tiling Upscaling 算法。

### 问题根因

| 问题 | 当前实现 | 正确做法 |
|------|----------|----------|
| 颜色空间 | RGB (CGImage 默认) | BGR (模型期望) |
| Tile 接缝 | 直接拼接 | Padding + 只取有效区域 |
| 边缘处理 | 简单填充 | Reflect/Replicate padding |

## Requirements

### R1: BGR 颜色空间正确处理
- RGB → BGR 转换 (输入)
- BGR → RGB 转换 (输出)
- 使用 `kCVPixelFormatType_32BGRA` + 正确的 bitmapInfo

### R2: Tile Padding 算法
- 裁剪 tile 时向外扩展 `tilePad` 像素
- 处理后只保留有效区域
- `tilePad` 推荐值: 32px

### R3: 边缘处理
- 边缘 tiles 使用 reflect padding 填充

### R4: 小图直接处理
- ≤512x512 直接 pad 到 512x512
- 处理后裁剪回正确尺寸

## Acceptance Criteria

- [ ] AI 增强后无色偏
- [ ] Tile 边界无可见接缝
- [ ] 任意尺寸图像正确处理
- [ ] Basic 模式保持不变
- [ ] 模型未下载时正常 fallback

## Out of Scope

- 模型下载/编译逻辑
- 新 UI 控件
- Alpha 通道处理
