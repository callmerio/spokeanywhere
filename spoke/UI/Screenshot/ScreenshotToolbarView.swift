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
    var onTextFontStep: ((CGFloat) -> Void)?
    var onTextColorSelected: ((NSColor) -> Void)?
    
    // MARK: - Properties
    
    private var buttons: [ToolbarAction: ScreenshotToolbarButton] = [:]
    private let stackView: NSStackView
    private let backgroundView: NSVisualEffectView
    private let textControlsStackView = NSStackView()
    private let textFontValueLabel = NSTextField(labelWithString: "16")
    private var textColorButtons: [NSButton] = []
    private var textColorMap: [ObjectIdentifier: NSColor] = [:]

    var isTextControlsVisible: Bool { !textControlsStackView.isHidden }
    var displayedTextFontSize: String { textFontValueLabel.stringValue }
    
    // MARK: - Constants
    
    private enum Design {
        static let height: CGFloat = 44
        static let horizontalPadding: CGFloat = 12
        static let buttonSpacing: CGFloat = 4
        static let groupSpacing: CGFloat = 12
        static let cornerRadius: CGFloat = 12
        static let textControlSpacing: CGFloat = 6
        static let fontButtonWidth: CGFloat = 28
        static let fontLabelWidth: CGFloat = 28
        static let colorSwatchSize: CGFloat = 14
        static let fontStepAmount: CGFloat = 1
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
        layer?.shadowColor = DesignTokens.Colors.NS.inkDark.cgColor
        layer?.shadowOpacity = 0.3
        layer?.shadowRadius = 8
        layer?.shadowOffset = CGSize(width: 0, height: -2)
        
        // 按钮容器
        stackView.orientation = .horizontal
        stackView.spacing = Design.buttonSpacing
        stackView.alignment = .centerY
        stackView.distribution = .fill
        addSubview(stackView)

        textControlsStackView.orientation = .horizontal
        textControlsStackView.alignment = .centerY
        textControlsStackView.spacing = Design.textControlSpacing
        textControlsStackView.isHidden = true

        textFontValueLabel.textColor = DesignTokens.Colors.NS.textPrimary
        textFontValueLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        textFontValueLabel.alignment = .center
        textFontValueLabel.translatesAutoresizingMaskIntoConstraints = false
        textFontValueLabel.widthAnchor.constraint(equalToConstant: Design.fontLabelWidth).isActive = true
        
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
            if action == .text {
                stackView.addArrangedSubview(textControlsStackView)
            }
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
        separator.layer?.backgroundColor = DesignTokens.Colors.NS.separatorStrong.cgColor
        
        separator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            separator.widthAnchor.constraint(equalToConstant: 1),
            separator.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        return separator
    }

    private func configureTextControlsIfNeeded() {
        guard textControlsStackView.arrangedSubviews.isEmpty else { return }

        textControlsStackView.addArrangedSubview(makeFontStepButton(title: "A-", delta: -Design.fontStepAmount))
        textControlsStackView.addArrangedSubview(textFontValueLabel)
        textControlsStackView.addArrangedSubview(makeFontStepButton(title: "A+", delta: Design.fontStepAmount))
        textControlsStackView.addArrangedSubview(createSeparator())

        let colors: [NSColor] = [
            DesignTokens.Colors.NS.annotationText,
            .systemYellow,
            .systemRed,
            .systemGreen,
            .systemBlue
        ]

        for color in colors {
            let swatch = makeColorSwatch(color: color)
            textControlsStackView.addArrangedSubview(swatch)
            textColorButtons.append(swatch)
            textColorMap[ObjectIdentifier(swatch)] = color
        }
    }

    private func makeFontStepButton(title: String, delta: CGFloat) -> NSButton {
        let button = NSButton(title: title, target: self, action: #selector(handleTextFontStep(_:)))
        button.bezelStyle = .texturedRounded
        button.isBordered = true
        button.font = .systemFont(ofSize: 11, weight: .semibold)
        button.contentTintColor = DesignTokens.Colors.NS.textPrimary
        button.identifier = NSUserInterfaceItemIdentifier("\(delta)")
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: Design.fontButtonWidth),
            button.heightAnchor.constraint(equalToConstant: 24)
        ])
        return button
    }

    private func makeColorSwatch(color: NSColor) -> NSButton {
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: Design.colorSwatchSize, height: Design.colorSwatchSize))
        button.isBordered = false
        button.bezelStyle = .shadowlessSquare
        button.title = ""
        button.target = self
        button.action = #selector(handleTextColorTap(_:))
        button.wantsLayer = true
        button.layer?.cornerRadius = Design.colorSwatchSize / 2
        button.layer?.backgroundColor = color.cgColor
        button.layer?.borderColor = DesignTokens.Colors.NS.clear.cgColor
        button.layer?.borderWidth = 1
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: Design.colorSwatchSize),
            button.heightAnchor.constraint(equalToConstant: Design.colorSwatchSize)
        ])
        return button
    }

    @objc
    private func handleTextFontStep(_ sender: NSButton) {
        guard let rawValue = sender.identifier?.rawValue,
              let delta = Double(rawValue) else { return }
        onTextFontStep?(CGFloat(delta))
    }

    @objc
    private func handleTextColorTap(_ sender: NSButton) {
        guard let color = textColorMap[ObjectIdentifier(sender)] else { return }
        onTextColorSelected?(color)
    }

    private func updateSelectedTextColor(_ color: NSColor) {
        for button in textColorButtons {
            let isSelected = textColorMap[ObjectIdentifier(button)] == color
            button.layer?.borderWidth = isSelected ? 2 : 1
            button.layer?.borderColor = isSelected
                ? DesignTokens.Colors.NS.inkLight.cgColor
                : DesignTokens.Colors.NS.clear.cgColor
        }
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

    func setTextControlsVisible(_ visible: Bool) {
        configureTextControlsIfNeeded()
        textControlsStackView.isHidden = !visible
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    func applyTextStyle(_ style: TextAnnotationStyle, hasSelectedText: Bool) {
        configureTextControlsIfNeeded()
        textFontValueLabel.stringValue = String(Int(style.fontSize.rounded()))
        textFontValueLabel.textColor = hasSelectedText
            ? DesignTokens.Colors.NS.inkLight
            : DesignTokens.Colors.NS.textPrimary
        updateSelectedTextColor(style.color)
        invalidateIntrinsicContentSize()
    }
    
    /// 更新撤销/重做按钮状态
    func updateHistoryButtons(canUndo: Bool, canRedo: Bool) {
        buttons[.undo]?.setEnabled(canUndo)
        buttons[.redo]?.setEnabled(canRedo)
    }
}
