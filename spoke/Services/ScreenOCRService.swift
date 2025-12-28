import AppKit
import ImageIO
import os
import ScreenCaptureKit
import UniformTypeIdentifiers
import Vision

// MARK: - String Extension

private extension String {
    /// 将字符串按指定长度分割
    func split(every length: Int) -> [String] {
        guard length > 0, !isEmpty else { return [self] }
        var result: [String] = []
        var startIndex = self.startIndex
        while startIndex < self.endIndex {
            let endIndex = self.index(startIndex, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
            result.append(String(self[startIndex..<endIndex]))
            startIndex = endIndex
        }
        return result
    }
}

/// 屏幕 OCR 服务
/// 使用 Vision 框架快速提取当前聚焦窗口的文本内容
@MainActor
final class ScreenOCRService {
    
    // MARK: - Singleton
    
    static let shared = ScreenOCRService()
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "ScreenOCRService")
    
    // MARK: - Cache
    
    /// 缓存：避免短时间内重复 OCR
    private var cachedText: String?
    private var cacheTimestamp: Date?
    private let cacheValidDuration: TimeInterval = 60.0 // 缓存 60 秒（覆盖整个录音周期）
    
    /// 预取任务
    private var prefetchTask: Task<String?, Never>?
    
    private init() {}
    
    // MARK: - Public API
    
    /// 获取当前聚焦窗口的 OCR 文本
    /// - Parameter maxLength: 最大文本长度（避免 token 过多）
    /// - Returns: OCR 提取的文本，失败返回 nil
    func getActiveWindowText(maxLength: Int = 2000) async -> String? {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 检查缓存
        if let cached = cachedText,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValidDuration {
            logger.info("🔍 [OCR] 使用缓存 | 长度: \(cached.count, privacy: .public) 字符")
            return cached
        }
        
        // 获取聚焦窗口截图（使用 ScreenCaptureKit）
        let captureStart = CFAbsoluteTimeGetCurrent()
        guard let image = await captureActiveWindow() else {
            logger.warning("🔍 [OCR] ❌ 窗口捕获失败")
            return nil
        }
        let captureTime = (CFAbsoluteTimeGetCurrent() - captureStart) * 1000
        logger.info("🔍 [OCR] 窗口捕获 | \(image.width, privacy: .public)x\(image.height, privacy: .public) | 耗时: \(String(format: "%.1f", captureTime), privacy: .public)ms")
        
        // 执行 OCR
        let ocrStart = CFAbsoluteTimeGetCurrent()
        let text = await performOCR(on: image)
        let ocrTime = (CFAbsoluteTimeGetCurrent() - ocrStart) * 1000
        
        // 限制长度并缓存
        let trimmedText = text.map { String($0.prefix(maxLength)) }
        cachedText = trimmedText
        cacheTimestamp = Date()
        
        let totalTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        if let result = trimmedText {
            logger.info("🔍 [OCR] ✅ 识别完成 | 长度: \(result.count, privacy: .public) 字符 | OCR: \(String(format: "%.1f", ocrTime), privacy: .public)ms | 总计: \(String(format: "%.1f", totalTime), privacy: .public)ms")
            // 保存完整 OCR 内容到文件（日志有长度限制，文件没有）
            saveDebugOCRText(result)
        } else {
            logger.warning("🔍 [OCR] ⚠️ 无文本内容 | 耗时: \(String(format: "%.1f", totalTime), privacy: .public)ms")
        }
        
        return trimmedText
    }
    
    /// 预取 OCR（录音开始时调用，异步执行不阻塞）
    func prefetch() {
        // 取消之前的预取任务
        prefetchTask?.cancel()
        
        // 清除旧缓存
        clearCache()
        
        logger.info("🔍 [OCR] 🚀 开始预取...")
        
        prefetchTask = Task {
            _ = await getActiveWindowText(maxLength: 1500)
            return cachedText
        }
    }
    
