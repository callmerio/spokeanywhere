import Foundation
import AppKit
import ScreenCaptureKit
import os

// MARK: - Screenshot Manager

/// 截图管理器
/// 管理截图窗口的生命周期、持久化和恢复
@MainActor
final class ScreenshotManager {
    
    // MARK: - Singleton
    
    static let shared = ScreenshotManager()
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "ScreenshotManager")
    
    // MARK: - Properties
    
    /// 所有截图项
    private(set) var items: [ScreenshotItem] = []
    
    /// 截图窗口映射 (itemId -> window)
    private var windows: [UUID: NSPanel] = [:]
    
    /// 窗口创建回调（由 UI 层注入）
    var windowFactory: ((ScreenshotItem) -> NSPanel)?
    
    // MARK: - Storage
    
    private var screenshotsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Spoke/Screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Spoke/screenshot_items.json")
    }
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Public API
    
    /// 触发区域截图
    func captureRegion() async {
        print("📸 [ScreenshotManager] captureRegion triggered")
        
        // 检查屏幕录制权限
        let hasPermission = await checkAndRequestPermission()
        guard hasPermission else {
            print("🚫 [ScreenshotManager] Screen capture permission not granted")
            return
        }
        
        guard let image = await ScreenCaptureService.shared.captureRegion() else {
            print("🚫 [ScreenshotManager] User cancelled or capture failed")
            return
        }
        
        // 保存图片到文件
        let itemId = UUID()
        let imagePath = screenshotsDirectory.appendingPathComponent("\(itemId.uuidString).png")
        
        guard saveImage(image, to: imagePath) else {
            logger.error("❌ [ScreenshotManager] Failed to save image")
            return
        }
        
        // 计算初始窗口位置（鼠标附近）
        let mouseLocation = NSEvent.mouseLocation
        let frame = CGRect(
            x: mouseLocation.x - image.size.width / 2,
            y: mouseLocation.y - image.size.height / 2,
            width: image.size.width,
            height: image.size.height
        )
        
        // 创建 ScreenshotItem（记录原始尺寸用于保持宽高比）
        let item = ScreenshotItem(
            id: itemId,
            imagePath: imagePath.path,
            frame: frame,
            originalSize: image.size
        )
        item.cachedImage = image
        
        items.append(item)
        
        // 创建并显示窗口
        showWindow(for: item)
        
        logger.info("✅ [ScreenshotManager] Screenshot created: \(itemId)")
    }
    
    /// Pin 截图到当前 Space
    func pin(_ item: ScreenshotItem) {
        item.isPinned = true
        updateWindowBehavior(for: item)
        saveAll()
        logger.info("📌 [ScreenshotManager] Pinned: \(item.id)")
    }
    
    /// Unpin 截图
    func unpin(_ item: ScreenshotItem) {
        item.isPinned = false
        updateWindowBehavior(for: item)
        saveAll()
        logger.info("📌 [ScreenshotManager] Unpinned: \(item.id)")
    }
    
    /// 锁定截图（禁止拖拽/缩放）
    func lock(_ item: ScreenshotItem) {
        item.isLocked = true
        updateWindowBehavior(for: item)
        saveAll()
        logger.info("🔒 [ScreenshotManager] Locked: \(item.id)")
    }
    
    /// 解锁截图
    func unlock(_ item: ScreenshotItem) {
        item.isLocked = false
        updateWindowBehavior(for: item)
        saveAll()
        logger.info("🔓 [ScreenshotManager] Unlocked: \(item.id)")
    }
    
    /// 关闭截图窗口
    func close(_ item: ScreenshotItem) {
        // 关闭窗口
        if let window = windows[item.id] {
            window.orderOut(nil)
            windows.removeValue(forKey: item.id)
        }
        
        // 如果未 Pin，删除数据
        if !item.isPinned {
            removeItem(item)
        }
        
        logger.info("❌ [ScreenshotManager] Closed: \(item.id)")
    }
    
    /// 更新窗口位置
    func updateFrame(_ frame: CGRect, for item: ScreenshotItem) {
        item.frame = frame
        saveAll()
    }
    
    /// 复制图片到剪贴板
    func copyToClipboard(_ item: ScreenshotItem) {
        guard let image = item.loadImage() else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        
        logger.info("📋 [ScreenshotManager] Copied to clipboard: \(item.id)")
    }
    
    // MARK: - Persistence
    
    /// 保存所有 Pinned 截图
    func saveAll() {
        let pinnedItems = items.filter { $0.isPinned }
        
        do {
            let data = try JSONEncoder().encode(pinnedItems)
            try data.write(to: storageURL)
            logger.info("💾 [ScreenshotManager] Saved \(pinnedItems.count) pinned items")
        } catch {
            logger.error("❌ [ScreenshotManager] Save failed: \(error.localizedDescription)")
        }
    }
    
    /// 恢复所有 Pinned 截图（App 启动时调用）
    func restoreAll() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            logger.info("📂 [ScreenshotManager] No saved items to restore")
            return
        }
        
        do {
            let data = try Data(contentsOf: storageURL)
            let savedItems = try JSONDecoder().decode([ScreenshotItem].self, from: data)
            
            for item in savedItems {
                // 验证图片文件存在
                guard FileManager.default.fileExists(atPath: item.imagePath) else {
                    logger.warning("⚠️ [ScreenshotManager] Image not found: \(item.imagePath)")
                    continue
                }
                
                items.append(item)
                showWindow(for: item)
            }
            
            logger.info("✅ [ScreenshotManager] Restored \(savedItems.count) items")
        } catch {
            logger.error("❌ [ScreenshotManager] Restore failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private
    
    private func showWindow(for item: ScreenshotItem) {
        guard let factory = windowFactory else {
            logger.error("❌ [ScreenshotManager] windowFactory not set")
            return
        }
        
        let window = factory(item)
        windows[item.id] = window
        
        updateWindowBehavior(for: item)
        window.setFrame(item.frame, display: true)
        window.orderFront(nil)
    }
    
    private func updateWindowBehavior(for item: ScreenshotItem) {
        guard let window = windows[item.id] else { return }
        
        // Pin to Space 行为
        if item.isPinned {
            window.collectionBehavior = []
        } else {
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        }
        
        // Lock 行为
        window.isMovableByWindowBackground = !item.isLocked
    }
    
    private func removeItem(_ item: ScreenshotItem) {
        // 删除图片文件
        try? FileManager.default.removeItem(atPath: item.imagePath)
        
        // 从列表移除
        items.removeAll { $0.id == item.id }
        
        saveAll()
    }
    
    private func saveImage(_ image: NSImage, to url: URL) -> Bool {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return false
        }
        
        do {
            try pngData.write(to: url)
            return true
        } catch {
            logger.error("❌ [ScreenshotManager] Failed to write image: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Permission
    
    /// 检查并请求屏幕录制权限
    private func checkAndRequestPermission() async -> Bool {
        // macOS 15+ 使用 SCShareableContent 检查
        if #available(macOS 15.0, *) {
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                return true
            } catch {
                print("📸 [ScreenshotManager] Permission check failed: \(error.localizedDescription)")
                await showPermissionGuide()
                return false
            }
        }
        
        // macOS 14 及更早版本
        if CGPreflightScreenCaptureAccess() {
            return true
        }
        
        // 请求权限
        CGRequestScreenCaptureAccess()
        await showPermissionGuide()
        return false
    }
    
    /// 显示权限引导弹窗
    private func showPermissionGuide() async {
        let alert = NSAlert()
        alert.messageText = "需要屏幕录制权限"
        alert.informativeText = """
        截图功能需要「屏幕与系统音频录制」权限。
        
        请点击下方按钮打开系统设置，然后：
        1. 找到 SpokenAnyWhere 应用
        2. 启用权限开关
        3. 如未找到，点击 + 号手动添加应用
        
        授权后需要重新触发截图。
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            SystemAudioCaptureService.openScreenCaptureSettings()
        }
    }
}
