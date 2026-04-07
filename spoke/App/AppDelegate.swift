import AppKit
import os
import SwiftData
import SwiftUI

@MainActor
struct AppDelegateDependencies {
    let notificationCenter: NotificationCenter
    let hotKeyService: HotKeyService
    let quickAskService: QuickAskService
    let screenshotManager: ScreenshotManager
    let dictionaryPanelManager: DictionaryPanelManager
    let debugAutomationTrigger: DebugAutomationTriggerService
    let recordingController: RecordingController
    let liveCaptionWindowManager: LiveCaptionWindowManager
    let selectionActionService: SelectionActionService
    let appSettings: AppSettings
    let selectionToolbarManager: SelectionToolbarManager
    let trackpadSwipeService: TrackpadSwipeService
    let messagePanelManager: MessagePanelManager
    let historyManager: HistoryManager
    let resourceMonitor: ResourceMonitor
    let clipboardHistoryService: ClipboardHistoryService
    let transcriptionModelManager: TranscriptionModelManager
    let transcriptionManager: TranscriptionManager
    let crashLogger: CrashLogger
}

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
    private var toolbarSettingsObserver: NSObjectProtocol?
    private let dependencies: AppDelegateDependencies
    private let settingsWindowRuntime = SettingsWindowRuntime.live
    private lazy var screenshotRuntime = AppScreenshotRuntime(
        makeWindow: { item in
            ScreenshotWindow(item: item)
        },
        updateFrame: { [screenshotManager = dependencies.screenshotManager] frame, item in
            screenshotManager.updateFrame(frame, for: item)
        },
        restoreAll: { [screenshotManager = dependencies.screenshotManager] in
            await screenshotManager.restoreAll()
        },
        captureRegion: { [screenshotManager = dependencies.screenshotManager] in
            await screenshotManager.captureRegion()
        },
        debugCaptureForAutomation: { [screenshotManager = dependencies.screenshotManager] in
            await screenshotManager.debugCaptureForAutomation()
        }
    )

    private typealias LifecycleStep = (name: String, action: () -> Void)

    override init() {
        AppIdentity.migrateLegacyUserDefaultsIfNeeded()
        self.dependencies = .makeLive()
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 启动计时（仅用于内部 logger）
        let launchStart = CFAbsoluteTimeGetCurrent()
        let launchLogger = Logger(subsystem: "com.spokeanywhere", category: "Launch")

        runStartupPipeline(launchStart: launchStart, launchLogger: launchLogger)

        logLaunchStep("Step 12: Application launch complete! ✅", launchStart: launchStart, launchLogger: launchLogger)

        if ProcessInfo.processInfo.environment["SPOKE_PERF_LOG"] == "1" {
            let launchTotalMs = Int((CFAbsoluteTimeGetCurrent() - launchStart) * 1000)
            print("PERF launch_total_ms=\(launchTotalMs)")
        }
    }
    
    private func setupScreenshotService() {
        logger.info("📸 [AppDelegate] setupScreenshotService() 开始")
        
        // 设置 HotKeyService 的截图回调
        dependencies.hotKeyService.onScreenshotTrigger = { [weak self] in
            self?.triggerScreenshot()
        }
        
        // 设置 ScreenshotManager 的窗口工厂
        dependencies.screenshotManager.windowFactory = screenshotRuntime.makeWindowFactory()
        
        // 异步恢复之前 Pinned 的截图，避免启动阶段主线程阻塞
        runAppDelegateUtilityTask(self) { delegate in
            await delegate.screenshotRuntime.restorePinnedScreenshots { message in
                delegate.logger.info("\(message, privacy: .public)")
            }
        }
        
        logger.info("📸 [AppDelegate] ✅ Screenshot service setup complete")
    }
    
    private func setupDictionaryPanel() {
        logger.info("📖 [AppDelegate] setupDictionaryPanel() 开始")
        
        dependencies.dictionaryPanelManager.registerShortcut()
        
        logger.info("📖 [AppDelegate] ✅ Dictionary panel setup complete (⌥+Space)")
    }

