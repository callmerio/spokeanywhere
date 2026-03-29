import AppKit
import SwiftUI

/// 悬浮面板 - 不抢夺焦点的置顶窗口
/// 用于显示录音状态胶囊
final class FloatingPanel: NSPanel {
    
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        configure()
    }
    
    private func configure() {
        // 窗口层级：悬浮在普通窗口之上
        level = .floating
        
        // 透明背景
        isOpaque = false
        backgroundColor = .clear
        
        // 不在 Dock/Mission Control 显示
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        
        // 动画
        animationBehavior = .utilityWindow
        
        // 圆角
        isMovableByWindowBackground = false
        hasShadow = false // 禁用系统阴影，防止出现方框黑影
    }
    
    /// 定位到屏幕底部中央（固定位置，内容向上扩展）
    func positionAtBottomCenter() {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let panelWidth = frame.width
        
        let x = screenFrame.midX - panelWidth / 2
        // 底部固定，距离底部 80pt
        let y = screenFrame.minY + 80
        
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

// MARK: - Quick Ask Panel

/// Quick Ask 悬浮面板 - 可以接收键盘输入
/// 用于 Quick Ask 输入交互
/// 改为继承 NSWindow 以获得系统级的一等公民待遇，彻底解决输入法问题
final class QuickAskPanel: NSWindow {
    
    // 允许接收键盘输入和成为主窗口
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    init(contentRect: NSRect) {
        // 关键修复：使用 .titled | .fullSizeContentView 来欺骗系统，获得完整的输入法支持
        super.init(
            contentRect: contentRect,
            // .titled + .fullSizeContentView 是让 InputContext 正常工作的关键
            styleMask: [.titled, .fullSizeContentView, .resizable], 
            backing: .buffered,
            defer: false
        )
        
        configure()
    }
    
    private func configure() {
        // 窗口层级：悬浮在普通窗口之上
        level = .floating
        
        // 透明背景
        isOpaque = false
        backgroundColor = .clear
        
        // 关键配置：隐藏标题栏但保留 .titled 属性
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        
        // 禁用系统标准窗口按钮
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        
        // 不在 Dock/Mission Control 显示
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        
        // 动画
        animationBehavior = .utilityWindow
        
        // 允许通过背景拖动
        isMovableByWindowBackground = true
        
        // 禁用阴影
        hasShadow = false
    }
    
    /// 定位到屏幕底部中央
    func positionAtBottomCenter() {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let panelWidth = frame.width
        
        let x = screenFrame.midX - panelWidth / 2
        let y = screenFrame.minY + 80
        
        setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    // 处理 ESC 键
    override func cancelOperation(_ sender: Any?) {
        // 发送取消通知
        postFloatingPanelQuickAskCancel()
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let quickAskCancelRequested = Notification.Name("QuickAskCancelRequested")
}
