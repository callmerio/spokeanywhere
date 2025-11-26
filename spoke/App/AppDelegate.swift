import AppKit
import SwiftUI
import SwiftData

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var modelContainer: ModelContainer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 确保应用可以显示窗口（非 accessory 模式）
        NSApp.setActivationPolicy(.regular)
        
        // 初始化 SwiftData 容器
        do {
            modelContainer = try ModelContainer(for: HistoryItem.self, AppRule.self, AIProviderConfig.self)
            print("✅ ModelContainer initialized")
        } catch {
            print("❌ Failed to create ModelContainer: \(error)")
        }
        print("🚀 SpokenAnyWhere started")
        
        // 检查辅助功能权限
        checkAccessibilityPermission()
        
        // 设置菜单栏图标
        setupMenuBar()
        
        // 启动录音控制器
        RecordingController.shared.start()
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
        
        let hotkeyItem = NSMenuItem(title: "快捷键: ⌥ + R", action: nil, keyEquivalent: "")
        hotkeyItem.isEnabled = false
        menu.addItem(hotkeyItem)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc private func openSettings() {
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
