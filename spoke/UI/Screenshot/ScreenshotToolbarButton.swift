import AppKit

// MARK: - Screenshot Toolbar Button

/// 工具栏按钮组件
/// 支持 hover 效果、禁用状态、选中状态
final class ScreenshotToolbarButton: NSView {
    
    // MARK: - Properties
    
    private let iconView: NSImageView
    private let backgroundView: NSView
    private var trackingArea: NSTrackingArea?
    
    private let iconName: String
    private var isHovered: Bool = false
    private var isSelected: Bool = false
    private var isEnabled: Bool = true
    
    var action: (() -> Void)?
    
    // MARK: - Constants
    
    private enum Design {
        static let size: CGFloat = 28
        static let iconSize: CGFloat = 14
        static let cornerRadius: CGFloat = 6
        static let animationDuration: TimeInterval = 0.15
    }
    
    // MARK: - Init
    
    init(icon: String, isEnabled: Bool = true) {
        self.iconName = icon
        self.isEnabled = isEnabled
        self.iconView = NSImageView()
        self.backgroundView = NSView()
        
        super.init(frame: NSRect(x: 0, y: 0, width: Design.size, height: Design.size))
        
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setup() {
        wantsLayer = true
        
        // 背景
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = Design.cornerRadius
        backgroundView.layer?.backgroundColor = DesignTokens.Colors.NS.clear.cgColor
        backgroundView.frame = bounds
        backgroundView.autoresizingMask = [.width, .height]
        addSubview(backgroundView)
        
        // 图标
        let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        image?.isTemplate = true
        iconView.image = image
        iconView.imageScaling = .scaleProportionallyDown
        iconView.contentTintColor = isEnabled ? DesignTokens.Colors.NS.textPrimary : DesignTokens.Colors.NS.textPlaceholder
        
        let iconFrame = NSRect(
            x: (Design.size - Design.iconSize) / 2,
            y: (Design.size - Design.iconSize) / 2,
            width: Design.iconSize,
            height: Design.iconSize
        )
        iconView.frame = iconFrame
        addSubview(iconView)
        
        // 约束
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Design.size),
            heightAnchor.constraint(equalToConstant: Design.size)
        ])
    }
    
    // MARK: - Tracking Area
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }
    
    // MARK: - Mouse Events
    
    override func mouseEntered(with event: NSEvent) {
        guard isEnabled else { return }
        isHovered = true
        updateAppearance(animated: true)
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateAppearance(animated: true)
    }
    
    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        
        // 按下效果
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            backgroundView.animator().layer?.backgroundColor = DesignTokens.Colors.NS.buttonPressed.cgColor
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        guard isEnabled else { return }
        
        // 恢复
        updateAppearance(animated: true)
        
        // 检查点击是否在按钮内
        let location = convert(event.locationInWindow, from: nil)
        if bounds.contains(location) {
            action?()
        }
    }
    
    // MARK: - State
    
    func setSelected(_ selected: Bool) {
        isSelected = selected
        updateAppearance(animated: true)
    }
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        iconView.contentTintColor = enabled ? DesignTokens.Colors.NS.textPrimary : DesignTokens.Colors.NS.textPlaceholder
        updateAppearance(animated: false)
    }
    
    // MARK: - Appearance
    
    private func updateAppearance(animated: Bool) {
        let bgColor: CGColor
        
        if isSelected {
            bgColor = DesignTokens.Colors.NS.buttonPressed.cgColor
        } else if isHovered && isEnabled {
            bgColor = DesignTokens.Colors.NS.buttonActive.cgColor
        } else {
            bgColor = DesignTokens.Colors.NS.clear.cgColor
        }
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Design.animationDuration
                backgroundView.animator().layer?.backgroundColor = bgColor
            }
        } else {
            backgroundView.layer?.backgroundColor = bgColor
        }
    }
}
