import AppKit
import Foundation
import os
import ScreenCaptureKit

// MARK: - Screenshot Manager

@MainActor
struct ScreenshotManagerDependencies {
    let enhancementPath: () -> String
    let copyEnhancedImageEnabled: () -> Bool
    let resetBlurDiagnostics: () -> Void
    let blurMainDispatchP95: () -> Double
    let blurCoverage: () -> Bool
    let captureScreen: @MainActor (NSScreen) async -> NSImage?
    let copyImageToPasteboard: (NSImage) -> Void
    let openScreenCaptureSettings: () -> Void
}

/// 截图管理器
/// 管理截图窗口的生命周期、持久化和恢复
@MainActor
final class ScreenshotManager {
    
    // MARK: - Singleton
    
    static let shared = ScreenshotManager(dependencies: .live)
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "ScreenshotManager")
    private let dependencies: ScreenshotManagerDependencies

    // MARK: - Diagnostic Counters (R2-2)

    /// 截图捕获开始时间（用于计算端到端延迟）
    private var captureStartTime: CFAbsoluteTime = 0

    /// 最近一次截图的增强路径（none/basic/ai-fallback）
    private var lastEnhancementPath: String = "none"

    /// saveAll 写入耗时累积（用于计算 P95）
    private var saveAllWriteTimes: [Double] = []

    /// 覆盖标志：是否触发过 saveAll 路径
    private var coverageSaveAll: Bool = false

    /// 覆盖标志：是否触发过 blur 路径（由 ScreenCaptureBlurService 设置）
    private var coverageBlur: Bool = false

#if DEBUG
    /// Debug 自动化上一次创建的截图（用于闭环清理，避免窗口叠加）
    private var debugAutomationLastItemID: UUID?
