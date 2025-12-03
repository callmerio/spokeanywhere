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
            let image = NSImage(cgImage: cgImage, size: screen.frame.size)
            logger.info("✅ Screen captured via SCK: \(Int(scDisplay.width))x\(Int(scDisplay.height))")
            
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
