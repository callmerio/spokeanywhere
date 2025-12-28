import AppKit
import CoreImage
import CoreML
import os
import Vision
// MARK: - Image Enhancement Service

/// 图片增强服务
/// 使用 Lanczos + Sharpen 提升放大后图片的清晰度
final class ImageEnhancementService {
    
    static let shared = ImageEnhancementService()
    
    private let context = CIContext()
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "ImageEnhancementService")
    
    // Cache the loaded model
    private var loadedVNCoreMLModel: VNCoreMLModel?
    
    private init() {}
    
    // MARK: - Public API
    
    /// 增强图片
    /// 根据 ScreenshotSettings 决定使用 AI 或 Basic 模式
    func enhance(_ image: NSImage, to targetSize: NSSize, sharpness: CGFloat = 0.6) -> NSImage? {
        let mode = ScreenshotSettings.shared.upscalingMode
        
        switch mode {
        case .none:
            return nil
            
        case .basic:
            return enhanceBasic(image, to: targetSize, sharpness: sharpness)
            
        case .ai:
            if let result = enhanceAI(image, to: targetSize) {
                return result
            }
            // Fallback to basic if AI fails
            return enhanceBasic(image, to: targetSize, sharpness: sharpness)
        }
    }
    
    // MARK: - Basic Enhancement (Lanczos + Sharpen)
    
    private func enhanceBasic(_ image: NSImage, to targetSize: NSSize, sharpness: CGFloat) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        var ciImage = CIImage(cgImage: cgImage)
        
        // Step 1: Lanczos 缩放
        let scaleX = targetSize.width / image.size.width
        
        if let lanczos = CIFilter(name: "CILanczosScaleTransform") {
            lanczos.setValue(ciImage, forKey: kCIInputImageKey)
            lanczos.setValue(scaleX, forKey: kCIInputScaleKey)
            lanczos.setValue(1.0, forKey: kCIInputAspectRatioKey)
            
            if let output = lanczos.outputImage {
                ciImage = output
            }
        }
        
        // Step 2: 锐化亮度通道
        if let sharpen = CIFilter(name: "CISharpenLuminance") {
            sharpen.setValue(ciImage, forKey: kCIInputImageKey)
            sharpen.setValue(sharpness, forKey: kCIInputSharpnessKey)
            
            if let output = sharpen.outputImage {
                ciImage = output
            }
        }
        
        // 渲染结果
        guard let resultCGImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        // 🔧 Fix: 保持原图宽高比，不强制使用 targetSize
        // Lanczos 等比例缩放后，实际尺寸是 (原宽*scaleX, 原高*scaleX)
        // NSImage.size 必须与实际像素比例一致，否则 imageView 显示会错位
        let actualSize = NSSize(
            width: image.size.width * scaleX,
            height: image.size.height * scaleX
        )
        return NSImage(cgImage: resultCGImage, size: actualSize)
    }
    
    // MARK: - AI Enhancement (CoreML with Tiling)
    
    // 缓存加载的 MLModel
    private var loadedMLModel: MLModel?
    
    // Tiling 参数 (参考 Real-ESRGAN 官方实现)
    private let tileSize = 512        // 模型固定输入尺寸
    private let tilePad = 32          // 边缘 padding，避免接缝 (官方默认 10，我们用 32 更保守)
    private let scaleFactor = 4       // 模型 4x 放大
    
    private func enhanceAI(_ image: NSImage, to targetSize: NSSize) -> NSImage? {
        guard let modelURL = ImageUpscalerModelManager.shared.getCompiledModelURL() else {
            logger.warning("AI model not compiled or ready")
            return nil
        }
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        // Load Model (Lazy)
        if loadedMLModel == nil {
            do {
                let config = MLModelConfiguration()
                config.computeUnits = .all
                loadedMLModel = try MLModel(contentsOf: modelURL, configuration: config)
                logger.info("✅ CoreML model loaded successfully")
            } catch {
                logger.error("❌ Failed to load CoreML model: \(error.localizedDescription)")
                return nil
            }
        }
        
        guard let model = loadedMLModel else { return nil }
        
        // 🔧 Fix: 区分像素尺寸和点尺寸
        // - cgImage.width/height 是像素尺寸
        // - image.size 是点尺寸
        // - NSImage(cgImage:size:) 的 size 参数必须是点尺寸
        let inputPixelWidth = cgImage.width
        let inputPixelHeight = cgImage.height
        
        // 🔧 Fix: 原图的 NSImage.size 可能不精确（DPI 信息丢失）
        // 强制使用 像素/backingScale 作为正确的点尺寸
        let backingScale = NSScreen.main?.backingScaleFactor ?? 2.0
        let correctedInputPointSize = NSSize(
            width: CGFloat(inputPixelWidth) / backingScale,
            height: CGFloat(inputPixelHeight) / backingScale
        )
        
        logger.info("🔍 Original Image: pixels=\(inputPixelWidth)x\(inputPixelHeight), original.size=\(image.size.width)x\(image.size.height), corrected=\(correctedInputPointSize.width)x\(correctedInputPointSize.height)")
        
        let outputPixelWidth = inputPixelWidth * scaleFactor
        let outputPixelHeight = inputPixelHeight * scaleFactor
        
        // ============================================================
        // 新方案：先放大拼接，后裁剪
        // 1. 按 512 切分 tile
        // 2. 每个 tile 填充到 512×512
        // 3. AI 放大到 2048×2048
        // 4. 直接拼接 2048 块（不缩放！）
        // 5. 裁剪掉填充区域，保留原图 ×4 的有效区域
        // 6. 最后缩放到 targetSize
        // ============================================================
        
        // 计算 tile 数量
        let tilesX = Int(ceil(Double(inputPixelWidth) / Double(tileSize)))
        let tilesY = Int(ceil(Double(inputPixelHeight) / Double(tileSize)))
        
        // 拼接画布尺寸 = tile数量 × 2048
        let canvasWidth = tilesX * tileSize * scaleFactor   // tilesX * 2048
        let canvasHeight = tilesY * tileSize * scaleFactor  // tilesY * 2048
        
        logger.info("🔲 New tiling: \(inputPixelWidth)x\(inputPixelHeight) -> canvas \(canvasWidth)x\(canvasHeight), tiles=\(tilesX)x\(tilesY)")
        
        // 创建拼接画布
        guard let canvasContext = createOutputContext(width: canvasWidth, height: canvasHeight) else {
            logger.error("Failed to create canvas context")
            return nil
        }
        
        // 处理每个 tile
        for tileY in 0..<tilesY {
            for tileX in 0..<tilesX {
                // 计算 tile 在原图中的区域
                let srcX = tileX * tileSize
                let srcY = tileY * tileSize
                let srcW = min(tileSize, inputPixelWidth - srcX)
                let srcH = min(tileSize, inputPixelHeight - srcY)
                
                // 裁剪 tile（可能小于 512）
                let cropRect = CGRect(x: srcX, y: srcY, width: srcW, height: srcH)
                guard let tileCGImage = cgImage.cropping(to: cropRect) else { continue }
                
                // 填充到 512×512
                let paddedTile = padTileToModelSize(tileCGImage)
                
                // AI 放大到 2048×2048
                guard let upscaledTile = processOneTile(paddedTile, model: model) else { continue }
                
                // 直接放到画布上（坐标 = tileIndex × 2048）
                let dstX = tileX * tileSize * scaleFactor
                let dstY = tileY * tileSize * scaleFactor
                
                // CGContext Y 轴翻转
                let drawRect = CGRect(
                    x: dstX,
                    y: canvasHeight - dstY - tileSize * scaleFactor,
                    width: tileSize * scaleFactor,
                    height: tileSize * scaleFactor
                )
                canvasContext.draw(upscaledTile, in: drawRect)
            }
        }
        
        // 生成拼接后的完整画布
        guard let canvasImage = canvasContext.makeImage() else {
            logger.error("Failed to create canvas image")
            return nil
        }
        
        // 裁剪掉填充区域，保留原图 ×4 的有效区域
        let validRect = CGRect(x: 0, y: 0, width: outputPixelWidth, height: outputPixelHeight)
        guard let croppedResult = canvasImage.cropping(to: validRect) else {
            logger.error("Failed to crop valid region")
            return nil
        }
        
        logger.info("🔍 enhanceAI: canvas=\(canvasWidth)x\(canvasHeight), cropped=\(croppedResult.width)x\(croppedResult.height), target=\(targetSize.width)x\(targetSize.height)")
        
        // 最后缩放到 targetSize
        return scaleCGImage(croppedResult, to: targetSize, backingScale: backingScale)
    }
    
    /// 处理单个 tile (小于 512x512 的图片直接处理)
    private func processSingleTile(_ cgImage: CGImage, model: MLModel, targetSize: NSSize, originalPointSize: NSSize) -> NSImage? {
        let paddedTile = padTileToModelSize(cgImage)
        guard let upscaled = processOneTile(paddedTile, model: model) else { return nil }
        
        // 裁剪到实际输出像素尺寸 (从左上角开始)
        let actualPixelWidth = cgImage.width * scaleFactor
        let actualPixelHeight = cgImage.height * scaleFactor
        let cropRect = CGRect(x: 0, y: 0, width: actualPixelWidth, height: actualPixelHeight)
        
        guard let croppedImage = upscaled.cropping(to: cropRect) else { return nil }
        
        // 🔧 Fix: 使用屏幕真实 backingScaleFactor
        let backingScale = NSScreen.main?.backingScaleFactor ?? 2.0
        return scaleCGImage(croppedImage, to: targetSize, backingScale: backingScale)
    }
    
    /// 处理单个 512x512 tile
    private func processOneTile(_ tile: CGImage, model: MLModel) -> CGImage? {
        let modelInputSize = CGSize(width: tileSize, height: tileSize)
        
        // 创建 BGR PixelBuffer
        guard let bgrBuffer = createBGRPixelBuffer(from: tile, size: modelInputSize) else {
            return nil
        }
        
        do {
            let input = try MLDictionaryFeatureProvider(dictionary: ["input": MLFeatureValue(pixelBuffer: bgrBuffer)])
            let output = try model.prediction(from: input)
            
            guard let outputBuffer = output.featureValue(for: "activation_out")?.imageBufferValue else {
                return nil
            }
            
            // 转换输出
            let ciImage = CIImage(cvPixelBuffer: outputBuffer)
            return context.createCGImage(ciImage, from: ciImage.extent)
        } catch {
            logger.error("Tile processing failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 将 tile 填充到模型输入尺寸 512x512
    /// 使用 reflect padding 避免边缘 artifacts
    private func padTileToModelSize(_ tile: CGImage) -> CGImage {
        if tile.width == tileSize && tile.height == tileSize {
            return tile
        }
        
        // 创建 512x512 画布
        guard let ctx = CGContext(
            data: nil,
            width: tileSize,
            height: tileSize,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return tile
        }
        
        // 使用边缘像素复制填充 (replicate padding)
        // 先填充边缘颜色，再绘制原图覆盖
        // 简化实现：直接用黑色填充，因为有效区域会被裁剪
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: tileSize, height: tileSize))
        
        // 绘制 tile 到左上角 (CGContext Y 轴翻转，所以实际是左上)
        // CGContext 坐标系: 左下原点，但我们希望图像在左上角
        let drawRect = CGRect(x: 0, y: tileSize - tile.height, width: tile.width, height: tile.height)
        ctx.draw(tile, in: drawRect)
        
        return ctx.makeImage() ?? tile
    }
    
    /// 创建输出画布 (CGContext)
    private func createOutputContext(width: Int, height: Int) -> CGContext? {
        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }
    
    // MARK: - Image Processing Helpers
    
    /// 缩放 CGImage 到指定尺寸
    private func scaleImage(_ image: CGImage, to size: CGSize) -> CGImage? {
        let ciImage = CIImage(cgImage: image)
        let scaleX = size.width / CGFloat(image.width)
        let scaleY = size.height / CGFloat(image.height)
        
        guard let lanczos = CIFilter(name: "CILanczosScaleTransform") else { return nil }
        lanczos.setValue(ciImage, forKey: kCIInputImageKey)
        lanczos.setValue(scaleX, forKey: kCIInputScaleKey)
        lanczos.setValue(scaleY / scaleX, forKey: kCIInputAspectRatioKey)
        
        guard let output = lanczos.outputImage else { return nil }
        return context.createCGImage(output, from: CGRect(origin: .zero, size: size))
    }
    
    /// 创建 BGR 格式的 CVPixelBuffer (模型期望 BGR)
    private func createBGRPixelBuffer(from image: CGImage, size: CGSize) -> CVPixelBuffer? {
        let width = Int(size.width)
        let height = Int(size.height)
        
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        
        // 使用 32BGRA 格式 (B 在最低字节)
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width, height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        
        guard let cgContext = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        cgContext.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return buffer
    }
    
    /// 从 BGR CVPixelBuffer 创建 NSImage (转换回 RGB)
    private func createImageFromBGRBuffer(_ buffer: CVPixelBuffer) -> NSImage? {
        // CIImage 可以正确处理 BGRA 格式
        let ciImage = CIImage(cvPixelBuffer: buffer)
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        let size = NSSize(width: CGFloat(CVPixelBufferGetWidth(buffer)),
                          height: CGFloat(CVPixelBufferGetHeight(buffer)))
        return NSImage(cgImage: cgImage, size: size)
    }
    
    /// 缩放 CGImage 到目标尺寸（使用 CGContext 直接绘制，100% 精确像素控制）
    /// - Parameters:
    ///   - cgImage: 原始 CGImage（像素尺寸）
    ///   - targetSize: 目标点尺寸
    ///   - backingScale: 屏幕缩放因子（Retina=2.0）
    /// - Note: 方案 A - 使用 CGContext 直接绘制，避免 CILanczosScaleTransform 输出尺寸不精确问题
    private func scaleCGImage(_ cgImage: CGImage, to targetSize: NSSize, backingScale: CGFloat) -> NSImage? {
        // 精确计算目标像素尺寸（整数）
        let targetPixelWidth = Int(targetSize.width * backingScale)
        let targetPixelHeight = Int(targetSize.height * backingScale)
        
        logger.info("🔍 scaleCGImage Debug: cgImage=\(cgImage.width)x\(cgImage.height), targetPixels=\(targetPixelWidth)x\(targetPixelHeight), backingScale=\(backingScale)")
        
        // 创建精确像素尺寸的 CGContext
        guard let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: targetPixelWidth,
                height: targetPixelHeight,
                bitsPerComponent: cgImage.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: cgImage.bitmapInfo.rawValue
              ) else {
            logger.error("❌ scaleCGImage: Failed to create CGContext")
            return nil
        }
        
        // 高质量插值
        context.interpolationQuality = .high
        
        // 绘制到精确尺寸
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetPixelWidth, height: targetPixelHeight))
        
        guard let resultCGImage = context.makeImage() else {
            logger.error("❌ scaleCGImage: Failed to create result image")
            return nil
        }
        
        logger.info("🔍 scaleCGImage Output: resultCGImage=\(resultCGImage.width)x\(resultCGImage.height), targetSize=\(targetSize.width)x\(targetSize.height)")
        
        // NSImage.size 使用点尺寸，CGImage 像素 = targetSize × backingScale（精确对应）
        return NSImage(cgImage: resultCGImage, size: targetSize)
    }
    
    /// 兼容旧接口：缩放 NSImage 到目标尺寸
    private func scaleNSImage(_ image: NSImage, to targetSize: NSSize, backingScale: CGFloat = 2.0) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return scaleCGImage(cgImage, to: targetSize, backingScale: backingScale)
    }
    
    /// 仅锐化图片（不缩放）
    func sharpen(_ image: NSImage, sharpness: CGFloat = 0.5) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        guard let filter = CIFilter(name: "CISharpenLuminance") else {
            return nil
        }
        
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(sharpness, forKey: kCIInputSharpnessKey)
        
        guard let outputImage = filter.outputImage,
              let resultCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        
        return NSImage(cgImage: resultCGImage, size: image.size)
    }
}
