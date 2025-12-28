# Research Summary: Tiling Upscaling 性能 + UX 优化

## 用户反馈的三个问题

| # | 问题描述 | 优先级 |
|---|----------|--------|
| 1 | 放大后要等 18 秒才能完成，之前测试只需 5-7 秒 | P0 |
| 2 | 希望在 AI 完成前，先用 Basic 增强显示中间态 | P1 |
| 3 | AI 结果应缓存，再次放大直接显示 | P0 |

---

## 📁 Code Context (5 items)

1. `spoke/Services/ImageEnhancementService.swift:102-205` - `enhanceAI()` 主方法，串行处理 tiles
2. `spoke/Services/ImageEnhancementService.swift:244-267` - `processOneTile()` 单个 tile 的 CoreML 推理
3. `spoke/UI/Screenshot/ScreenshotContentView.swift:127-193` - `updateImageQuality()` 防抖触发增强
4. `spoke/UI/Screenshot/ScreenshotContentView.swift:43-52` - `enhanceDebounceTask` + `currentEnhanceTask` 任务管理
5. `spoke/UI/Screenshot/ScreenshotContentView.swift:49` - `lastEnhancedSize` 缓存标记（但未缓存图片本身）

---

## 📜 Memory Context (4 items)

1. **#22** `2025-12-22`: AI增强图像偏移问题修复 - DPI 丢失导致尺寸不精确
2. **#104** `2025-12-21`: AI增强响应优化 - debounce 1s→0.3s
3. **#122** `2025-12-22`: scaleNSImage 点尺寸/像素尺寸混淆修复
4. **#238** `2025-12-21`: ImageEnhancementService 创建 - Lanczos+Sharpen 基础增强

---

## 🌐 External Research (12 items)

### Real-ESRGAN/Tiling 优化
1. [StackOverflow](https://stackoverflow.com/...) - Tiling 是处理大图的必要手段，tile size 需要权衡内存和性能
2. [Real-ESRGAN-LP](https://github.com/...) - Local Padding 策略可减少接缝 artifacts
3. [GitHub ncnn](https://github.com/...) - 多 GPU/多线程可显著提升性能 (`-j` 参数控制线程)

### CoreML 性能优化
4. [Medium](https://medium.com/...) - CoreML `computeUnits = .all` 可自动利用 Neural Engine/GPU/CPU
5. [Apple WWDC](https://developer.apple.com/...) - MLModelConfiguration 可指定计算单元优化性能
6. [Medium](https://medium.com/...) - Batch Predictions 比逐个预测更高效

### Swift 并行处理
7. [Swift Forum](https://swift.org/...) - TaskGroup 并行处理可达 6x 加速
8. [SwiftWithMajid](https://swiftwithmajid.com/...) - TaskGroup 内存管理：动态添加任务而非一次性全部添加
9. [BetterProgramming](https://betterprogramming.pub/...) - 图像 tile 并行处理的最佳实践

### Progressive Loading UX
10. [WatchSumo](https://watchsumo.com/...) - 先显示低质量版本再逐步替换高质量版本
11. [Medium](https://medium.com/...) - "Blur-up" 技术：先显示模糊缩略图再替换
12. [SpeedCurve](https://speedcurve.com/...) - Progressive JPEG 策略提升 perceived performance

### 图片缓存
13. [Apple Docs](https://developer.apple.com/...) - NSCache 自动内存管理，低内存时自动清理
14. [StackAdemic](https://stackademic.com/...) - LRU 缓存策略用于图片

---

## 💡 Key Takeaways

### 性能问题根因分析

| 嫌疑 | 证据 | 可能性 |
|------|------|--------|
| **串行 Tile 处理** | 当前 for 循环串行处理，6 tiles × 2s/tile = 12s | ⭐⭐⭐⭐ |
| **重复模型加载** | 日志显示 "CoreML model loaded" 出现两次 | ⭐⭐⭐ |
| **图片尺寸更大** | 1405x889 = 3×2=6 tiles，之前可能是更小图片 | ⭐⭐ |

### 解决方案设计

#### 问题 1: 性能优化

| 方案 | 说明 | 预期收益 |
|------|------|----------|
| **TaskGroup 并行** | 6 tiles 并行处理 | 6x → ~2s |
| **模型单例缓存** | 确保 `loadedMLModel` 只加载一次 | 避免重复加载 |
| **CGContext 复用** | 预分配画布避免重复创建 | 减少内存分配 |

#### 问题 2: 中间态 (Basic 先行)

```swift
// 两阶段增强流程
1. 立即: enhanceBasic() → 显示
2. 后台: enhanceAI() → 完成后替换
```

#### 问题 3: 缓存 AI 结果

```swift
// ScreenshotContentView 新增
private var cachedEnhancedImage: NSImage?
private var cachedEnhancedSize: CGSize = .zero

// 放大时检查缓存
if cachedEnhancedSize == targetSize {
    imageView.image = cachedEnhancedImage
    return
}
```

---

## 实现计划扩展建议

### 新增 Tasks

| Task | 描述 | 估时 |
|------|------|------|
| 3.6 | 实现 TaskGroup 并行 Tile 处理 | 1h |
| 3.7 | 添加 Basic 先行中间态 | 0.5h |
| 3.8 | 添加 AI 结果缓存 | 0.5h |
| 3.9 | 添加处理进度指示 (可选) | 0.5h |
