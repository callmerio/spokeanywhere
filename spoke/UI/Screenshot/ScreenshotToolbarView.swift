import AppKit

// MARK: - Screenshot Toolbar View

/// 截图选区工具栏
/// 悬浮在选区下方，提供标注工具和确认操作
final class ScreenshotToolbarView: NSView {
    
    // MARK: - Types
    
    enum ToolbarAction: CaseIterable {
        // 标注工具 (Phase 1.1+)
        case arrow, pen, marker, text, eraser
        // 历史 (Phase 1.3)
        case undo, redo
        // 操作
        case cancel, confirm, pin, copy
        
        var icon: String {
            switch self {
            case .arrow: return "arrow.up.right"
            case .pen: return "highlighter"
            case .marker: return "paintbrush"
            case .text: return "textformat"
            case .eraser: return "eraser"
            case .undo: return "arrow.uturn.backward"
            case .redo: return "arrow.uturn.forward"
            case .cancel: return "xmark"
            case .confirm: return "checkmark"
            case .pin: return "pin.fill"
            case .copy: return "doc.on.doc"
            }
        }
        
        var tooltip: String {
            switch self {
            case .arrow: return "箭头 (A)"
            case .pen: return "画笔 (B)"
            case .marker: return "荧光笔 (M)"
            case .text: return "文字 (T)"
            case .eraser: return "橡皮擦 (E)"
            case .undo: return "撤销 (⌘Z)"
            case .redo: return "重做 (⌘⇧Z)"
            case .cancel: return "取消 (ESC)"
            case .confirm: return "确认 (↩)"
            case .pin: return "钉住 (⌘P)"
            case .copy: return "复制 (⌘C)"
            }
        }
        
        /// 是否启用
        var isEnabled: Bool {
            // 所有按钮都启用
            return true
        }
        
        /// 分组信息
        static var annotationTools: [ToolbarAction] { [.arrow, .pen, .marker, .text, .eraser] }
        static var historyActions: [ToolbarAction] { [.undo, .redo] }
        static var confirmActions: [ToolbarAction] { [.cancel, .confirm, .pin, .copy] }
    }
    
    // MARK: - Callbacks
    
    var onAction: ((ToolbarAction) -> Void)?
    
    // MARK: - Properties
    
    private var buttons: [ToolbarAction: ScreenshotToolbarButton] = [:]
    private let stackView: NSStackView
    private let backgroundView: NSVisualEffectView
    
    // MARK: - Constants
    
    private enum Design {
        static let height: CGFloat = 44
        static let horizontalPadding: CGFloat = 12
        static let buttonSpacing: CGFloat = 4
        static let groupSpacing: CGFloat = 12
        static let cornerRadius: CGFloat = 12
    }
    
    // MARK: - Init
    
    override init(frame frameRect: NSRect) {
        stackView = NSStackView()
        backgroundView = NSVisualEffectView()
        
        super.init(frame: frameRect)
        
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setup() {
        wantsLayer = true
        
        // 毛玻璃背景
        backgroundView.material = .hudWindow
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = Design.cornerRadius
        backgroundView.layer?.masksToBounds = true
        addSubview(backgroundView)
        
        // 阴影
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.3
        layer?.shadowRadius = 8
        layer?.shadowOffset = CGSize(width: 0, height: -2)
        
        // 按钮容器
        stackView.orientation = .horizontal
        stackView.spacing = Design.buttonSpacing
        stackView.alignment = .centerY
        stackView.distribution = .fill
        addSubview(stackView)
        
        // 创建按钮组
        createButtonGroups()
        
        // 布局
        setupConstraints()
    }
    
    private func createButtonGroups() {
        // 标注工具组
        for action in ToolbarAction.annotationTools {
            let button = createButton(for: action)
            stackView.addArrangedSubview(button)
        }
        
        // 分隔线 1
        stackView.addArrangedSubview(createSeparator())
        
        // 历史组
        for action in ToolbarAction.historyActions {
            let button = createButton(for: action)
            stackView.addArrangedSubview(button)
        }
        
        // 分隔线 2
        stackView.addArrangedSubview(createSeparator())
        
        // 确认操作组
        for action in ToolbarAction.confirmActions {
            let button = createButton(for: action)
            stackView.addArrangedSubview(button)
        }
    }
    
    private func createButton(for action: ToolbarAction) -> ScreenshotToolbarButton {
        let button = ScreenshotToolbarButton(icon: action.icon, isEnabled: action.isEnabled)
        button.toolTip = action.tooltip
        button.action = { [weak self] in
            self?.onAction?(action)
        }
        buttons[action] = button
        return button
    }
    
    private func createSeparator() -> NSView {
        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.3).cgColor
        
        separator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            separator.widthAnchor.constraint(equalToConstant: 1),
            separator.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        return separator
    }
    
    private func setupConstraints() {
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 背景填满
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            // 按钮容器居中
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.horizontalPadding),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.horizontalPadding),
            
            // 固定高度
            heightAnchor.constraint(equalToConstant: Design.height)
        ])
    }
    
    // MARK: - Layout
    
    override var intrinsicContentSize: NSSize {
        let width = stackView.fittingSize.width + Design.horizontalPadding * 2
        return NSSize(width: width, height: Design.height)
    }
    
    // MARK: - Public API
    
    /// 设置按钮选中状态（用于标注工具切换）
    func setSelected(_ action: ToolbarAction, selected: Bool) {
        // 如果选中一个工具，取消其他工具的选中状态
        if selected {
            for tool in ToolbarAction.annotationTools where tool != action {
                buttons[tool]?.setSelected(false)
            }
        }
        buttons[action]?.setSelected(selected)
    }
    
    /// 取消所有标注工具的选中状态
    func deselectAllTools() {
        for tool in ToolbarAction.annotationTools {
            buttons[tool]?.setSelected(false)
        }
    }
    
    /// 设置按钮启用状态
    func setEnabled(_ action: ToolbarAction, enabled: Bool) {
        buttons[action]?.setEnabled(enabled)
    }
    
    /// 更新撤销/重做按钮状态
    func updateHistoryButtons(canUndo: Bool, canRedo: Bool) {
        buttons[.undo]?.setEnabled(canUndo)
        buttons[.redo]?.setEnabled(canRedo)
    }
}
