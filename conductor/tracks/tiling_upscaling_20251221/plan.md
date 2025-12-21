# Plan: Tiling Upscaling Implementation

**Track ID**: tiling_upscaling_20251221  
**Type**: Bug Fix  
**Estimated**: 2-3h

## Phase 1: Setup
- [ ] Task 1.1: 备份当前 ImageEnhancementService.swift

## Phase 2: Implementation (TDD)

### Task 2.1: BGR 颜色转换
- [ ] Test: 验证 BGRA PixelBuffer 创建正确
- [ ] Code: 修复 `createBGRPixelBuffer` 方法
- [ ] Refactor: 确保 bitmapInfo 正确

### Task 2.2: Tile Padding 算法
- [ ] Test: 验证 padding 扩展正确
- [ ] Code: 实现 `extractTileWithPadding` 方法
- [ ] Code: 实现 `calculateValidOutputRect` 方法

### Task 2.3: 边缘 Reflect Padding
- [ ] Code: 实现 `reflectPadImage` 辅助方法
- [ ] Code: 集成到 tiling 流程

### Task 2.4: 整合 Tiling 流程
- [ ] Code: 重写 `enhanceAI` 方法
- [ ] Code: 重写 `processOneTile` 方法
- [ ] Refactor: 清理冗余代码

## Phase 3: Verification
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