#endif

    // MARK: - Properties

    /// 所有截图项
    private(set) var items: [ScreenshotItem] = []
    
    /// 截图窗口映射 (itemId -> window)
    private var windows: [UUID: NSPanel] = [:]
    
    /// 当前活跃的选区窗口（用于防止重复触发）
    private weak var activeSelectionWindow: RegionSelectionWindow?
    
    /// 窗口创建回调（由 UI 层注入）
    var windowFactory: ((ScreenshotItem) -> NSPanel)?
    
    // MARK: - Storage

    private var screenshotRootDirectory: URL {
        if let override = ProcessInfo.processInfo.environment["SPOKE_SCREENSHOT_BASE_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Spoke", isDirectory: true)
    }
    
    private var screenshotsDirectory: URL {
        let dir = screenshotRootDirectory.appendingPathComponent("Screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private var storageURL: URL {
        let dir = screenshotRootDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("screenshot_items.json")
    }
    
    // MARK: - Init
    
    private init(dependencies: ScreenshotManagerDependencies) {
        self.dependencies = dependencies
    }
    
    // MARK: - Public API
    
    /// 触发区域截图
    /// 使用自建选区 UI，精确获取选区坐标
    /// 再次触发时取消当前截图（toggle 行为）
    func captureRegion() async {
        resetCaptureDiagnostics()

        logger.info("📸 [ScreenshotManager] captureRegion triggered")
        
        // 如果已有活跃的选区窗口，取消它（toggle 行为）
        if let existingWindow = activeSelectionWindow, existingWindow.isVisible {
            logger.info("📸 [ScreenshotManager] Cancelling existing selection window")
            existingWindow.dismiss()
            activeSelectionWindow = nil
            return
        }

        // 检查屏幕录制权限
        let hasPermission = await checkAndRequestPermission()
        guard hasPermission else {
            logger.warning("🚫 [ScreenshotManager] Screen capture permission not granted")
            return
        }

        // 1. 获取目标屏幕（立即返回）
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
                     ?? NSScreen.main
                     ?? NSScreen.screens.first!
        let screenFrame = screen.frame

        // 2. 显示选区 UI (异步获取截图)
        // 传入 screen 对象以便异步捕获
        let result = await showRegionSelectionUI(screen: screen, screenFrame: screenFrame)

        guard let (viewSelectionRect, croppedImage, confirmMode) = result else {
            logger.info("🚫 [ScreenshotManager] User cancelled region selection")
            return
        }

        // 3. 处理不同的确认模式
        switch confirmMode {
        case .copy:
            // 直接复制到剪贴板，不创建窗口
            dependencies.copyImageToPasteboard(croppedImage)
            logger.info("📋 [ScreenshotManager] Screenshot copied to clipboard")
            return
            
        case .temporary, .pin:
            break // 继续创建窗口
        }

        await persistAndShowScreenshot(
            viewSelectionRect: viewSelectionRect,
            croppedImage: croppedImage,
            screenFrame: screenFrame,
            confirmMode: confirmMode
        )
    }

    /// 应用退出期统一收口入口
    func stop() {
        activeSelectionWindow?.dismiss()
        activeSelectionWindow = nil

        for window in windows.values {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()

        saveAll()
        windowFactory = nil
        logger.info("🛑 Screenshot manager stopped")
    }

#if DEBUG
    /// Debug-only：自动化脚本入口，固定区域截图（无需手动框选）
    func debugCaptureForAutomation() async {
        resetCaptureDiagnostics()

        if let lastID = debugAutomationLastItemID,
           let previousItem = items.first(where: { $0.id == lastID }) {
            // 自动化闭环：每轮先清理上一次自动化截图，避免窗口叠加干扰验收
            close(previousItem)
            debugAutomationLastItemID = nil
            logger.info("🧪 [DebugAutomation] cleaned previous automation screenshot")
        }

        // 自动化路径使用快速预检，避免系统权限弹窗打断后续回归轮次
        guard hasScreenCapturePermissionForAutomation() else {
            logger.warning("🚫 [DebugAutomation] Screen capture permission not granted (preflight)")
            return
        }

        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            logger.error("❌ [DebugAutomation] No screen available")
            return
        }

        guard let fullImage = await dependencies.captureScreen(screen) else {
            logger.error("❌ [DebugAutomation] Full screen capture failed")
            return
        }

        let screenFrame = screen.frame
        let targetWidth = min(screenFrame.width * 0.4, 640)
        let targetHeight = min(screenFrame.height * 0.35, 360)
        let viewSelectionRect = CGRect(
            x: (screenFrame.width - targetWidth) / 2,
            y: (screenFrame.height - targetHeight) / 2,
            width: targetWidth,
            height: targetHeight
        )

        let imageSelectionRect = CGRect(
            x: viewSelectionRect.origin.x * fullImage.size.width / screenFrame.width,
            y: viewSelectionRect.origin.y * fullImage.size.height / screenFrame.height,
            width: viewSelectionRect.width * fullImage.size.width / screenFrame.width,
            height: viewSelectionRect.height * fullImage.size.height / screenFrame.height
        )

        let croppedImage = cropImage(fullImage, to: imageSelectionRect)
        let itemCountBefore = items.count
        await persistAndShowScreenshot(
            viewSelectionRect: viewSelectionRect,
            croppedImage: croppedImage,
            screenFrame: screenFrame,
            confirmMode: .temporary
        )

        if items.count > itemCountBefore, let lastItem = items.last {
            debugAutomationLastItemID = lastItem.id
        }

        logger.info("🧪 [DebugAutomation] screenshot.capture complete")
    }
#endif
    
    /// 显示选区 UI 并等待用户选择
    /// - Returns: (视图内选区坐标, 裁剪后的图片, 确认模式) 或 nil（用户取消）
    private func showRegionSelectionUI(
        screen: NSScreen,
        screenFrame: CGRect
    ) async -> (CGRect, NSImage, RegionSelectionWindow.ConfirmMode)? { // swiftlint:disable:this large_tuple
        let logger = self.logger

        return await withCheckedContinuation { continuation in
            let selectionWindow = RegionSelectionWindow(screenFrame: screenFrame)
            // 保存引用以便 toggle 取消
            self.activeSelectionWindow = selectionWindow

            // 异步获取截图并更新背景
            Task(priority: .userInitiated) {
                logger.info("📸 [ScreenshotManager] Starting async screen capture...")
                if let image = await self.dependencies.captureScreen(screen) {
                    logger.info("✅ [ScreenshotManager] Async capture complete, updating UI")
                    if selectionWindow.isVisible {
                        selectionWindow.setBackgroundImage(image)
                    }
                } else {
                     logger.error("❌ [ScreenshotManager] Async capture failed")
                }
            }

            selectionWindow.onComplete = { [weak self] rect, croppedImage, confirmMode in
                self?.activeSelectionWindow = nil
                continuation.resume(returning: (rect, croppedImage, confirmMode))
            }

            selectionWindow.onCancel = { [weak self] in
                self?.activeSelectionWindow = nil
                continuation.resume(returning: nil)
            }

            selectionWindow.show()
        }
    }

    private func persistAndShowScreenshot(
        viewSelectionRect: CGRect,
        croppedImage: NSImage,
        screenFrame: CGRect,
        confirmMode: RegionSelectionWindow.ConfirmMode
    ) async {
        let itemId = UUID()
        let imagePath = screenshotsDirectory.appendingPathComponent("\(itemId.uuidString).png")

        guard await saveImage(croppedImage, to: imagePath) else {
            logger.error("❌ [ScreenshotManager] Failed to save image")
            return
        }

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

        let item = ScreenshotItem(
            id: itemId,
            imagePath: imagePath.path,
            frame: frame,
            originalSize: croppedImage.size
        )
        item.cachedImage = croppedImage

        if confirmMode == .pin {
            item.isPinned = true
            let mouseLocation = NSEvent.mouseLocation
            if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
                item.screenLocalizedName = screen.localizedName
            }
        }

        items.append(item)
        showWindow(for: item)

        if confirmMode == .pin {
            saveAll()
        }

        let captureLatencyMs = (CFAbsoluteTimeGetCurrent() - self.captureStartTime) * 1000
        let saveAllWriteP95: Double
        if !self.saveAllWriteTimes.isEmpty {
            let sorted = self.saveAllWriteTimes.sorted()
            let p95Index = Int(Double(sorted.count) * 0.95)
            saveAllWriteP95 = sorted[min(p95Index, sorted.count - 1)]
        } else {
            saveAllWriteP95 = 0
        }

        let blurMainDispatchP95: Double
        blurMainDispatchP95 = dependencies.blurMainDispatchP95()
        self.coverageBlur = dependencies.blurCoverage()

        logger.info("""
            ✅ [ScreenshotManager] Screenshot created (mode: \(confirmMode, privacy: .public)): \(itemId, privacy: .public) \
            [capture_latency: \(String(format: "%.0f", captureLatencyMs), privacy: .public)ms, \
            enhancement_path: \(self.lastEnhancementPath, privacy: .public), \
            save_all_write_p95: \(String(format: "%.1f", saveAllWriteP95), privacy: .public)ms, \
            blur_main_dispatch_p95: \(String(format: "%.1f", blurMainDispatchP95), privacy: .public)ms, \
            coverage_saveall: \(self.coverageSaveAll ? 1 : 0, privacy: .public), \
            coverage_blur: \(self.coverageBlur ? 1 : 0, privacy: .public)]
            """)
    }

    private func cropImage(_ image: NSImage, to imageRect: CGRect) -> NSImage {
        let rect = imageRect.integral
        let croppedImage = NSImage(size: rect.size)
        croppedImage.lockFocus()
        image.draw(
            at: NSPoint(x: -rect.origin.x, y: -rect.origin.y),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        croppedImage.unlockFocus()
        return croppedImage
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
    /// - Parameters:
    ///   - item: 截图项
    ///   - enhancedImage: AI 增强后的图片（可选）。如果设置开启且提供了增强图片，则使用增强图片
    func copyToClipboard(_ item: ScreenshotItem, enhancedImage: NSImage? = nil) {
        let imageToUse: NSImage?
        
        // 如果设置开启且提供了增强图片，使用增强图片
        if dependencies.enhancementPath() != "none",
           dependencies.copyEnhancedImageEnabled(), let enhanced = enhancedImage {
            imageToUse = enhanced
            logger.info("📋 [ScreenshotManager] Using enhanced image for clipboard")
        } else {
            imageToUse = item.loadImage()
            logger.info("📋 [ScreenshotManager] Using original image for clipboard")
        }
        
        guard let image = imageToUse else { return }
        
        dependencies.copyImageToPasteboard(image)
        
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

        // R2-2: 测量写入耗时
        let writeStart = CFAbsoluteTimeGetCurrent()

        do {
            let data = try JSONEncoder().encode(pinnedItems)
            try data.write(to: storageURL)

            // R2-2: 记录写入耗时
            let writeMs = (CFAbsoluteTimeGetCurrent() - writeStart) * 1000
            self.saveAllWriteTimes.append(writeMs)
            self.coverageSaveAll = true

            logger.info("💾 [ScreenshotManager] Saved \(pinnedItems.count) pinned items [write_ms: \(String(format: "%.1f", writeMs))]")
        } catch {
            logger.error("❌ [ScreenshotManager] Save failed: \(error.localizedDescription)")
        }
    }
    
    /// 恢复所有 Pinned 截图（App 启动时调用）
    func restoreAll() async {
        let restoreStart = CFAbsoluteTimeGetCurrent()
        var decodeDurationMs = 0
        var uiDurationMs = 0

        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            logger.info("📂 [ScreenshotManager] No saved items to restore")
            return
        }

        // 后台读取和解码，避免阻塞主线程
        let savedItems: [ScreenshotItem]
        do {
            let restoreURL = storageURL
            let decodeStart = CFAbsoluteTimeGetCurrent()
            savedItems = try await runScreenshotManagerDetachedThrowing(priority: .utility) {
                let data = try Data(contentsOf: restoreURL)
                return try JSONDecoder().decode([ScreenshotItem].self, from: data)
            }
            decodeDurationMs = Int((CFAbsoluteTimeGetCurrent() - decodeStart) * 1000)
        } catch {
            logger.error("❌ [ScreenshotManager] Restore failed: \(error.localizedDescription)")
            return
        }

        // 回到主线程创建窗口
        var restoredCount = 0
        let uiStart = CFAbsoluteTimeGetCurrent()
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
            restoredCount += 1

            // 分帧恢复，避免一次性恢复多个窗口造成短时卡顿
            await Task.yield()
        }
        uiDurationMs = Int((CFAbsoluteTimeGetCurrent() - uiStart) * 1000)

        let restoreDurationMs = Int((CFAbsoluteTimeGetCurrent() - restoreStart) * 1000)
        logger.info("✅ [ScreenshotManager] Restored \(restoredCount)/\(savedItems.count) items in \(restoreDurationMs, privacy: .public)ms")

        if ProcessInfo.processInfo.environment["SPOKE_PERF_LOG"] == "1" {
            print("PERF restore_decode_ms=\(decodeDurationMs) restore_ui_ms=\(uiDurationMs) restore_total_ms=\(restoreDurationMs) restored_count=\(restoredCount) decoded_count=\(savedItems.count)")
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
    
    private func saveImage(_ image: NSImage, to url: URL) async -> Bool {
        guard let tiffData = image.tiffRepresentation else {
            return false
        }

        return await runScreenshotManagerDetached(priority: .userInitiated) {
            guard let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                return false
            }

            do {
                try pngData.write(to: url, options: .atomic)
                return true
            } catch {
                return false
            }
        }
    }
    
    // MARK: - Permission

    /// Debug-only 快速权限预检：不触发系统请求流程，避免自动化链路被弹窗阻塞。
    private func hasScreenCapturePermissionForAutomation() -> Bool {
        CGPreflightScreenCaptureAccess()
    }
    
    /// 检查并请求屏幕录制权限
    private func checkAndRequestPermission(shouldShowGuide: Bool = true) async -> Bool {
        // macOS 15+ 使用 SCShareableContent 检查
        if #available(macOS 15.0, *) {
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                return true
            } catch {
                print("📸 [ScreenshotManager] Permission check failed: \(error.localizedDescription)")
                if shouldShowGuide {
                    await showPermissionGuide()
                }
                return false
            }
        }
        
        // macOS 14 及更早版本
        if CGPreflightScreenCaptureAccess() {
            return true
        }
        
        // 请求权限
        CGRequestScreenCaptureAccess()
        if shouldShowGuide {
            await showPermissionGuide()
        }
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
            dependencies.openScreenCaptureSettings()
        }
    }

    private func resetCaptureDiagnostics() {
        captureStartTime = CFAbsoluteTimeGetCurrent()
        saveAllWriteTimes.removeAll()
        coverageSaveAll = false
        coverageBlur = false
        lastEnhancementPath = dependencies.enhancementPath()
        dependencies.resetBlurDiagnostics()
    }
}
