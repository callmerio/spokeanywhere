# Research Summary: Tiling Upscaling for RealESRGAN CoreML

## 📁 Code Context (5 items)

1. `@/spoke/Services/ImageEnhancementService.swift:85-192` - 当前 AI 增强实现，已有 tiling 框架但存在问题
2. `@/spoke/Core/Screenshot/ImageUpscalerModelManager.swift:1-223` - 模型下载/编译管理
3. 模型规格 (通过 coremltools 分析):
   - **Input**: `input` - BGR ColorSpace (20), 512x512 固定尺寸
   - **Output**: `activation_out` - BGR ColorSpace (20), 2048x2048
   - **Scale Factor**: 4x

## 📜 Memory Context

- **No INDEX.md found** - 项目未配置记忆索引
- `memory.csv` 存在但无直接相关条目

## 🌐 External Research (12 items)

1. **[Real-ESRGAN GitHub](https://github.com/xinntao/Real-ESRGAN)** - 官方实现，提供 tile_size/tile_pad 参数
2. **[Real-ESRGAN utils.py tile_process](https://github.com/xinntao/Real-ESRGAN/blob/master/realesrgan/utils.py)** - 核心 tiling 算法:
   - 每个 tile 裁剪时包含 `tile_pad` 像素的 padding
   - 处理后只取中间有效区域，丢弃 padding 部分
   - 这样相邻 tile 的边缘上下文一致，避免接缝
3. **[Issue #197 Tile-Size Averaging](https://github.com/xinntao/Real-ESRGAN/issues/197)** - 不同 tile 大小可能产生接缝
4. **[Issue #103 About --tile](https://github.com/xinntao/Real-ESRGAN/issues/103)** - tile 模式质量与非 tile 基本一致
5. **[Local Padding in Patch-Based GANs](https://arxiv.org/html/2309.02340v4)** - 学术论文解释 local padding 避免 tiling artifacts
6. **[CoreML Image to MLMultiArray](https://machinethink.net/blog/coreml-image-mlmultiarray/)** - CoreML 图像处理最佳实践
7. **[FreeScaler-CoreML](https://github.com/TheMurusTeam/FreeScaler-CoreML)** - macOS 开源 CoreML upscaler 参考实现
8. **[Image Upscale Tiled (ComfyUI)](https://www.runcomfy.com/comfyui-nodes/ComfyUI-YCNodes/image-upscale-tiled)** - 分块处理后无缝合并
9. **[Seamless Image Stitching in Gradient Domain](https://webee.technion.ac.il/people/anat.levin/papers/eccv04-blending.pdf)** - 梯度域图像拼接理论
10. **[CoreMLHelpers GitHub](https://github.com/hollance/CoreMLHelpers)** - CVPixelBuffer 转换工具库
11. **[SD Upscale Tile Overlap](https://www.reddit.com/r/StableDiffusion/comments/1doemd7/sd_upscale_sampling_steps_denoising_tile_overlap/)** - overlap 帮助去除接缝
12. **[GPU-Friendly Laplacian Texture Blending](https://arxiv.org/html/2502.13945v1)** - 不同 blending radii 对拼接效果的影响

## 💡 Key Takeaways

### 问题根因
1. **BGR 颜色空间**: 模型期望 BGR，当前可能传入 RGB → 颜色错乱
2. **固定输入尺寸**: 模型只接受 512x512，大图必须 tiling
3. **接缝问题**: 直接拼接会有明显边界 artifacts

### Real-ESRGAN 官方 Tiling 算法核心

```python
# 关键参数
tile_size = 512   # 模型输入尺寸
tile_pad = 10     # 边缘 padding (官方默认 10)
scale = 4         # 放大倍数

# 裁剪时包含 padding
input_start_x_pad = max(input_start_x - tile_pad, 0)
input_end_x_pad = min(input_end_x + tile_pad, width)

# 处理后只取有效区域
output_start_x_tile = (input_start_x - input_start_x_pad) * scale
output_end_x_tile = output_start_x_tile + input_tile_width * scale
```

### 推荐实现策略

1. **Padding Strategy**: 裁剪时多取 padding，输出时只保留有效区域
2. **Overlap 区域**: 48px overlap (当前实现) 可能过大，官方用 10px
3. **BGR 转换**: 使用 BGRA pixel format 的 CVPixelBuffer
4. **边缘处理**: 图像边缘用 reflect padding 或 replicate padding

### 参考实现 (Python → Swift 转换)

| Python (Real-ESRGAN) | Swift (CoreML) |
|---------------------|----------------|
| `tile_pad = 10` | `tilePad = 10` |
| `cv2.cvtColor(BGR2RGB)` | `kCVPixelFormatType_32BGRA` |
| `F.pad(..., 'reflect')` | `CGContext` 或 `vImage` 镜像填充 |
| `torch.no_grad()` | `MLModel.prediction()` |