#if DEBUG
    private func setupDebugAutomationTrigger() {
        let trigger = dependencies.debugAutomationTrigger
        trigger.onRecordingToggle = {
            self.dependencies.recordingController.debugToggleRecording()
        }
        trigger.onCaptionToggle = {
            self.dependencies.liveCaptionWindowManager.toggle()
        }
        trigger.onScreenshotCapture = {
            runAppMainActorAsync {
                await self.dependencies.screenshotManager.debugCaptureForAutomation()
            }
        }
        trigger.onMessagePanelToggle = {
            self.dependencies.messagePanelManager.toggle()
        }
        trigger.onQuickAskTrigger = {
            self.dependencies.quickAskService.startSession()
        }
        if trigger.start() {
            logger.info("🧪 [AppDelegate] Debug automation trigger ready")
        } else {
            logger.info("🧪 [AppDelegate] Debug automation trigger disabled by env")
        }
    }
#endif
    
    private func setupSelectionToolbar() {
        logger.info("📋 [AppDelegate] setupSelectionToolbar() 开始")
        
        // 初始化动作服务 (监听通知)
        _ = dependencies.selectionActionService
        logger.info("📋 [AppDelegate] SelectionActionService 已初始化")
        
        // 监听打开工具栏设置的通知
        installObserver(&toolbarSettingsObserver, forName: .openToolbarSettings) { [weak self] notification in
            let focusAddSkill = notification.userInfo?["focusAddSkill"] as? Bool ?? false
            self?.presentSettingsWindow(focusToolbar: true, focusAddSkill: focusAddSkill)
        }
        
        // 启动工具栏管理器 (根据设置决定是否自动启动)
        let enabled = dependencies.appSettings.selectionToolbarEnabled
        logger.info("📋 [AppDelegate] selectionToolbarEnabled = \(enabled)")
        
        if enabled {
            dependencies.selectionToolbarManager.start(requestPermissionIfNeeded: false)
            logger.info("📋 [AppDelegate] ✅ Selection toolbar started")
        } else {
            logger.info("📋 [AppDelegate] ⏸️ Selection toolbar disabled in settings")
        }
    }
    
    private func setupTrackpadGesture() {
        NSLog("🖐️ 设置触控板手势 (公开 API)...")
        let gesture = dependencies.trackpadSwipeService
        let panel = dependencies.messagePanelManager
        
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
        
        // 启动监听 (需要 Accessibility 权限)
        gesture.start(requestPermissionIfNeeded: false)
    }
    
    private func performHistoryCleanup() {
        let settings = dependencies.appSettings
        runAppMainActorAsync {
            await self.makeHistoryMaintenanceRuntime().runAutoCleanup(
                using: AppHistoryMaintenanceSettings(
                    autoCleanupEnabled: settings.historyAutoCleanupEnabled,
                    keepDays: settings.historyKeepDays,
                    maxCount: settings.historyMaxCount
                )
            )
        }
    }
    
    private func performOrphanCleanup() {
        runAppMainActorAsync {
            await self.makeHistoryMaintenanceRuntime().runOrphanMaintenance()
        }
    }
    
    private func setupResourceMonitor() {
        let monitor = dependencies.resourceMonitor
        
        // 阈值配置
        monitor.cpuThreshold = 150  // CPU 150%（多核可能超100%）
        monitor.memoryThresholdMB = 800  // 内存 800MB
        
        // 启动监控，超限时降级
        monitor.start(interval: 3.0) {
            NSLog("⚠️ 资源超限！执行降级策略...")
            
            // 降级策略：停止非关键服务
            runAppMainActorAsync {
                // 1. 停止剪贴板监控
                self.dependencies.clipboardHistoryService.stop()
                
                // 2. 关闭 MessagePanel
                self.dependencies.messagePanelManager.hide()
                
                NSLog("🔻 已降级：停止剪贴板监控、关闭面板")
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        for step in buildShutdownSteps() {
            step.action()
        }
    }
    
    // MARK: - Private
    
    private func checkAccessibilityPermission() {
        let trusted = MainActor.assumeIsolated {
            AccessibilityHelper.hasAccessibilityPermission()
        }

        if trusted {
            print("✅ Accessibility permission granted")
        } else {
            print("⚠️ Accessibility permission not granted (startup check only)")
        }
    }
    
    private var modeMenuItem: NSMenuItem?

    private func runStartupPipeline(launchStart: CFAbsoluteTime, launchLogger: Logger) {
        for step in buildStartupSteps() {
            logLaunchStep(step.name, launchStart: launchStart, launchLogger: launchLogger)
            step.action()
        }
    }

    private func buildStartupSteps() -> [LifecycleStep] {
        AppLifecyclePlan.startup(includeDebugAutomation: includeDebugAutomationStep)
            .map { spec in
                (spec.name, startupAction(for: spec.id))
            }
    }

    private func buildShutdownSteps() -> [LifecycleStep] {
        AppLifecyclePlan.shutdown(includeDebugAutomation: includeDebugAutomationStep)
            .map { spec in
                (spec.name, shutdownAction(for: spec.id))
            }
    }

    private var includeDebugAutomationStep: Bool {
#if DEBUG
        true
#else
        false
#endif
    }

    private func startupAction(for id: AppLifecycleStepID) -> () -> Void {
        switch id {
        case .installCrashLogger: return installCrashLogger
        case .checkAccessibility: return checkAccessibilityPermission
        case .setupMenuBar: return setupMenuBar
        case .startClipboardService: return startClipboardService
        case .startRecordingController: return startRecordingController
        case .configureHistoryManager: return configureHistoryManager
        case .performHistoryCleanup: return performHistoryCleanup
        case .performOrphanCleanup: return performOrphanCleanup
        case .prepareDictionary: return prepareDictionaryIfNeeded
        case .warmupSpeechEngine: return warmupSpeechEngineInBackground
        case .setupTrackpadGesture: return setupTrackpadGesture
        case .setupResourceMonitor: return setupResourceMonitor
        case .setupSelectionToolbar: return setupSelectionToolbar
        case .setupScreenshotService: return setupScreenshotService
        case .setupDictionaryPanel: return setupDictionaryPanel
        case .setupDebugAutomationTrigger:
#if DEBUG
            return setupDebugAutomationTrigger
#else
            return {}
#endif
        case .stopRecordingController,
             .stopTrackpadGesture,
             .stopSelectionToolbar,
             .stopResourceMonitor,
             .removeNotificationObservers,
             .stopDebugAutomationTrigger:
            return {}
        }
    }

    private func shutdownAction(for id: AppLifecycleStepID) -> () -> Void {
        switch id {
        case .stopRecordingController:
            return { self.dependencies.recordingController.stop() }
        case .stopTrackpadGesture:
            return { self.dependencies.trackpadSwipeService.stop() }
        case .stopSelectionToolbar:
            return { self.dependencies.selectionToolbarManager.stop() }
        case .stopResourceMonitor:
            return { self.dependencies.resourceMonitor.stop() }
        case .removeNotificationObservers:
            return { self.removeAllObservers() }
        case .stopDebugAutomationTrigger:
#if DEBUG
            return { self.dependencies.debugAutomationTrigger.stop() }
#else
            return {}
#endif
        case .installCrashLogger,
             .checkAccessibility,
             .setupMenuBar,
             .startClipboardService,
             .startRecordingController,
             .configureHistoryManager,
             .performHistoryCleanup,
             .performOrphanCleanup,
             .prepareDictionary,
             .warmupSpeechEngine,
             .setupTrackpadGesture,
             .setupResourceMonitor,
             .setupSelectionToolbar,
             .setupScreenshotService,
             .setupDictionaryPanel,
             .setupDebugAutomationTrigger:
            return {}
        }
    }

    private func logLaunchStep(_ name: String, launchStart: CFAbsoluteTime, launchLogger: Logger) {
        let envEnabled = ProcessInfo.processInfo.environment["SPOKE_STARTUP_LOG"] == "1"
        let settingsEnabled = dependencies.appSettings.startupDiagnosticsEnabled
        guard envEnabled || settingsEnabled else { return }

        let totalTime = (CFAbsoluteTimeGetCurrent() - launchStart) * 1000
        launchLogger.info("🚀 \(name) [\(String(format: "%.0f", totalTime))ms]")
    }

    private func installCrashLogger() {
        dependencies.crashLogger.install()
    }

    private func startClipboardService() {
        dependencies.clipboardHistoryService.start()
    }

    private func startRecordingController() {
        dependencies.recordingController.start()
    }

    private func configureHistoryManager() {
        dependencies.historyManager.configure(with: Self.sharedModelContainer.mainContext)
    }

    private func prepareDictionaryIfNeeded() {
        // 双轨词典注入策略：
        // 1. contextualStrings（轻量级）- 每次录音时实时注入，无需预编译
        // 2. 预编译 LM（重量级）- 启动时后台准备，准备好后提供更强识别效果
        // 只有当前选择的模型支持预编译 LM 时才执行
        if #available(macOS 26.0, *) {
            let config = dependencies.transcriptionModelManager.getProviderConfiguration()
            if config.enablePrecompiledLM {
                print("  → Starting dictionary precompilation (background)...")
                runAppDetached(priority: .background) { [transcriptionManager = dependencies.transcriptionManager] in
                    await transcriptionManager.prepareDictionary()
                }
            } else {
                print("  → Skipping (model doesn't support it)")
            }
            return
        }

        // macOS 25 及以下，使用 SFSpeechRecognizer，支持预编译
        print("  → Starting dictionary precompilation (background)...")
        runAppDetached(priority: .background) { [transcriptionManager = dependencies.transcriptionManager] in
            await transcriptionManager.prepareDictionary()
        }
    }

    private func warmupSpeechEngineInBackground() {
        // 预热语音引擎（后台）- 消除首次使用时的 ~2s 卡顿
        // SpeechTranscriber assets 安装是主要耗时点
        runAppDetached(priority: .background) { [transcriptionManager = dependencies.transcriptionManager] in
            await Self.warmupSpeechEngine(transcriptionManager: transcriptionManager)
        }
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "SpokenAnyWhere")
        }
        
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "SpokenAnyWhere", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        // 动态显示当前快捷键
        let hotkeyItem = NSMenuItem(title: "快捷键: \(dependencies.appSettings.shortcutDisplayString)", action: nil, keyEquivalent: "")
        hotkeyItem.isEnabled = false
        self.hotkeyMenuItem = hotkeyItem
        menu.addItem(hotkeyItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 实时字幕
        let captionItem = NSMenuItem(title: "实时字幕", action: #selector(toggleLiveCaption), keyEquivalent: "s")
        captionItem.keyEquivalentModifierMask = .option
        menu.addItem(captionItem)
        
        // 选择工具栏
        let toolbarItem = NSMenuItem(title: "选择工具栏", action: #selector(toggleSelectionToolbar), keyEquivalent: "")
        toolbarItem.state = dependencies.appSettings.selectionToolbarEnabled ? .on : .off
        self.selectionToolbarMenuItem = toolbarItem
        menu.addItem(toolbarItem)
        
        // 区域截图
        let screenshotItem = NSMenuItem(title: "区域截图", action: #selector(triggerScreenshot), keyEquivalent: "a")
        screenshotItem.keyEquivalentModifierMask = .option
        menu.addItem(screenshotItem)
        
        // 查词
        let dictionaryItem = NSMenuItem(title: "查词", action: #selector(toggleDictionaryPanel), keyEquivalent: " ")
        dictionaryItem.keyEquivalentModifierMask = .option
        menu.addItem(dictionaryItem)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        
        // 监听快捷键变更通知
        setupShortcutObserver()
    }
    
    private func setupShortcutObserver() {
        installObserver(&shortcutObserver, forName: AppSettings.shortcutDidChangeNotification) { [weak self] _ in
            self?.updateHotkeyMenuItem()
        }
    }
    
    private func updateHotkeyMenuItem() {
        hotkeyMenuItem?.title = "快捷键: \(dependencies.appSettings.shortcutDisplayString)"
    }
    
    @objc func toggleLiveCaption() {
        dependencies.liveCaptionWindowManager.toggle()
    }
    
    @objc func toggleSelectionToolbar() {
        dependencies.appSettings.selectionToolbarEnabled.toggle()
        selectionToolbarMenuItem?.state = dependencies.appSettings.selectionToolbarEnabled ? .on : .off
    }
    
    @objc func toggleDictionaryPanel() {
        dependencies.dictionaryPanelManager.toggle()
    }
    
    @objc func triggerScreenshot() {
        runAppMainActorAsync {
            await self.screenshotRuntime.captureRegion()
        }
    }
    
    @objc func openSettings() {
        presentSettingsWindow(focusToolbar: false, focusAddSkill: false)
    }
    
    private var settingsWindowObserver: NSObjectProtocol?
    
    private func presentSettingsWindow(focusToolbar: Bool, focusAddSkill: Bool) {
        print("⚙️ openSettings called, focusToolbar=\(focusToolbar), focusAddSkill=\(focusAddSkill)")
        
        settingsWindowRuntime.prepareForPresentation()
        
        // 如果窗口已存在，直接显示（并发送通知切换 tab）
        if let window = settingsWindow {
            print("⚙️ Reusing existing window")
            settingsWindowRuntime.reuseExistingWindow(window)
            if focusToolbar {
                postSettingsSwitchToToolbar(focusAddSkill: focusAddSkill)
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
        
        // 监听窗口关闭，恢复 accessory 模式
        installObserver(&settingsWindowObserver, forName: NSWindow.willCloseNotification, object: window) { [weak self] _ in
            guard let self else { return }
            self.settingsWindow = nil
            self.removeObserver(&self.settingsWindowObserver)
            self.settingsWindowRuntime.restoreAfterClose(showInDock: self.dependencies.appSettings.showInDock)
        }
        
        self.settingsWindow = window
        
        settingsWindowRuntime.showNewWindow(window)
    }

    private func postSettingsSwitchToToolbar(focusAddSkill: Bool) {
        dependencies.notificationCenter.post(
            name: .settingsSwitchToToolbar,
            object: nil,
            userInfo: ["focusAddSkill": focusAddSkill]
        )
    }

    private func installObserver(
        _ observer: inout NSObjectProtocol?,
        forName name: Notification.Name,
        object: Any? = nil,
        queue: OperationQueue? = .main,
        using handler: @escaping @MainActor (Notification) -> Void
    ) {
        removeObserver(&observer)
        observer = dependencies.notificationCenter.addObserver(
            forName: name,
            object: object,
            queue: queue
        ) { notification in
            runAppMainActor {
                handler(notification)
            }
        }
    }

    private func removeAllObservers() {
        removeObserver(&shortcutObserver)
        removeObserver(&toolbarSettingsObserver)
        removeObserver(&settingsWindowObserver)
    }

    private func removeObserver(_ observer: inout NSObjectProtocol?) {
        guard let existingObserver = observer else { return }
        dependencies.notificationCenter.removeObserver(existingObserver)
        observer = nil
    }

    private func makeHistoryMaintenanceRuntime() -> AppHistoryMaintenanceRuntime {
        AppHistoryMaintenanceRuntime(
            performCleanup: { [historyManager = dependencies.historyManager] policy in
                await historyManager.performCleanup(policy: policy)
            },
            migrateLegacyTodayRecords: { [historyManager = dependencies.historyManager] in
                await historyManager.migrateLegacyTodayRecords()
            },
            cleanupOrphanedAudioFiles: { [historyManager = dependencies.historyManager] in
                await historyManager.cleanupOrphanedAudioFiles()
            },
            enforceNormalRecordLimit: { [historyManager = dependencies.historyManager] maxCount in
                await historyManager.enforceNormalRecordLimit(maxCount: maxCount)
            },
            enforceAudioSizeLimit: { [historyManager = dependencies.historyManager] maxSizeMB in
                await historyManager.enforceAudioSizeLimit(maxSizeMB: maxSizeMB)
            }
        )
    }
    
    // MARK: - Speech Engine Warmup
    
    /// 预热语音引擎，消除首次使用时的卡顿
    /// SpeechTranscriber assets 安装是主要耗时点（~1.8s）
    private static func warmupSpeechEngine(transcriptionManager: TranscriptionManager) async {
        let warmupLogger = Logger(subsystem: "com.spokeanywhere", category: "AppDelegate")
        do {
            // 1. 创建 provider（触发引擎选择）- 需要在 MainActor 上执行
            let provider = await MainActor.run {
                transcriptionManager.createBestProvider()
            }
            
            // 2. 调用 prepare() 触发 assets 安装
            try await provider.prepare()
            
            // 3. 立即重置，释放资源（预热完成后不需要保持）
            await MainActor.run {
                provider.reset()
            }
        } catch {
            warmupLogger.warning("⚠️ Speech engine warmup skipped due to error: \(error.localizedDescription, privacy: .public)")
        }
    }
}
