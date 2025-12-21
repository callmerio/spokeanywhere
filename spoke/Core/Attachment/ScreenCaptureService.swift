import Foundation
import AppKit
import ScreenCaptureKit
import os

// MARK: - Screen Capture Service

/// 屏幕截图服务
/// 提供截取当前屏幕的能力
@MainActor
final class ScreenCaptureService {
    
    // MARK: - Singleton
    
    static let shared = ScreenCaptureService()
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "ScreenCapture")
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Capture Current Screen
    
    /// 截取当前屏幕（鼠标所在的屏幕）
    func captureCurrentScreen() async -> NSImage? {
        // 获取鼠标所在的屏幕
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
              ?? NSScreen.main else {
            logger.error("❌ No screen found")
            return nil
        }
        
        return await captureScreen(screen)
    }
    
    /// 截取指定屏幕
    func captureScreen(_ screen: NSScreen) async -> NSImage? {
        do {
            let content = try await SCShareableContent.current
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
                  let scDisplay = content.displays.first(where: { $0.displayID == displayID }) else {
                logger.error("❌ Failed to find SCDisplay for screen")
                return nil
            }
            
            let filter = SCContentFilter(display: scDisplay, excludingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = scDisplay.width
            configuration.height = scDisplay.height
            configuration.showsCursor = false
            
            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            
            // 🔧 Fix: SCDisplay.width/height 返回的是逻辑尺寸（点），不是像素尺寸！
            // 在 HiDPI 缩放模式下（如 3360×1890 @ 2x），SCDisplay 返回 3360×1890
            // 而不是物理像素 6720×3780
            // 所以 NSImage.size 应该直接使用 scDisplay 的尺寸，不需要除以 backingScaleFactor
            let pointSize = NSSize(
                width: CGFloat(scDisplay.width),
                height: CGFloat(scDisplay.height)
            )
            let image = NSImage(cgImage: cgImage, size: pointSize)
            logger.info("✅ Screen captured via SCK: \(Int(scDisplay.width))x\(Int(scDisplay.height)) pt, cgImage: \(cgImage.width)x\(cgImage.height) px")
            
            return image
        } catch {
            logger.error("❌ SCK Capture failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 截取所有屏幕
    func captureAllScreens() async -> [NSImage] {
        var images: [NSImage] = []
        
        for screen in NSScreen.screens {
            if let image = await captureScreen(screen) {
                images.append(image)
            }
        }
        
        return images
    }
    
    /// 截取鼠标所在屏幕（用于选区 UI 背景）
    /// 返回 (截图, 屏幕 frame)
    func captureCurrentScreenWithFrame() async -> (NSImage, CGRect)? {
        // 获取鼠标所在的屏幕
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
              ?? NSScreen.main else {
            logger.error("❌ No screen found for mouse location")
            return nil
        }
        
        guard let image = await captureScreen(screen) else {
            logger.error("❌ Failed to capture current screen")
            return nil
        }
        
        logger.info("✅ Current screen captured: \(Int(screen.frame.width))x\(Int(screen.frame.height))")
        return (image, screen.frame)
    }
    
    // MARK: - Region Capture
    
    /// 区域截图（调用系统 screencapture 工具）
    /// 用户可交互选择截图区域，按 ESC 取消
    /// - Returns: 截取的图片，用户取消或失败时返回 nil
    func captureRegion() async -> NSImage? {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".png")
        
        logger.info("📸 Starting region capture")
        
        return await withCheckedContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(returning: nil)
                return
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-i", tempFile.path]
            
            // 捕获 stderr 以便调试
            let errorPipe = Pipe()
            process.standardError = errorPipe
            
            process.terminationHandler = { proc in
                Task { @MainActor in
                    // 读取 stderr
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                    if !errorOutput.isEmpty {
                        self.logger.warning("📸 stderr: \(errorOutput)")
                    }
                    
                    defer {
                        try? FileManager.default.removeItem(at: tempFile)
                    }
                    
                    let fileExists = FileManager.default.fileExists(atPath: tempFile.path)
                    
                    if fileExists {
                        if let image = NSImage(contentsOf: tempFile) {
                            self.logger.info("✅ Region captured: \(Int(image.size.width))x\(Int(image.size.height))")
                            continuation.resume(returning: image)
                        } else {
                            self.logger.error("❌ Failed to load captured image")
                            continuation.resume(returning: nil)
                        }
                    } else {
                        self.logger.debug("🚫 Region capture cancelled")
                        continuation.resume(returning: nil)
                    }
                }
            }
            
            do {
                try process.run()
            } catch {
                self.logger.error("❌ Failed to start screencapture: \(error.localizedDescription)")
                continuation.resume(returning: nil)
            }
        }
    }
    
    // MARK: - Permission Check
    
    /// 检查屏幕录制权限
    func checkPermission() async -> Bool {
        return CGPreflightScreenCaptureAccess()
    }
    
    /// 请求屏幕录制权限
    func requestPermission() {
        // 打开系统偏好设置的屏幕录制权限页面
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
