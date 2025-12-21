import AppKit
import CoreImage
import Vision
import CoreML
import os
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
        
        let inputWidth = cgImage.width
        let inputHeight = cgImage.height
        let outputWidth = inputWidth * scaleFactor
        let outputHeight = inputHeight * scaleFactor
        
        // 如果图片小于等于 tile 尺寸，直接处理
        if inputWidth <= tileSize && inputHeight <= tileSize {
            return processSingleTile(cgImage, model: model, targetSize: targetSize)
        }
        
        // Tiling 处理大图 (使用 tilePad 策略，参考 Real-ESRGAN)
        logger.info("🔲 Using tiling: \(inputWidth)x\(inputHeight) -> \(outputWidth)x\(outputHeight)")
        
        // 创建输出画布 (4x 尺寸)
        guard let outputContext = createOutputContext(width: outputWidth, height: outputHeight) else {
            logger.error("Failed to create output context")
            return nil
        }
        
        // 计算 tile 数量 (stride = tileSize，无 overlap)
        let tilesX = Int(ceil(Double(inputWidth) / Double(tileSize)))
        let tilesY = Int(ceil(Double(inputHeight) / Double(tileSize)))
        
        logger.info("📦 Processing \(tilesX * tilesY) tiles (\(tilesX)x\(tilesY)) with tilePad=\(self.tilePad)")
        
        for tileY in 0..<tilesY {
            for tileX in 0..<tilesX {
                // 计算 tile 的原始区域 (不含 padding)
                let inputStartX = tileX * tileSize
                let inputStartY = tileY * tileSize
                let inputEndX = min(inputStartX + tileSize, inputWidth)
                let inputEndY = min(inputStartY + tileSize, inputHeight)
                
                // tile 的实际尺寸
                let tileWidth = inputEndX - inputStartX
                let tileHeight = inputEndY - inputStartY
                
                // 计算带 padding 的裁剪区域 (向外扩展 tilePad)
                let inputStartXPad = max(inputStartX - tilePad, 0)
                let inputStartYPad = max(inputStartY - tilePad, 0)
                let inputEndXPad = min(inputEndX + tilePad, inputWidth)
                let inputEndYPad = min(inputEndY + tilePad, inputHeight)
                
                // 裁剪带 padding 的 tile
                let paddedRect = CGRect(
                    x: inputStartXPad,
                    y: inputStartYPad,
                    width: inputEndXPad - inputStartXPad,
                    height: inputEndYPad - inputStartYPad
                )
                guard let paddedTileCGImage = cgImage.cropping(to: paddedRect) else { continue }
                
                // Pad 到 512x512 (如果需要)
                let modelInputTile = padTileToModelSize(paddedTileCGImage)
                
                // 处理 tile
                guard let upscaledTile = processOneTile(modelInputTile, model: model) else { continue }
                
                // 计算输出中有效区域的位置 (去掉 padding)
                // padding 在输入侧的偏移量
                let padLeft = inputStartX - inputStartXPad
                let padTop = inputStartY - inputStartYPad
                
                // 输出侧对应的偏移量 (4x)
                let outputStartXTile = padLeft * scaleFactor
                let outputStartYTile = padTop * scaleFactor
                let outputTileWidth = tileWidth * scaleFactor
                let outputTileHeight = tileHeight * scaleFactor
                
                // 从 upscaledTile 中裁剪有效区域
                // 注意: CGImage 坐标系是左上角原点
                let validRect = CGRect(
                    x: outputStartXTile,
                    y: outputStartYTile,
                    width: outputTileWidth,
                    height: outputTileHeight
                )
                guard let validTile = upscaledTile.cropping(to: validRect) else { continue }
                
                // 计算在输出画布上的位置
                let outX = inputStartX * scaleFactor
                let outY = inputStartY * scaleFactor
                
                // 绘制到输出画布 (CGContext 坐标系是左下角原点，需要翻转 Y)
                let drawRect = CGRect(
                    x: outX,
                    y: outputHeight - outY - outputTileHeight,
                    width: outputTileWidth,
                    height: outputTileHeight
                )
                outputContext.draw(validTile, in: drawRect)
            }
        }
        
        // 生成最终图像
        guard let resultCGImage = outputContext.makeImage() else {
            logger.error("Failed to create result image")
            return nil
        }
        
        let resultImage = NSImage(cgImage: resultCGImage, size: NSSize(width: outputWidth, height: outputHeight))
        
        // 缩放到目标尺寸
        return scaleNSImage(resultImage, to: targetSize)
    }
    
    /// 处理单个 tile (小于 512x512 的图片直接处理)
    private func processSingleTile(_ cgImage: CGImage, model: MLModel, targetSize: NSSize) -> NSImage? {
        let paddedTile = padTileToModelSize(cgImage)
        guard let upscaled = processOneTile(paddedTile, model: model) else { return nil }
        
        // 裁剪到实际输出尺寸 (从左上角开始)
        let actualWidth = cgImage.width * scaleFactor
        let actualHeight = cgImage.height * scaleFactor
        let cropRect = CGRect(x: 0, y: 0, width: actualWidth, height: actualHeight)
        
        guard let croppedImage = upscaled.cropping(to: cropRect) else { return nil }
        let resultImage = NSImage(cgImage: croppedImage, size: NSSize(width: actualWidth, height: actualHeight))
        
        return scaleNSImage(resultImage, to: targetSize)
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
    
    /// 缩放 NSImage 到目标尺寸
    private func scaleNSImage(_ image: NSImage, to targetSize: NSSize) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        let scaleX = targetSize.width / ciImage.extent.width
        let scaleY = targetSize.height / ciImage.extent.height
        let scale = min(scaleX, scaleY)
        
        guard let lanczos = CIFilter(name: "CILanczosScaleTransform") else { return nil }
        lanczos.setValue(ciImage, forKey: kCIInputImageKey)
        lanczos.setValue(scale, forKey: kCIInputScaleKey)
        lanczos.setValue(1.0, forKey: kCIInputAspectRatioKey)
        
        guard let output = lanczos.outputImage,
              let resultCGImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }
        
        // 🔧 Fix: 保持原图宽高比，不强制使用 targetSize
        // Lanczos 等比例缩放后，实际尺寸是 (原宽*scale, 原高*scale)
        let actualSize = NSSize(
            width: ciImage.extent.width * scale,
            height: ciImage.extent.height * scale
        )
        return NSImage(cgImage: resultCGImage, size: actualSize)
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
