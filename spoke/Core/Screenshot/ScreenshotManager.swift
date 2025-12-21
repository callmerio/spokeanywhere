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
    /// 使用自建选区 UI，精确获取选区坐标
    func captureRegion() async {
        logger.info("📸 [ScreenshotManager] captureRegion triggered")
        
        // 检查屏幕录制权限
        let hasPermission = await checkAndRequestPermission()
        guard hasPermission else {
            logger.warning("🚫 [ScreenshotManager] Screen capture permission not granted")
            return
        }
        
        // 1. 截取鼠标所在屏幕
        guard let (screenImage, screenFrame) = await ScreenCaptureService.shared.captureCurrentScreenWithFrame() else {
            logger.error("❌ [ScreenshotManager] Failed to capture current screen")
            return
        }
        
        // 2. 显示选区 UI，等待用户选择
        let result = await showRegionSelectionUI(backgroundImage: screenImage, screenFrame: screenFrame)
        
        guard let (viewSelectionRect, croppedImage, confirmMode) = result else {
            logger.info("🚫 [ScreenshotManager] User cancelled region selection")
            return
        }
        
        // 3. 处理不同的确认模式
        switch confirmMode {
        case .copy:
            // 直接复制到剪贴板，不创建窗口
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([croppedImage])
            logger.info("📋 [ScreenshotManager] Screenshot copied to clipboard")
            return
            
        case .temporary, .pin:
            break // 继续创建窗口
        }
        
        // 4. 保存图片到文件
        let itemId = UUID()
        let imagePath = screenshotsDirectory.appendingPathComponent("\(itemId.uuidString).png")
        
        guard saveImage(croppedImage, to: imagePath) else {
            logger.error("❌ [ScreenshotManager] Failed to save image")
            return
        }
        
        // 5. 计算窗口位置
        let screenSelectionRect = CGRect(
            x: screenFrame.origin.x + viewSelectionRect.origin.x,
            y: screenFrame.origin.y + viewSelectionRect.origin.y,
            width: viewSelectionRect.width,
            height: viewSelectionRect.height
        )
        
        let padding: CGFloat = ScreenshotContentView.paddingPerSide
        let frame = CGRect(
            x: screenSelectionRect.midX - (croppedImage.size.width + padding * 2) / 2,
            y: screenSelectionRect.midY - (croppedImage.size.height + padding * 2) / 2,
            width: croppedImage.size.width + padding * 2,
            height: croppedImage.size.height + padding * 2
        )
        
        // 6. 创建 ScreenshotItem
        let item = ScreenshotItem(
            id: itemId,
            imagePath: imagePath.path,
            frame: frame,
            originalSize: croppedImage.size
        )
        item.cachedImage = croppedImage
        
        // 如果是 Pin 模式，直接标记为 Pinned
        if confirmMode == .pin {
            item.isPinned = true
            // 保存当前显示器名称
            let mouseLocation = NSEvent.mouseLocation
            if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
                item.screenLocalizedName = screen.localizedName
            }
        }
        
        items.append(item)
        
        // 7. 创建并显示窗口
        showWindow(for: item)
        
        // 如果是 Pin 模式，保存状态
        if confirmMode == .pin {
            saveAll()
        }
        
        logger.info("✅ [ScreenshotManager] Screenshot created (mode: \(confirmMode)): \(itemId)")
    }
    
    /// 显示选区 UI 并等待用户选择
    /// - Returns: (视图内选区坐标, 裁剪后的图片, 确认模式) 或 nil（用户取消）
    private func showRegionSelectionUI(backgroundImage: NSImage, screenFrame: CGRect) async -> (CGRect, NSImage, RegionSelectionWindow.ConfirmMode)? {
        return await withCheckedContinuation { continuation in
            let selectionWindow = RegionSelectionWindow(screenFrame: screenFrame)
            selectionWindow.setBackgroundImage(backgroundImage)
            
            selectionWindow.onComplete = { rect, croppedImage, confirmMode in
                continuation.resume(returning: (rect, croppedImage, confirmMode))
            }
            
            selectionWindow.onCancel = {
                continuation.resume(returning: nil)
            }
            
            selectionWindow.show()
        }
    }
    
    /// Pin 截图到当前 Space
    func pin(_ item: ScreenshotItem) {
        item.isPinned = true
        
        // 保存当前显示器名称，用于跨重启恢复
        if let window = windows[item.id], let screen = window.screen ?? NSScreen.main {
            item.screenLocalizedName = screen.localizedName
        }
        
        updateWindowBehavior(for: item)
        saveAll()
        logger.info("📌 [ScreenshotManager] Pinned: \(item.id) on screen: \(item.screenLocalizedName ?? "unknown")")
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
    
    /// 标记截图（橙色光晕）
    /// Mark 时自动 Pin：如果截图未 Pin，标记时会自动 Pin
    func mark(_ item: ScreenshotItem) {
        item.isMarked = true
        
        // 🎯 Mark 时自动 Pin：已标记的内容通常需要保留在当前 Space
        if !item.isPinned {
            pin(item)
            logger.info("📌 [ScreenshotManager] Auto-pinned due to mark")
        }
        
        updateGlow(for: item)
        saveAll()
        logger.info("🏷️ [ScreenshotManager] Marked: \(item.id)")
    }
    
    /// 取消标记
    func unmark(_ item: ScreenshotItem) {
        item.isMarked = false
        updateGlow(for: item)
        saveAll()
        logger.info("🏷️ [ScreenshotManager] Unmarked: \(item.id)")
    }
    
    /// 关闭截图窗口
    /// Close = 永久删除，无论是否 Pinned
    func close(_ item: ScreenshotItem) {
        // 关闭窗口
        if let window = windows[item.id] {
            window.orderOut(nil)
            windows.removeValue(forKey: item.id)
        }
        
        // 删除数据（无论是否 Pinned）
        removeItem(item)
        
        // 更新持久化存储
        saveAll()
        
        logger.info("❌ [ScreenshotManager] Closed and removed: \(item.id)")
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
    
    /// 切换 Pin 状态
    func togglePin(_ item: ScreenshotItem) {
        if item.isPinned {
            unpin(item)
        } else {
            pin(item)
        }
    }
    
    /// 切换 Mark 状态
    func toggleMark(_ item: ScreenshotItem) {
        if item.isMarked {
            unmark(item)
        } else {
            mark(item)
        }
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
                
                // 恢复到正确的显示器
                adjustFrameToScreen(for: item)
                
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
        guard let window = windows[item.id] as? ScreenshotWindow else { return }
        
        // Pin to Space 行为
        if item.isPinned {
            window.collectionBehavior = []
        } else {
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        }
        
        // Lock 行为
        window.isMovableByWindowBackground = !item.isLocked
        
        // 更新光晕
        window.updateGlow()
    }
    
    private func updateGlow(for item: ScreenshotItem) {
        guard let window = windows[item.id] as? ScreenshotWindow else { return }
        window.updateGlow()
    }
    
    private func removeItem(_ item: ScreenshotItem) {
        // 删除图片文件
        try? FileManager.default.removeItem(atPath: item.imagePath)
        
        // 从列表移除
        items.removeAll { $0.id == item.id }
        
        saveAll()
    }
    
    /// 将窗口位置调整到保存时的显示器
    private func adjustFrameToScreen(for item: ScreenshotItem) {
        guard let savedScreenName = item.screenLocalizedName else {
            // 没有保存的显示器信息，保持原位置
            return
        }
        
        // 查找匹配的显示器
        let targetScreen = NSScreen.screens.first { $0.localizedName == savedScreenName }
        
        guard let screen = targetScreen else {
            // 找不到原显示器，尝试放到主显示器
            logger.info("📺 [ScreenshotManager] Original screen '\(savedScreenName)' not found, using main screen")
            if let mainScreen = NSScreen.main {
                item.frame = adjustFrameToFit(item.frame, in: mainScreen)
            }
            return
        }
        
        // 检查窗口是否已经在目标显示器上
        let screenFrame = screen.visibleFrame
        if screenFrame.contains(item.frame.origin) {
            return
        }
        
        // 计算窗口在原显示器坐标系中的相对位置
        // 然后映射到目标显示器
        item.frame = adjustFrameToFit(item.frame, in: screen)
        logger.info("📺 [ScreenshotManager] Adjusted frame to screen: \(savedScreenName)")
    }
    
    /// 确保窗口位置在指定显示器的可见区域内
    private func adjustFrameToFit(_ frame: CGRect, in screen: NSScreen) -> CGRect {
        let screenFrame = screen.visibleFrame
        var newFrame = frame
        
        // 确保窗口不会超出显示器边界
        if newFrame.maxX > screenFrame.maxX {
            newFrame.origin.x = screenFrame.maxX - newFrame.width
        }
        if newFrame.minX < screenFrame.minX {
            newFrame.origin.x = screenFrame.minX
        }
        if newFrame.maxY > screenFrame.maxY {
            newFrame.origin.y = screenFrame.maxY - newFrame.height
        }
        if newFrame.minY < screenFrame.minY {
            newFrame.origin.y = screenFrame.minY
        }
        
        // 如果窗口比显示器大，缩小窗口并居中
        if newFrame.width > screenFrame.width {
            newFrame.size.width = screenFrame.width * 0.9
            newFrame.origin.x = screenFrame.minX + (screenFrame.width - newFrame.width) / 2
        }
        if newFrame.height > screenFrame.height {
            newFrame.size.height = screenFrame.height * 0.9
            newFrame.origin.y = screenFrame.minY + (screenFrame.height - newFrame.height) / 2
        }
        
        return newFrame
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
