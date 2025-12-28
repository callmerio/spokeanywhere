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

### R5: 性能优化 - 并行 Tile 处理 (2025-12-29 新增)
- 使用 Swift `TaskGroup` 并行处理多个 tiles
- 理论加速比: N tiles 并行 → ~1/N 时间
- 目标: 1405x889 图片 (6 tiles) 从 12s → ~3s

### R6: UX 优化 - Basic 先行中间态 (2025-12-29 新增)
- 用户放大后立即显示 Basic 增强结果
- 后台异步执行 AI 增强
- AI 完成后无缝替换 Basic 结果

### R7: 性能优化 - AI 结果缓存 (2025-12-29 新增)
- 缓存 AI 增强后的图片
- 以 scale 为 key（相同放大比例直接使用缓存）
- 再次放大到相同尺寸时直接显示，无需重新计算

## Acceptance Criteria

- [x] AI 增强后无色偏
- [x] Tile 边界无可见接缝
- [x] 任意尺寸图像正确处理
- [x] Basic 模式保持不变
- [x] 模型未下载时正常 fallback
- [ ] **[新增]** 6 tiles 图片增强时间 < 5s
- [ ] **[新增]** 放大后立即看到增强效果（Basic 中间态）
- [ ] **[新增]** 相同放大比例再次查看时无延迟（缓存命中）

## Out of Scope

- 模型下载/编译逻辑
- ~~新 UI 控件~~ (进度指示器可选)
- Alpha 通道处理
