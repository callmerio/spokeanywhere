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

## Phase 4: 性能 + UX 优化 (2025-12-29 新增)
> 目标: 解决用户反馈的三个问题
> - 太慢 (18s → <5s)
> - 无中间态
> - 无缓存

### Task 4.1: 修复重复任务问题
- [x] 调查日志中模型加载两次的原因
- [x] 确保同一图片只启动一个增强任务

### Task 4.2: TaskGroup 并行 Tile 处理
- [x] Code: `enhanceAI()` 改为 async 方法
- [x] Code: 使用 `withTaskGroup` 并行处理 tiles
- [x] Code: 收集结果后绘制到画布
- [x] Test: 对比串行 vs 并行耗时

### Task 4.3: Basic 先行中间态
- [x] Code: `updateImageQuality()` 立即调用 `enhanceBasic()`
- [x] Code: 后台 Task 执行 AI 增强
- [x] Code: AI 完成后替换 Basic 结果

### Task 4.4: AI 结果缓存
- [x] Code: 添加 `cachedEnhancedImage: NSImage?`
- [x] Code: 添加 `cachedEnhancedScale: CGFloat`
- [x] Code: 放大时先检查缓存命中
- [x] Code: AI 完成时更新缓存

### Task 4.5: 性能验证
- [x] Test: 1405x889 图片增强时间 < 5s
- [x] Test: 缓存命中时无延迟 (4x HighRes 缓存)
- [x] Test: 中间态立即显示 (Basic Lanczos+Sharpen)

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

### 并行处理伪代码 (Phase 4)

```swift
func enhanceAI() async -> NSImage? {
    // 收集所有 tile 任务
    let tiles = await withTaskGroup(of: (x: Int, y: Int, image: CGImage?).self) { group in
        for tileY in 0..<tilesY {
            for tileX in 0..<tilesX {
                group.addTask {
                    let tile = cropTile(x: tileX, y: tileY)
                    let padded = padTileToModelSize(tile)
                    let upscaled = processOneTile(padded, model: model)
                    return (tileX, tileY, upscaled)
                }
            }
        }
        return await group.reduce(into: []) { $0.append($1) }
    }
    
    // 绘制到画布
    for (x, y, image) in tiles {
        canvasContext.draw(image, in: calculateRect(x, y))
    }
}
```

## Files to Modify

| File | Changes |
|------|---------|
| `ImageEnhancementService.swift` | 重写 AI 增强逻辑 + 并行处理 |
| `ScreenshotContentView.swift` | 中间态 + 缓存逻辑 |

## Rollback Plan

```bash
git checkout -- spoke/Services/ImageEnhancementService.swift
git checkout -- spoke/UI/Screenshot/ScreenshotContentView.swift
```

