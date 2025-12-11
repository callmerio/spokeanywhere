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
    private var selectionToolbarMenuItem: NSMenuItem?
    private var shortcutObserver: NSObjectProtocol?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let launchStart = CFAbsoluteTimeGetCurrent()
        var stepStart = launchStart
        
        func logStep(_ name: String) {
            let now = CFAbsoluteTimeGetCurrent()
            let stepTime = (now - stepStart) * 1000
            let totalTime = (now - launchStart) * 1000
            print("📍 \(name) [+\(String(format: "%.0f", stepTime))ms, total: \(String(format: "%.0f", totalTime))ms]")
            stepStart = now
        }
        
        print("🚀 SpokenAnyWhere started")
        
        logStep("Step 0: Installing crash logger...")
        // 安装崩溃日志记录器
        CrashLogger.shared.install()
        
        logStep("Step 1: Checking accessibility permission...")
        // 检查辅助功能权限
        checkAccessibilityPermission()
        
        logStep("Step 2: Setting up status bar...")
        // 创建状态栏图标
        setupMenuBar()
        
        logStep("Step 3: Starting clipboard service...")
        ClipboardHistoryService.shared.start()
        
        logStep("Step 4: Starting recording controller...")
        RecordingController.shared.start()
        
        logStep("Step 5: Configuring HistoryManager...")
        // 先配置 HistoryManager 的 ModelContext
        HistoryManager.shared.configure(with: Self.sharedModelContainer.mainContext)
        
        logStep("Step 6: Performing history cleanup...")
        performHistoryCleanup()
        
        logStep("Step 6.1: Cleaning orphaned audio files...")
        performOrphanCleanup()
        
        // 双轨词典注入策略：
        // 1. contextualStrings（轻量级）- 每次录音时实时注入，无需预编译
        // 2. 预编译 LM（重量级）- 启动时后台准备，准备好后提供更强识别效果
        // 只有当前选择的模型支持预编译 LM 时才执行
        logStep("Step 6.5: Checking dictionary precompilation...")
        if #available(macOS 26.0, *) {
            let config = TranscriptionModelManager.shared.getProviderConfiguration()
            if config.enablePrecompiledLM {
                print("  → Starting dictionary precompilation (background)...")
                Task.detached(priority: .background) {
                    await TranscriptionManager.shared.prepareDictionary()
                }
            } else {
                print("  → Skipping (model doesn't support it)")
            }
        } else {
            // macOS 25 及以下，使用 SFSpeechRecognizer，支持预编译
            print("  → Starting dictionary precompilation (background)...")
            Task.detached(priority: .background) {
                await TranscriptionManager.shared.prepareDictionary()
            }
        }
        
        // 预热语音引擎（后台）- 消除首次使用时的 ~2s 卡顿
        // SpeechTranscriber assets 安装是主要耗时点
        logStep("Step 6.6: Warming up speech engine (background)...")
        Task.detached(priority: .background) {
            await Self.warmupSpeechEngine()
        }
        
        logStep("Step 7: Setting up trackpad gesture...")
        setupTrackpadGesture()
        
        logStep("Step 8: Starting resource monitor...")
        setupResourceMonitor()
        
        logStep("Step 9: Starting selection toolbar...")
        setupSelectionToolbar()
        
        logStep("Step 10: Application launch complete! ✅")
    }
    
    private func setupSelectionToolbar() {
        print("📋 [AppDelegate] setupSelectionToolbar() 开始")
        
        // 初始化动作服务 (监听通知)
        _ = SelectionActionService.shared
        print("📋 [AppDelegate] SelectionActionService 已初始化")
        
        // 监听打开工具栏设置的通知
        NotificationCenter.default.addObserver(
            forName: .openToolbarSettings,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let focusAddSkill = notification.userInfo?["focusAddSkill"] as? Bool ?? false
            Task { @MainActor in
                self?.showSettingsWindow(focusToolbar: true, focusAddSkill: focusAddSkill)
            }
        }
        
        // 启动工具栏管理器 (根据设置决定是否自动启动)
        let enabled = AppSettings.shared.selectionToolbarEnabled
        print("📋 [AppDelegate] selectionToolbarEnabled = \(enabled)")
        
        if enabled {
            SelectionToolbarManager.shared.start()
            print("📋 [AppDelegate] ✅ Selection toolbar started")
        } else {
            print("📋 [AppDelegate] ⏸️ Selection toolbar disabled in settings")
        }
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
            // 迁移旧版 today 记录为 todo
            await HistoryManager.shared.migrateLegacyTodayRecords()
            // 清理孤儿音频文件（磁盘有文件但数据库无记录）
            await HistoryManager.shared.cleanupOrphanedAudioFiles()
            // 限制普通记录数量为 50 条（todo/done/note 不受影响）
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
        SelectionToolbarManager.shared.stop()
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
        
        // 选择工具栏
        let toolbarItem = NSMenuItem(title: "选择工具栏", action: #selector(toggleSelectionToolbar), keyEquivalent: "")
        toolbarItem.state = AppSettings.shared.selectionToolbarEnabled ? .on : .off
        self.selectionToolbarMenuItem = toolbarItem
        menu.addItem(toolbarItem)
        
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
    
    @objc func toggleSelectionToolbar() {
        AppSettings.shared.selectionToolbarEnabled.toggle()
        selectionToolbarMenuItem?.state = AppSettings.shared.selectionToolbarEnabled ? .on : .off
    }
    
    @objc func openSettings() {
        showSettingsWindow(focusToolbar: false, focusAddSkill: false)
    }
    
    private func showSettingsWindow(focusToolbar: Bool, focusAddSkill: Bool) {
        print("⚙️ openSettings called, focusToolbar=\(focusToolbar), focusAddSkill=\(focusAddSkill)")
        
        // 如果窗口已存在，直接显示（并发送通知切换 tab）
        if let window = settingsWindow {
            print("⚙️ Reusing existing window")
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            if focusToolbar {
                NotificationCenter.default.post(name: .settingsSwitchToToolbar, object: nil, userInfo: ["focusAddSkill": focusAddSkill])
            }
            return
        }
        
        let container = Self.sharedModelContainer
        
        print("⚙️ Creating new settings window...")
        
        // 创建设置视图
        let settingsView = SettingsView(initialTab: focusToolbar ? .toolbar : nil, focusAddSkill: focusAddSkill)
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
    
    // MARK: - Speech Engine Warmup
    
    /// 预热语音引擎，消除首次使用时的卡顿
    /// SpeechTranscriber assets 安装是主要耗时点（~1.8s）
    private static func warmupSpeechEngine() async {
        let start = CFAbsoluteTimeGetCurrent()
        print("🔥 [Warmup] Starting speech engine warmup...")
        
        do {
            // 1. 创建 provider（触发引擎选择）- 需要在 MainActor 上执行
            let provider = await MainActor.run {
                TranscriptionManager.shared.createBestProvider()
            }
            print("🔥 [Warmup] Provider created: \(type(of: provider))")
            
            // 2. 调用 prepare() 触发 assets 安装
            try await provider.prepare()
            
            // 3. 立即重置，释放资源（预热完成后不需要保持）
            provider.reset()
            
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
            print("🔥 [Warmup] ✅ Speech engine warmed up in \(String(format: "%.0f", elapsed))ms")
        } catch {
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
            print("🔥 [Warmup] ⚠️ Warmup failed after \(String(format: "%.0f", elapsed))ms: \(error.localizedDescription)")
        }
    }
}
