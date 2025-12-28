import AppKit
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.spokeanywhere", category: "DictionaryPanelWindow")

// MARK: - Dictionary Panel Window

/// 查词面板窗口 - 支持输入法
/// 使用 .titled + .fullSizeContentView 欺骗系统获得完整输入法支持
final class DictionaryPanelWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        configure()
    }
    
    private func configure() {
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        animationBehavior = .utilityWindow
        isMovableByWindowBackground = true
        hasShadow = true
        hidesOnDeactivate = false  // 不自动隐藏，由快捷键/ESC 控制
    }
    
    override func cancelOperation(_ sender: Any?) {
        // ESC: 详情页返回列表，列表页关闭面板
        if case .detail = DictionaryPanelState.current?.viewMode {
            DictionaryPanelState.current?.backToList()
        } else {
            DictionaryPanelManager.shared.hide()
        }
    }
    
    override func keyDown(with event: NSEvent) {
        guard let state = DictionaryPanelState.current else {
            super.keyDown(with: event)
            return
        }
        
        // 详情页键盘处理
        if case .detail = state.viewMode {
            switch event.keyCode {
            case 48: // Tab - 切换生词
                state.toggleVocabulary()
                return
            case 125: // 下箭头 - 向下滚动
                scrollDetailView(by: 40)
                return
            case 126: // 上箭头 - 向上滚动
                scrollDetailView(by: -40)
                return
            default:
                break
            }
        }
        
        super.keyDown(with: event)
    }
    
    private func scrollDetailView(by delta: CGFloat) {
        guard let contentView = contentView else { return }
        
        // 递归查找 NSScrollView
        func findScrollView(in view: NSView) -> NSScrollView? {
            if let scrollView = view as? NSScrollView {
                return scrollView
            }
            for subview in view.subviews {
                if let found = findScrollView(in: subview) {
                    return found
                }
            }
            return nil
        }
        
        if let scrollView = findScrollView(in: contentView) {
            let clipView = scrollView.contentView
            var newOrigin = clipView.bounds.origin
            newOrigin.y += delta
            
            // 限制滚动范围
            guard let documentView = scrollView.documentView else { return }
            let maxY = max(0, documentView.frame.height - clipView.bounds.height)
            newOrigin.y = max(0, min(newOrigin.y, maxY))
            
            clipView.setBoundsOrigin(newOrigin)
        }
    }
}

// MARK: - Dictionary Panel Window Manager

@MainActor
final class DictionaryPanelManager {
    
    // MARK: - Singleton
    
    static let shared = DictionaryPanelManager()
    
    // MARK: - Properties
    
    private var window: DictionaryPanelWindow?
    private let state = DictionaryPanelState()
    private var clickOutsideMonitor: Any?
    
    var isVisible: Bool {
        window?.isVisible ?? false
    }
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Public API
    
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
    
    func show() {
        if window == nil {
            createWindow()
        }
        
        guard let window = window else { return }
        
        state.reset()
        DictionaryPanelState.current = state
        
        // 每次显示时重新设置 rootView，确保 SwiftUI 正确追踪 @Observable 状态
        let contentView = DictionaryPanelView(state: state) { [weak self] in
            self?.hide()
        }
        (window.contentView as? NSHostingView<DictionaryPanelView>)?.rootView = contentView
        
        positionWindow(window)
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        setupClickOutsideMonitor()
        
        logger.info("📖 [DictionaryPanel] 显示面板")
    }
    
    func hide() {
        removeClickOutsideMonitor()
        window?.orderOut(nil)
        logger.info("📖 [DictionaryPanel] 隐藏面板")
    }
    
    // MARK: - Click Outside Monitor
    
    private func setupClickOutsideMonitor() {
        removeClickOutsideMonitor()
        
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self,
                  let window = self.window,
                  window.isVisible else {
                return
            }
            
            let windowFrame = window.frame
            let screenLocation = NSEvent.mouseLocation
            
            if !windowFrame.contains(screenLocation) {
                Task { @MainActor in
                    self.hide()
                }
            }
        }
    }
    
    private func removeClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
    }
    
    // MARK: - Private
    
    private func createWindow() {
        let window = DictionaryPanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 420)
        )
        
        let contentView = DictionaryPanelView(state: state) { [weak self] in
            self?.hide()
        }
        
        window.contentView = NSHostingView(rootView: contentView)
        self.window = window
        
        logger.info("📖 [DictionaryPanel] 创建窗口")
    }
    
    private func positionWindow(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let windowSize = window.frame.size
        
        let x = screenFrame.midX - windowSize.width / 2
        let y = screenFrame.midY + screenFrame.height * 0.12
        
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

// MARK: - Shortcut Registration

extension DictionaryPanelManager {
    
    func registerShortcut() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.option) && event.keyCode == 49 {
                Task { @MainActor in
                    self?.toggle()
                }
            }
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.option) && event.keyCode == 49 {
                Task { @MainActor in
                    self?.toggle()
                }
                return nil
            }
            return event
        }
        
        logger.info("📖 [DictionaryPanel] 注册快捷键: ⌥+Space")
    }
}
