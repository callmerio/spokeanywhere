# Research Summary: 截图放大锐化/超分辨率

## 📁 Code Context (3 items)

1. `UI/HUD/FloatingCapsuleView.swift:360` - CIFilter 已在项目中使用 (CIGaussianBlur)
2. `Services/ScreenOCRService.swift:2` - Vision 框架已集成
3. `docs/roadmap.md:97` - CoreML 仅在规划中 (Whisper)

## 📜 Memory Context
- None found

## 🌐 External Research (15 items)

### 方案 A: CIFilter 原生锐化 (轻量级)
1. **CISharpenLuminance** - Apple 内置滤镜，调整亮度锐化
   - 参数: `inputImage`, `radius`, `sharpness`
   - 优点: 无需额外依赖，即时生效
   - URL: developer.apple.com

2. **CIUnsharpMask** - 经典 Unsharp Mask 算法
   - 增强边缘对比度
   - 参数: `radius`, `intensity`
   - URL: developer.apple.com

### 方案 B: CoreML 超分辨率 (AI 驱动)
3. **FreeScaler-CoreML** - 开源 macOS 超分辨率应用
   - GitHub: TheMurusTeam/FreeScaler-CoreML
   - 基于 CoreML/Swift，Neural Engine 加速 (5-10x)
   - 支持自定义模型导入
   - URL: github.com/TheMurusTeam/FreeScaler-CoreML

4. **john-rocky/CoreML-Models** - 预转换 CoreML 模型集合
   - 包含: Real-ESRGAN, GFPGAN, BSRGAN, A-ESRGAN
   - 直接可用于 Swift 项目
   - URL: github.com/john-rocky/CoreML-Models

5. **Real-ESRGAN** - 最流行的 AI 超分辨率模型
   - 4x 放大效果优秀
   - 有 Anime 专用版本
   - 可通过 coremltools 转换

6. **Pixelmator Pro** - 商业应用参考实现
   - 使用 CoreML 实现 "Super Resolution" 功能
   - 证明技术成熟可行

### 方案 C: 传统插值 (最轻量)
7. **Lanczos Resampling** - 高质量传统算法
   - 比 bilinear/bicubic 更锐利
   - 可能有轻微 ringing 伪影
   - Core Image 支持

8. **Bicubic Sharper** - 简单有效
   - Photoshop 标准方法
   - 适合缩小时锐化

### 技术对比
9. **Neural Network vs Traditional**
   - AI: 可"想象"细节，效果最佳，需模型 (~50MB)
   - Lanczos: 快速，无依赖，效果中等
   - Bicubic: 最快，效果一般

10. **Apple Silicon Neural Engine**
    - CoreML 模型可利用 Neural Engine
    - 比 GPU 快 5-10x，功耗降低 75%

### 实现资源
11. **HuggingFace TheMurusTeam** - 免费 CoreML 模型下载
12. **WWDC 2024 CoreML Updates** - 压缩/量化/性能提升
13. **Vision + CoreML Integration** - 官方推荐方式
14. **myUpscaler** - SwiftUI + CoreML 参考实现
15. **Upscale-Enhance** - Real-ESRGAN 命令行工具

## 💡 Key Takeaways

### 推荐方案分级

| 优先级 | 方案 | 效果 | 复杂度 | 包体积 |
|--------|------|------|--------|--------|
| 🥇 P0 | CISharpenLuminance | ⭐⭐⭐ | 低 | 0 KB |
| 🥈 P1 | CoreML Real-ESRGAN | ⭐⭐⭐⭐⭐ | 中 | ~50 MB |
| 🥉 P2 | Lanczos + Sharpen | ⭐⭐⭐⭐ | 低 | 0 KB |

### 实施建议

1. **Phase 1 (立即可用)**: 使用 `CISharpenLuminance` 对放大后的图片进行锐化
   - 零成本，零依赖
   - 代码: ~10 行

2. **Phase 2 (可选增强)**: 集成 Real-ESRGAN CoreML 模型
   - 从 john-rocky/CoreML-Models 下载
   - 参考 FreeScaler-CoreML 实现
   - 增加 ~50MB 包体积

### Swift 代码示例 (CISharpenLuminance)

```swift
func sharpenImage(_ image: NSImage, sharpness: CGFloat = 0.4) -> NSImage? {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
    let ciImage = CIImage(cgImage: cgImage)
    
    guard let filter = CIFilter(name: "CISharpenLuminance") else { return nil }
    filter.setValue(ciImage, forKey: kCIInputImageKey)
    filter.setValue(sharpness, forKey: kCIInputSharpnessKey)
    
    guard let outputImage = filter.outputImage else { return nil }
    
    let context = CIContext()
    guard let resultCGImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
    
    return NSImage(cgImage: resultCGImage, size: image.size)
}
```
