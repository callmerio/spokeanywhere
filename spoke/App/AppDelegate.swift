import AppKit
import SwiftUI
import SwiftData
import os

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Singleton (for access from HotKeyService)
    static var shared: AppDelegate?
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "AppDelegate")
    
    // MARK: - Shared ModelContainer (专属路径避免冲突)
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([HistoryItem.self, AppRule.self, AIProviderConfig.self])
        
        // 使用专属路径，避免和其他应用冲突
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let spokeDataDir = appSupport.appendingPathComponent("Spoke/Data", isDirectory: true)
        
        // 确保目录存在
        try? FileManager.default.createDirectory(at: spokeDataDir, withIntermediateDirectories: true)
        
        let storeURL = spokeDataDir.appendingPathComponent("SpokenAnyWhere.store")
        let config = ModelConfiguration(schema: schema, url: storeURL)
        
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            print("✅ ModelContainer initialized at: \(storeURL.path)")
            return container
        } catch {
            fatalError("❌ Failed to create ModelContainer: \(error)")
        }
    }()
    
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var hotkeyMenuItem: NSMenuItem?
    private var shortcutObserver: NSObjectProtocol?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 SpokenAnyWhere started")
        
        print("📍 Step 0: Installing crash logger...")
        // 安装崩溃日志记录器
        CrashLogger.shared.install()
        
        print("📍 Step 1: Checking accessibility permission...")
        // 检查辅助功能权限
        checkAccessibilityPermission()
        
        print("📍 Step 2: Setting up status bar...")
        // 创建状态栏图标
        setupMenuBar()
        
        print("📍 Step 3: Starting clipboard service...")
        ClipboardHistoryService.shared.start()
        
        print("📍 Step 4: Starting recording controller...")
        RecordingController.shared.start()
        
        print("📍 Step 5: Configuring HistoryManager...")
        // 先配置 HistoryManager 的 ModelContext
        HistoryManager.shared.configure(with: Self.sharedModelContainer.mainContext)
        
        print("📍 Step 6: Performing history cleanup...")
        performHistoryCleanup()
        
        print("📍 Step 6.1: Cleaning orphaned audio files...")
        performOrphanCleanup()
        
        // 双轨词典注入策略：
        // 1. contextualStrings（轻量级）- 每次录音时实时注入，无需预编译
        // 2. 预编译 LM（重量级）- 启动时后台准备，准备好后提供更强识别效果
        // 只有当前选择的模型支持预编译 LM 时才执行
        if #available(macOS 26.0, *) {
            let config = TranscriptionModelManager.shared.getProviderConfiguration()
            if config.enablePrecompiledLM {
                print("📍 Step 6.5: Starting dictionary precompilation (background)...")
                Task.detached(priority: .background) {
                    await TranscriptionManager.shared.prepareDictionary()
                }
            } else {
                print("📍 Step 6.5: Skipping precompilation (model doesn't support it)")
            }
        } else {
            // macOS 25 及以下，使用 SFSpeechRecognizer，支持预编译
            print("📍 Step 6.5: Starting dictionary precompilation (background)...")
            Task.detached(priority: .background) {
                await TranscriptionManager.shared.prepareDictionary()
            }
        }
        
        print("📍 Step 7: Setting up trackpad gesture...")
        setupTrackpadGesture()
        
        print("📍 Step 8: Starting resource monitor...")
        setupResourceMonitor()
        
        print("📍 Step 9: Application launch complete!")
    }
    
    private func setupTrackpadGesture() {
        NSLog("🖐️ 设置触控板手势...")
        let gesture = TrackpadGestureService.shared
        let panel = MessagePanelManager.shared
        
        // 配置回调
        gesture.onOpenPanel = {
            if !panel.isVisible {
                panel.show()
            }
        }
        
        gesture.onClosePanel = {
            if panel.isVisible {
                panel.hide()
            }
        }
        
        gesture.isPanelVisible = {
            panel.isVisible
        }
        
        // 启动监听
        gesture.start()
    }
    
    private func performHistoryCleanup() {
        let settings = AppSettings.shared
        guard settings.historyAutoCleanupEnabled else { return }
        
        Task {
            // 按天数清理
            if settings.historyKeepDays > 0 {
                await HistoryManager.shared.performCleanup(policy: .keepDays(settings.historyKeepDays))
            }
            
            // 按条数清理
            if settings.historyMaxCount > 0 {
                await HistoryManager.shared.performCleanup(policy: .keepCount(settings.historyMaxCount))
            }
        }
    }
    
    private func performOrphanCleanup() {
        Task {
            // 降级过期的 Today 记录
            await HistoryManager.shared.downgradeExpiredTodayRecords()
            // 清理孤儿音频文件（磁盘有文件但数据库无记录）
            await HistoryManager.shared.cleanupOrphanedAudioFiles()
            // 限制普通记录数量为 50 条（today/note 不受影响）
            await HistoryManager.shared.enforceNormalRecordLimit(maxCount: 50)
            // 限制音频总大小为 2GB
            await HistoryManager.shared.enforceAudioSizeLimit(maxSizeMB: 2048)
        }
    }
    
    private func setupResourceMonitor() {
        let monitor = ResourceMonitor.shared
        
        // 阈值配置
        monitor.cpuThreshold = 150  // CPU 150%（多核可能超100%）
        monitor.memoryThresholdMB = 800  // 内存 800MB
        
        // 启动监控，超限时降级
        monitor.start(interval: 3.0) {
            NSLog("⚠️ 资源超限！执行降级策略...")
            
            // 降级策略：停止非关键服务
            Task { @MainActor in
                // 1. 停止剪贴板监控
                ClipboardHistoryService.shared.stop()
                
                // 2. 关闭 MessagePanel
                MessagePanelManager.shared.hide()
                
                NSLog("🔻 已降级：停止剪贴板监控、关闭面板")
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        RecordingController.shared.stop()
        TrackpadGestureService.shared.stop()
        ResourceMonitor.shared.stop()
    }
    
    // MARK: - Private
    
    private func checkAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if trusted {
            print("✅ Accessibility permission granted")
        } else {
            print("⚠️ Accessibility permission required for global hotkeys")
        }
    }
    
    private var modeMenuItem: NSMenuItem?
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "SpokenAnyWhere")
        }
        
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "SpokenAnyWhere", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        // 动态显示当前快捷键
        let hotkeyItem = NSMenuItem(title: "快捷键: \(AppSettings.shared.shortcutDisplayString)", action: nil, keyEquivalent: "")
        hotkeyItem.isEnabled = false
        self.hotkeyMenuItem = hotkeyItem
        menu.addItem(hotkeyItem)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: ","))
        
        menu.addItem(NSMenuItem.separator())
        
        // 实时字幕
        let captionItem = NSMenuItem(title: "实时字幕", action: #selector(toggleLiveCaption), keyEquivalent: "s")
        captionItem.keyEquivalentModifierMask = .option
        menu.addItem(captionItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        
        // 监听快捷键变更通知
        setupShortcutObserver()
    }
    
    private func setupShortcutObserver() {
        shortcutObserver = NotificationCenter.default.addObserver(
            forName: AppSettings.shortcutDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateHotkeyMenuItem()
            }
        }
    }
    
    private func updateHotkeyMenuItem() {
        hotkeyMenuItem?.title = "快捷键: \(AppSettings.shared.shortcutDisplayString)"
    }
    
    @objc func toggleLiveCaption() {
        LiveCaptionWindowManager.shared.toggle()
    }
    
    @objc func openSettings() {
        print("⚙️ openSettings called")
        
        // 如果窗口已存在，直接显示
        if let window = settingsWindow {
            print("⚙️ Reusing existing window")
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let container = Self.sharedModelContainer
        
        print("⚙️ Creating new settings window...")
        
        // 创建设置视图
        let settingsView = SettingsView()
            .modelContainer(container)
        
        // 创建窗口 - 深色融合标题栏风格
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // 深色标题栏融合风格
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0) // #141414
        window.isMovableByWindowBackground = true
        
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false
        
        self.settingsWindow = window
        
        print("⚙️ Showing window...")
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        print("⚙️ Window should be visible now, frame: \(window.frame)")
    }
}
