import AppKit
import OSLog
import SwiftUI

// MARK: - Live Caption Window Manager

/// 实时字幕窗口管理器
@MainActor
final class LiveCaptionWindowManager {
    
    // MARK: - Singleton
    
    static let shared = LiveCaptionWindowManager()
    
    // MARK: - Properties
    
    private var window: LiveCaptionPanel?
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "LiveCaptionWindow")
    private let manager = LiveCaptionManager.shared
    
    /// 窗口是否可见
    var isVisible: Bool { window?.isVisible ?? false }
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Public API
    
    /// 显示字幕窗口
    func show() {
        createWindowIfNeeded()
        
        window?.orderFront(nil)
        
        // 启动字幕
        Task {
            try? await manager.start()
        }
        
        logger.info("🎬 Live Caption window shown")
    }
    
    /// 隐藏字幕窗口
    func hide() {
        window?.orderOut(nil)
        
        // 停止字幕
        Task {
            await manager.stop()
        }
        
        logger.info("🛑 Live Caption window hidden")
    }
    
    /// 切换显示/隐藏
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
        
        NotificationCenter.default.post(name: .liveCaptionDidToggle, object: nil)
    }
    
    // MARK: - Private
    
    private func createWindowIfNeeded() {
        guard window == nil else { return }
        
        // 获取屏幕信息
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.visibleFrame
        
        // 计算初始位置（屏幕底部居中）
        // 窗口尺寸参考 Tailwind max-w-2xl ≈ 672px
        let windowWidth: CGFloat = 672
        // 折叠状态高度：2行字(44pt) + padding(48pt) + dragIndicator(12pt) ≈ 110pt
        // 使用较大值确保内容不被裁剪
        let windowHeight: CGFloat = 400  // 使用较大高度，让 SwiftUI 视图自适应
        let x = screenFrame.midX - windowWidth / 2
        let y = screenFrame.minY + 60  // 距离底部 60pt
        
        let frame = NSRect(x: x, y: y, width: windowWidth, height: windowHeight)
        
        // 创建窗口
        let panel = LiveCaptionPanel(contentRect: frame)
        
        // 设置内容
        let contentView = LiveCaptionView(
            manager: manager,
            onClose: { [weak self] in
                self?.hide()
            }
        )
        panel.contentView = NSHostingView(rootView: contentView)
        
        self.window = panel
        logger.info("📺 Live Caption window created")
    }
}

// MARK: - Live Caption Panel

/// 实时字幕悬浮窗口
final class LiveCaptionPanel: NSPanel {
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        configure()
    }
    
    private func configure() {
        // 窗口层级
        level = .floating
        
        // 透明背景
        isOpaque = false
        backgroundColor = .clear
        
        // 标题栏
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        
        // 可拖动
        isMovableByWindowBackground = true
        
        // 跨空间显示
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        
        // 动画
        animationBehavior = .utilityWindow
        
        // 阴影由视图处理
        hasShadow = false
    }
}

// MARK: - Availability

@MainActor
enum LiveCaptionAvailability {
    
    /// 系统音频捕获可用性
    static var isAudioCaptureAvailable: Bool {
        SystemAudioCaptureAvailability.isSupported
    }
    
    /// 翻译功能可用性
    static var isTranslationAvailable: Bool {
        TranslationService.shared.isAvailable
    }
    
    /// 完整功能可用性描述
    static var statusDescription: String {
        if !isAudioCaptureAvailable {
            return "需要 macOS 12.3+ 才能捕获系统音频"
        }
        if !isTranslationAvailable {
            return "翻译功能需要 macOS 14.4+，当前仅显示原文"
        }
        return "实时字幕功能可用"
    }
}
