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
        // 使用 CGWindowListCreateImage 截取屏幕
        // 这是最简单可靠的方式，不需要额外权限（在已有屏幕录制权限的情况下）
        
        let screenRect = screen.frame
        
        // 转换坐标系（NSScreen 使用左下角原点，CGWindow 使用左上角原点）
        let mainScreenHeight = NSScreen.screens.first?.frame.height ?? screenRect.height
        let cgRect = CGRect(
            x: screenRect.origin.x,
            y: mainScreenHeight - screenRect.origin.y - screenRect.height,
            width: screenRect.width,
            height: screenRect.height
        )
        
        // 截取屏幕
        guard let cgImage = CGWindowListCreateImage(
            cgRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) else {
            logger.error("❌ Failed to capture screen")
            return nil
        }
        
        let image = NSImage(cgImage: cgImage, size: screenRect.size)
        logger.info("✅ Screen captured: \(Int(screenRect.width))x\(Int(screenRect.height))")
        
        return image
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
        // 尝试截取一小块区域来检查权限
        let testRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        let testImage = CGWindowListCreateImage(
            testRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            []
        )
        
        return testImage != nil
    }
    
    /// 请求屏幕录制权限
    func requestPermission() {
        // 打开系统偏好设置的屏幕录制权限页面
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
