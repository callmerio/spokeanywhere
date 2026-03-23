import AppKit
import OSLog
import SwiftUI

// MARK: - Live Caption Window Manager

@MainActor
struct LiveCaptionWindowManagerDependencies {
    let manager: LiveCaptionManager
    let translator: TranslationService
    let viewDependencies: LiveCaptionViewDependencies
}

@MainActor
extension LiveCaptionWindowManagerDependencies {
    static let live = LiveCaptionWindowManagerDependencies(
        manager: .shared,
        translator: .shared,
        viewDependencies: .live(
            lookupWord: { word in
                await UnifiedDictionaryService.shared.lookup(word)
            },
            markVocabulary: { text in
                VocabularyService.shared.markVocabulary(in: text)
            },
            selectionToolbarState: .shared,
            selectionToolbarManager: .shared
        )
    )
}

/// 实时字幕窗口管理器
@MainActor
final class LiveCaptionWindowManager {
    
    // MARK: - Singleton
    
    static let shared = LiveCaptionWindowManager(dependencies: .live)
    
    // MARK: - Properties
    
    private let dependencies: LiveCaptionWindowManagerDependencies
    private var window: LiveCaptionPanel?
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "LiveCaptionWindow")
    private let manager: LiveCaptionManager
    
    /// 窗口是否可见
    var isVisible: Bool { window?.isVisible ?? false }
    
    // MARK: - Init
    
    private init(
        dependencies: LiveCaptionWindowManagerDependencies
    ) {
        self.dependencies = dependencies
        self.manager = dependencies.manager
    }
    
    // MARK: - Public API
    
    /// 显示字幕窗口
    func show() {
        createWindowIfNeeded()
        
        window?.orderFront(nil)
        
        // 启动字幕
        runLiveCaptionWindowAsync(self) { windowManager in
            try? await windowManager.manager.start()
        }
        
        logger.info("🎬 Live Caption window shown")
    }
    
    /// 隐藏字幕窗口
    func hide() {
        window?.orderOut(nil)
        
        // 停止字幕
        runLiveCaptionWindowAsync(self) { windowManager in
            await windowManager.manager.stop()
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
        
        postLiveCaptionWindowToggle()
    }
    
    // MARK: - Private
    
    private func createWindowIfNeeded() {
        guard window == nil else { return }

        // 获取屏幕信息
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            logger.error("No screen available for Live Caption window")
            return
        }
        let screenFrame = screen.visibleFrame

        // 计算初始位置（屏幕底部居中）
        // 窗口尺寸参考 Tailwind max-w-2xl ≈ 672px + 阴影/光晕留白
        let outerPadding = CaptionDesign.shadowPadding * 2  // 两侧各留白
        let windowWidth: CGFloat = CaptionDesign.maxWidth + outerPadding
        // 折叠状态高度：2行字(44pt) + padding(48pt) + dragIndicator(12pt) ≈ 110pt
        // 使用较大值确保内容不被裁剪，加上光晕空间
        let windowHeight: CGFloat = 400 + outerPadding
        let x = screenFrame.midX - windowWidth / 2
        let y = screenFrame.minY + 60 - CaptionDesign.shadowPadding  // 调整位置，保持视觉居中
        
        let frame = NSRect(x: x, y: y, width: windowWidth, height: windowHeight)
        
        // 创建窗口
        let panel = LiveCaptionPanel(contentRect: frame)
        panel.identifier = NSUserInterfaceItemIdentifier(UITestIdentifiers.Window.liveCaption)
        panel.setAccessibilityIdentifier(UITestIdentifiers.Window.liveCaption)
        
        // 设置内容
        let contentView = LiveCaptionView(
            manager: manager,
            onClose: { [weak self] in
                self?.hide()
            },
            translator: dependencies.translator,
            dependencies: dependencies.viewDependencies
        )
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.identifier = NSUserInterfaceItemIdentifier(UITestIdentifiers.Element.liveCaptionRoot)
        hostingView.setAccessibilityIdentifier(UITestIdentifiers.Element.liveCaptionRoot)
        // 确保 NSHostingView 完全透明（避免 padding 区域出现灰色）
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        // 🔧 关键：设置 layer 为非不透明，允许透明渲染
        hostingView.layer?.isOpaque = false
        // 设置视图本身也为非不透明
        hostingView.layerContentsRedrawPolicy = NSView.LayerContentsRedrawPolicy.onSetNeedsDisplay
        panel.contentView = hostingView
        
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

        // 禁用系统阴影（矩形边框很丑），使用 SwiftUI 自定义圆角阴影
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
