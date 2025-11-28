import AppKit
import SwiftUI
import SwiftData

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Singleton (for access from HotKeyService)
    static var shared: AppDelegate?
    
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var modelContainer: ModelContainer?
    private var hotkeyMenuItem: NSMenuItem?
    private var shortcutObserver: NSObjectProtocol?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 设置 shared 引用
        AppDelegate.shared = self
        // 确保应用可以显示窗口（非 accessory 模式）
        NSApp.setActivationPolicy(.regular)
        
        // 初始化 SwiftData 容器
        do {
            modelContainer = try ModelContainer(for: HistoryItem.self, AppRule.self, AIProviderConfig.self)
            
            // 配置 HistoryManager
            if let context = modelContainer?.mainContext {
                HistoryManager.shared.configure(with: context)
            }
            
            print("✅ ModelContainer initialized")
        } catch {
            print("❌ Failed to create ModelContainer: \(error)")
        }
        print("🚀 SpokenAnyWhere started")
        
        // 检查辅助功能权限
        checkAccessibilityPermission()
        
        // 设置菜单栏图标
        setupMenuBar()
        
        // 启动剪贴板历史服务
        ClipboardHistoryService.shared.start()
        
        // 启动录音控制器
        RecordingController.shared.start()
        
        // 执行历史记录自动清理
        performHistoryCleanup()
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
    
    func applicationWillTerminate(_ notification: Notification) {
        RecordingController.shared.stop()
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
    
    @objc func openSettings() {
        print("⚙️ openSettings called")
        
        // 如果窗口已存在，直接显示
        if let window = settingsWindow {
            print("⚙️ Reusing existing window")
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        guard let container = modelContainer else {
            print("❌ ModelContainer is nil!")
            return
        }
        
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
