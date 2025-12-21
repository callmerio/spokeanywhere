# Plan: Tiling Upscaling Implementation

**Track ID**: tiling_upscaling_20251221  
**Type**: Bug Fix  
**Estimated**: 2-3h

## Phase 1: Setup
- [x] Task 1.1: 备份当前 ImageEnhancementService.swift

## Phase 2: Implementation [Completed]
> Commit: 90d555a

### Task 2.1: BGR 颜色转换
- [x] Code: 保持 `createBGRPixelBuffer` 方法 (BGRA format)
- [x] Refactor: 确保 bitmapInfo 正确

### Task 2.2: Tile Padding 算法
- [x] Code: 实现 tilePad 策略 (裁剪时多取 padding)
- [x] Code: 实现 validRect 计算 (只取有效区域)

### Task 2.3: 边缘处理
- [x] Code: 使用黑色填充边缘 (有效区域会被裁剪)
- [x] Code: 集成到 tiling 流程

### Task 2.4: 整合 Tiling 流程
- [x] Code: 重写 `enhanceAI` 方法 (tilePad 策略)
- [x] Code: 重写 `padTileToModelSize` 方法
- [x] Refactor: 移除旧的 overlap 参数

## Phase 3: Verification [Pending User Test]
- [ ] Task 3.1: 测试小图 (< 512x512)
- [ ] Task 3.2: 测试中图 (512x512 ~ 1024x1024)
- [ ] Task 3.3: 测试大图 (> 2000x2000)
- [ ] Task 3.4: 视觉质量对比 (AI vs Basic)
- [ ] Task 3.5: 接缝检查

## Key Algorithm

```
tilePad = 32
stride = tileSize = 512

for each tile:
    1. paddedRect = tile.expanded(by: tilePad).clamped(to: image)
    2. paddedTile = crop(image, paddedRect)
    3. if paddedTile < 512: pad to 512 with reflect
    4. output = model(paddedTile)
    5. validRect = remove padding from output
    6. draw validRect to canvas
```

## Files to Modify

| File | Changes |
|------|---------|
| `ImageEnhancementService.swift` | 重写 AI 增强逻辑 |

## Rollback Plan

```bash
git checkout -- spoke/Services/ImageEnhancementService.swift
```
