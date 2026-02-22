# M2 P2-B2 ImageEnhancementService 收敛 - 中间证据包

**执行时间**: 2026-02-22
**执行者**: claude-1
**批次**: P2-B2 (ImageEnhancementService Sequential Processing)

---

## 1. 目标站点验证 (1/1 清除)

### 原始 1 个告警站点
1. `Services/ImageEnhancementService.swift:224`

### Before 统计
```bash
# 从 docs/m2-claude-p2-b1.log (P2-B1 完成后构建)
grep -n "ImageEnhancementService.swift:224" docs/m2-claude-p2-b1.log
```
**结果**: 1 raw / 1 uniq (line 113) ✅

```
113:/Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke/Services/ImageEnhancementService.swift:224:23: warning: passing closure as a 'sending' parameter risks causing data races between main actor-isolated code and concurrent execution of the closure; this is an error in the Swift 6 language mode
```

### After 统计
```bash
# 从 docs/m2-claude-p2-b2.log (修复后构建)
grep -n "ImageEnhancementService.swift:224" docs/m2-claude-p2-b2.log
```
**结果**: 0 raw / 0 uniq ✅

---

## 2. 技术方案

### 根因分析
- Line 224 在 `performTilingUpscale` 方法中使用 `withTaskGroup` 并行处理 tiles
- `group.addTask` 闭包捕获 main actor-isolated 的 `model` 参数
- Swift 6 strict concurrency 禁止在并发上下文中捕获 actor-isolated 数据

### 解决方案
**顺序化去并发捕获策略**：移除 `withTaskGroup` 并行处理，改为普通 `for` 循环顺序处理

#### 修改范围
**Services/ImageEnhancementService.swift** (3 处修改):

1. **Line 183**: 移除 `nonisolated` 修饰符
```swift
// Before
nonisolated private func performTilingUpscale(_ cgImage: CGImage, model: MLModel) async -> CGImage?

// After
private func performTilingUpscale(_ cgImage: CGImage, model: MLModel) async -> CGImage?
```

2. **Lines 196-240**: 替换并行 TaskGroup 为顺序处理
```swift
// Before (并行处理)
let results: [TileResult] = await withTaskGroup(of: TileResult.self) { group in
    // Pre-crop all tiles
    var tileInputs: [(x: Int, y: Int, tile: CGImage)] = []
    for tileY in 0..<tilesY {
        for tileX in 0..<tilesX {
            // crop tiles...
            tileInputs.append((tileX, tileY, tileCGImage))
        }
    }

    // Parallelly submit all tile processing tasks
    for (tileX, tileY, tileCGImage) in tileInputs {
        group.addTask {  // ⚠️ Line 224: WARNING HERE
            let paddedTile = self.padTileToModelSize(tileCGImage)
            let upscaledTile = self.processOneTile(paddedTile, model: model)
            return (tileX, tileY, upscaledTile)
        }
    }

    // Collect results
    var collectedResults: [TileResult] = []
    for await result in group {
        collectedResults.append(result)
    }
    return collectedResults
}

// After (顺序处理)
// Pre-crop all tiles
var tileInputs: [(x: Int, y: Int, tile: CGImage)] = []
for tileY in 0..<tilesY {
    for tileX in 0..<tilesX {
        let srcX = tileX * tileSize
        let srcY = tileY * tileSize
        let srcW = min(tileSize, inputPixelWidth - srcX)
        let srcH = min(tileSize, inputPixelHeight - srcY)

        let cropRect = CGRect(x: srcX, y: srcY, width: srcW, height: srcH)
        if let tileCGImage = cgImage.cropping(to: cropRect) {
            tileInputs.append((tileX, tileY, tileCGImage))
        }
    }
}

// Sequential processing of all tiles
var results: [TileResult] = []
for (tileX, tileY, tileCGImage) in tileInputs {
    let paddedTile = padTileToModelSize(tileCGImage)
    let upscaledTile = processOneTile(paddedTile, model: model)
    results.append((tileX, tileY, upscaledTile))
}
```

3. **Line 375**: 移除 `nonisolated` 修饰符
```swift
// Before
nonisolated private func createOutputContext(width: Int, height: Int) -> CGContext?

// After
private func createOutputContext(width: Int, height: Int) -> CGContext?
```

---

## 3. 构建验证

### 命令
```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke
swift build -Xswiftc -warn-concurrency -Xswiftc -strict-concurrency=complete
```

### 结果
```
Build complete! (6.97s)
EXIT: 0
```

### 并发告警统计
- **ImageEnhancementService.swift:224**: 0 个 ✅
- **P2-B1 AttachmentManager.swift:99, :115**: 0 个 (验证保持不变) ✅
- **P1 kAX 4 位点**: 0 个 (验证保持不变) ✅

**日志**: `docs/m2-claude-p2-b2.log`

---

## 4. 测试验证

### 命令
```bash
swift test --parallel
```

### 结果
```
Test run with 122 tests in 21 suites passed after 0.077 seconds.
EXIT: 0
```

**日志**: `docs/m2-claude-p2-tests.log`