    /// 等待预取完成并返回结果（超时 3 秒）
    func awaitPrefetch() async -> String? {
        // 已有缓存，直接返回
        if let cached = cachedText {
            logger.info("🔍 [OCR] 📋 使用缓存")
            return cached
        }
        
        guard let task = prefetchTask else {
            return nil
        }
        
        // 超时 3 秒：OCR 没完成就放弃，继续 LLM
        let timeoutNanos: UInt64 = 3_000_000_000
        
        return await withTaskGroup(of: String?.self) { group in
            // OCR 任务
            group.addTask {
                return await task.value
            }
            
            // 超时任务
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanos)
                return nil
            }
            
            // 谁先完成用谁的结果
            if let result = await group.next() {
                group.cancelAll()
                if result != nil {
                    self.logger.info("🔍 [OCR] ✅ 预取完成")
                } else {
                    self.logger.warning("🔍 [OCR] ⏰ 超时，跳过")
                }
                return result
            }
            return nil
        }
    }
    
    /// 清除缓存
    func clearCache() {
        cachedText = nil
        cacheTimestamp = nil
        prefetchTask?.cancel()
        prefetchTask = nil
    }
    
    // MARK: - Capture
    
    /// 捕获当前聚焦窗口（使用 ScreenCaptureKit）
    func captureActiveWindow() async -> CGImage? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        
        // 排除自身
        if frontApp.bundleIdentifier == Bundle.main.bundleIdentifier {
            return nil
        }
        
        do {
            // 先检查权限状态，避免在主线程阻塞等待权限对话框
            // 注意：macOS 15+ 首次调用会触发权限请求，需要用户手动在设置中授权
            let content: SCShareableContent
            do {
                content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            } catch {
                // 权限被拒绝或未授权
                logger.warning("🔍 [OCR] ⚠️ 屏幕录制权限未授权，请在 系统设置 → 隐私与安全性 → 屏幕录制 中授权")
                return nil
            }
            
            // 找到目标应用的所有窗口
            let appWindows = content.windows.filter { window in
                window.owningApplication?.processID == frontApp.processIdentifier
            }
            
            guard !appWindows.isEmpty else {
                logger.warning("🔍 [OCR] ⚠️ 未找到窗口 | 应用: \(frontApp.localizedName ?? "Unknown", privacy: .public)")
                return nil
            }
            
            // 选择最大的窗口（通常是主窗口）
            let targetWindow = appWindows.max(by: { win1, win2 in
                (win1.frame.width * win1.frame.height) < (win2.frame.width * win2.frame.height)
            })!
            
            logger.info("🔍 [OCR] 窗口选择 | 应用: \(frontApp.localizedName ?? "Unknown", privacy: .public) | 窗口数: \(appWindows.count, privacy: .public) | 选中: \(targetWindow.title ?? "无标题", privacy: .public) | 尺寸: \(Int(targetWindow.frame.width), privacy: .public)x\(Int(targetWindow.frame.height), privacy: .public)")
            
            // 配置截图参数 - 使用原始分辨率（Retina 显示器会自动 2x）
            let filter = SCContentFilter(desktopIndependentWindow: targetWindow)
            let config = SCStreamConfiguration()
            config.width = Int(targetWindow.frame.width)
            config.height = Int(targetWindow.frame.height)
            config.scalesToFit = true  // 确保按目标尺寸缩放
            config.showsCursor = false
            config.captureResolution = .best  // Retina 自动提供高分辨率
            
            // 捕获截图
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
            
            // 🔍 调试：保存截图到临时目录
            saveDebugImage(image, appName: frontApp.localizedName ?? "Unknown")
            
            return image
        } catch {
            logger.error("🔍 [OCR] ❌ ScreenCaptureKit 错误: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
    
    /// 执行 OCR
    /// OCR 识别 - 在后台线程执行避免阻塞主线程
    /// 主线程阻塞会导致 CGEvent tap 超时被系统禁用，造成快捷键失效
    private func performOCR(on image: CGImage) async -> String? {
        // 使用 nonisolated 在后台线程执行 OCR，避免阻塞主线程
        // 这样 CGEvent tap 可以正常响应快捷键
        await Task.detached(priority: .userInitiated) {
            await withCheckedContinuation { continuation in
                let request = VNRecognizeTextRequest { request, _ in
                    if request.results == nil {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    // 提取所有识别的文本
                    let text = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }.joined(separator: "\n")
                    
                    continuation.resume(returning: text.isEmpty ? nil : text)
                }
                
                // 必须使用 Accurate 模式才能识别中文
                // Fast: 1396ms, 11013字符, 中文0个 ❌
                // Accurate: 2547ms, 3684字符, 中文269个 ✅
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
                
                let handler = VNImageRequestHandler(cgImage: image, options: [:])
                
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }.value
    }
    
    /// 调试：保存 OCR 文本到 .tmp_frames 目录
    private func saveDebugOCRText(_ text: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmmss"
        let timestamp = formatter.string(from: Date())
        let filename = "ocr_\(timestamp).txt"
        
        let tmpDir = URL(fileURLWithPath: "/Users/bigdan/Workspace/macos/spokeanywhere/.tmp_frames")
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        
        let fileURL = tmpDir.appendingPathComponent(filename)
        
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            logger.info("🔍 [OCR] 📝 文本已保存: \(filename, privacy: .public)")
            
            // 清理旧文件，只保留最近 20 个
            cleanupOldFiles(in: tmpDir, prefix: "ocr_", extension: "txt", keepCount: 20)
        } catch {
            logger.warning("🔍 [OCR] ⚠️ 文本保存失败: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// 调试：保存截图到项目 .tmp_frames 目录
    private func saveDebugImage(_ image: CGImage, appName: String) {
        let timestamp = Int(Date().timeIntervalSince1970)
        let safeName = appName.replacingOccurrences(of: " ", with: "_")
        let filename = "OCR_\(safeName)_\(timestamp).png"
        
        // 保存到项目的 .tmp_frames 目录
        let tmpDir = URL(fileURLWithPath: "/Users/bigdan/Workspace/macos/spokeanywhere/.tmp_frames")
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        
        let fileURL = tmpDir.appendingPathComponent(filename)
        
        // 保存为 PNG
        guard let dest = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            logger.warning("🔍 [OCR] ⚠️ 无法创建图像目标: \(fileURL.path, privacy: .public)")
            return
        }
        CGImageDestinationAddImage(dest, image, nil)
        if CGImageDestinationFinalize(dest) {
            logger.info("🔍 [OCR] 📸 截图已保存: \(filename, privacy: .public) | 尺寸: \(image.width, privacy: .public)x\(image.height, privacy: .public)")
            
            // 清理旧截图，只保留最近 20 个
            cleanupOldFiles(in: tmpDir, prefix: "OCR_", extension: "png", keepCount: 20)
        } else {
            logger.warning("🔍 [OCR] ⚠️ 截图保存失败")
        }
    }
    
    /// 清理旧文件，只保留最近指定数量的文件
    /// - Parameters:
    ///   - directory: 目录 URL
    ///   - prefix: 文件名前缀
    ///   - fileExtension: 文件扩展名
    ///   - keepCount: 保留的文件数量
    private func cleanupOldFiles(in directory: URL, prefix: String, extension fileExtension: String, keepCount: Int) {
        let fm = FileManager.default
        
        do {
            let files = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == fileExtension }
            
            guard files.count > keepCount else { return }
            
            // 按创建时间排序（最新的在前）
            let sortedFiles = files.sorted { file1, file2 in
                let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2
            }
            
            // 删除超出数量的旧文件
            let filesToDelete = sortedFiles.dropFirst(keepCount)
            for file in filesToDelete {
                try fm.removeItem(at: file)
            }
            
            if !filesToDelete.isEmpty {
                logger.info("🔍 [OCR] 🗑️ 清理旧文件: \(filesToDelete.count, privacy: .public) 个 \(prefix)*.\(fileExtension, privacy: .public)")
            }
        } catch {
            logger.warning("🔍 [OCR] ⚠️ 清理旧文件失败: \(error.localizedDescription, privacy: .public)")
        }
    }
}