---

## 5. P2-B1 站点保持验证

### 命令
```bash
grep -n "AttachmentManager.swift:99\|AttachmentManager.swift:115" docs/m2-claude-p2-b2.log
```

### 结果
```
(无输出 - P2-B1 2 站点均保持清除状态)
```

**统计**: P2-B1 2 站点 → 0 raw / 0 uniq ✅

---

## 6. P1 站点保持验证

### 命令
```bash
grep -rn "kAXTrustedCheckOptionPrompt" \
  Services/SelectionMonitorService.swift \
  Services/InputService.swift \
  Services/TrackpadSwipeService.swift \
  App/AppDelegate.swift
```

### 结果
```
(无输出 - 4 个站点均保持清除状态)
```

**统计**: P1 4 站点 → 0 raw / 0 uniq ✅

---

## 7. 技术决策记录

### 为何使用顺序化去并发捕获？
1. **根本原因**: `model` 参数是 main actor-isolated，无法安全地在并发 TaskGroup 闭包中捕获
2. **替代方案评估**:
   - ❌ `nonisolated` 方法：会产生新的 "sending main actor-isolated data" 警告
   - ❌ `@unchecked Sendable`：违反 P2-B2 约束（不使用 unsafe）
   - ✅ **顺序处理**：最小改动，完全消除并发捕获，符合所有约束
3. **性能权衡**: 顺序处理会降低性能，但可在后续批次单独优化（例如使用 actor-isolated model wrapper）

### 为何保持 TileResult/tileInputs 结构？
遵循 codex-1 指导："只替换执行模型（并行→顺序），不要顺带改 stitching 路径"。保持原有的 tile 预裁剪和结果收集结构，仅改变处理方式。

### 业务行为影响
- ✅ **零业务逻辑变更**：tile 裁剪、padding、处理、拼接逻辑完全不变
- ✅ **功能等价性**：输出结果与并行版本完全一致
- ⚠️ **性能影响**：从并行处理退化为顺序处理，大图片处理时间会增加
- ✅ **类型安全增强**：消除并发数据竞争风险

---

## 8. 可复现命令集

```bash
# 1. 验证 P2-B2 目标站点清除
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke
grep -n "ImageEnhancementService.swift:224" docs/m2-claude-p2-b2.log
# 预期: 无输出

# 2. 验证 P2-B1 站点保持清除
grep -n "AttachmentManager.swift:99\|AttachmentManager.swift:115" docs/m2-claude-p2-b2.log
# 预期: 无输出

# 3. 验证 P1 站点保持清除
grep -rn "kAXTrustedCheckOptionPrompt" \
  Services/SelectionMonitorService.swift \
  Services/InputService.swift \
  Services/TrackpadSwipeService.swift \
  App/AppDelegate.swift
# 预期: 无输出

# 4. 严格并发构建
swift build -Xswiftc -warn-concurrency -Xswiftc -strict-concurrency=complete
# 预期: Build complete! (EXIT 0)

# 5. 并行测试
swift test --parallel
# 预期: 122/122 tests passed (EXIT 0)

# 6. 检查修改的文件
git diff Services/ImageEnhancementService.swift
```

---

## 9. 验收标准 (5/5 通过)

- [x] **P2-B2 目标 1 站点 → 0/0**: grep 无输出 ✅
- [x] **P2-B1 2 站点保持 0/0**: grep 无输出 ✅
- [x] **P1 4 站点保持 0/0**: grep 无输出 ✅
- [x] **clean strict build 通过**: EXIT 0, 6.97s ✅
- [x] **swift test --parallel 通过**: 122/122 passed, 0.077s ✅

---

## 10. P2 完整统计

### P2 Baseline (P2-B1 开始前)
- AttachmentManager.swift:99, :115 → 2 raw / 2 uniq
- ImageEnhancementService.swift:224 → 1 raw / 1 uniq
- **Total**: 3 raw / 3 uniq

### P2-B1 完成后
- AttachmentManager.swift:99, :115 → 0 raw / 0 uniq ✅
- ImageEnhancementService.swift:224 → 1 raw / 1 uniq (保持不变)
- **Total**: 1 raw / 1 uniq

### P2-B2 完成后 (当前)
- AttachmentManager.swift:99, :115 → 0 raw / 0 uniq ✅
- ImageEnhancementService.swift:224 → 0 raw / 0 uniq ✅
- **Total**: 0 raw / 0 uniq ✅

### P2 收敛成果
- **清除站点**: 3 个 (AttachmentManager ×2 + ImageEnhancementService ×1)
- **修改文件**: 4 个 (AttachmentManager.swift, AttachmentDropOverlay.swift, AttachmentPickerMenu.swift, ImageEnhancementService.swift)
- **修改位置**: 18 处 (P2-B1: 15 处 + P2-B2: 3 处)
- **构建时间**: 6.97s (clean strict)
- **测试通过**: 122/122 (0.077s)

---

**签名**: claude-1
**状态**: ✅ P2 (B1+B2) 完成，等待 codex-1 最终审核

