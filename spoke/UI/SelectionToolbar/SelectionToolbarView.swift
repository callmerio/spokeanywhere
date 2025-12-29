import SwiftUI

private typealias DS = DesignTokens

// MARK: - 工具栏视图

struct SelectionToolbarView: View {
    @EnvironmentObject var state: SelectionToolbarState
    @ObservedObject private var configService = ToolbarConfigService.shared
    @State private var isHovered = false
    
    var body: some View {
        let shadowTight = DS.Shadow.tight()
        let shadowMedium = DS.Shadow.medium()
        let shadowFar = DS.Shadow.far()

        return Group {
            if case .showingDictionary = state.phase {
                dictionaryResultContent
            } else {
                toolbarContent
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .frame(height: DS.Layout.toolbarHeight)
        .background(toolbarBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.CornerRadius.md)
                .strokeBorder(
                    isHovered ? DS.Colors.accentInfo.opacity(0.4) : DS.Colors.separator,
                    lineWidth: isHovered ? 1.5 : DS.BorderWidth.hairline
                )
        )
        // 🔥 Hover 光晕效果
        .shadow(
            color: isHovered ? DS.Colors.accentInfo.opacity(0.45) : Color.clear,
            radius: isHovered ? 10 : 0,
            x: 0,
            y: 0
        )
        .shadow(color: shadowTight.color, radius: shadowTight.radius, x: shadowTight.x, y: shadowTight.y)
        .shadow(color: shadowMedium.color, radius: shadowMedium.radius, x: shadowMedium.x, y: shadowMedium.y)
        .shadow(color: shadowFar.color, radius: shadowFar.radius, x: shadowFar.x, y: shadowFar.y)
        .animation(DS.Animation.fast, value: isHovered)
        .animation(DS.Animation.normal, value: state.phase == .showingDictionary)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    // MARK: - Background
    
    /// 工具栏背景 - 毛玻璃 + 深色叠加（与 LiveCaptionView 一致）
    /// 🔥 使用内部 clipShape 确保 VisualEffectBlur (NSViewRepresentable) 被正确裁剪
    private var toolbarBackground: some View {
        ZStack {
            // 毛玻璃效果
            VisualEffectBlur(material: .hudWindow, cornerRadius: DS.CornerRadius.md)
            // 深色叠加（使用与字幕卡片相同的背景色）
            DS.Colors.captionCardBackground
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.CornerRadius.md))
    }
    
    // MARK: - 工具栏内容
    
    private var toolbarContent: some View {
        HStack(spacing: DS.Spacing.xxs) {
            ToolbarLogoMenu {
                executeAction($0)
            }
            
            ToolbarDivider()
            
            HStack(spacing: DS.Spacing.xxs) {
                ForEach(Array(configService.visibleActions.enumerated()), id: \.element.id) { _, action in
                    ToolbarActionButton(action: action) {
                        executeAction(action)
                    }
                }
            }
        }
    }
    
    // MARK: - 词典结果内容
    
    private var dictionaryResultContent: some View {
        HStack(spacing: DS.Spacing.md) {
            if let data = state.dictionaryResult {
                // 每个释义带词性拼接（格式：a. 与言语相关的；n. 发音）
                let combined = data.senses.prefix(3).compactMap { sense -> String? in
                    guard let chinese = sense.chinese else { return nil }
                    let pos = sense.posDisplay
                    return pos.isEmpty ? chinese : "\(pos) \(chinese)"
                }.joined(separator: "；")
                
                Text(combined)
                    .font(DS.Typography.content)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)
            } else if let error = state.dictionaryError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DS.Colors.warning)
                Text(error.localizedDescription)
                    .font(DS.Typography.button)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            
            Spacer()
            
            // 爱心收藏按钮（仅在成功查词时显示）
            if state.dictionaryResult != nil {
                Button {
                    state.toggleVocabulary()
                } label: {
                    Image(systemName: state.isWordInVocabulary ? "heart.fill" : "heart")
                        .font(DS.Typography.content)
                        .foregroundStyle(state.isWordInVocabulary ? DS.Colors.error : DS.Colors.textPlaceholder)
                }
                .buttonStyle(.plain)
                .padding(DS.Spacing.xs)
                .animation(DS.Animation.fast, value: state.isWordInVocabulary)
            }
        }
    }
    
    private func executeAction(_ action: ToolbarAction) {
        state.executeToolbarAction(action)
    }
}

// MARK: - 分隔线

private struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(DS.Colors.separator)
            .frame(width: DS.BorderWidth.thin, height: DS.Layout.toolbarSeparatorHeight)
            .padding(.horizontal, DS.Spacing.xs)
    }
}

// MARK: - Logo 菜单（左侧触发下拉菜单）
// 使用 Button + NSMenu 替代 SwiftUI Menu，解决 onHover 不可靠问题

private struct ToolbarLogoMenu: View {
    let onAction: (ToolbarAction) -> Void
    
    @ObservedObject private var configService = ToolbarConfigService.shared
    @State private var isHovered = false
    
    var body: some View {
        Button {
            showMenu()
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: DS.Layout.iconSizeToolbar, weight: .semibold))
                    .foregroundStyle(DS.Gradients.toolbarLogo)
                    .shadow(
                        color: DS.Colors.accentGlow.opacity(0.5),
                        radius: DS.Spacing.xxs,
                        x: 0,
                        y: 0
                    )
                
                Image(systemName: "chevron.down")
                    .font(.system(size: DS.Typography.fontSizeCaptionSmall, weight: .semibold))
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .frame(height: DS.Layout.toolbarButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: DS.CornerRadius.sm)
                    .fill(isHovered ? DS.Colors.buttonHover : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DS.Animation.fast) {
                isHovered = hovering
            }
        }
    }
    
    private func showMenu() {
        let menu = NSMenu()
        
        // 溢出的动作
        for action in configService.menuActions {
            let item = NSMenuItem(title: action.name, action: #selector(ToolbarMenuActionHandler.handleMenuAction(_:)), keyEquivalent: "")
            item.image = NSImage(systemSymbolName: action.icon, accessibilityDescription: nil)
            item.target = ToolbarMenuActionHandler.shared
            item.representedObject = action
            menu.addItem(item)
        }
        
        if !configService.menuActions.isEmpty {
            menu.addItem(.separator())
        }
        
        // 发现更多技能
        let discoverItem = NSMenuItem(title: "发现更多技能", action: #selector(ToolbarMenuActionHandler.shared.discoverMoreSkills), keyEquivalent: "")
        discoverItem.image = NSImage(systemSymbolName: "plus.magnifyingglass", accessibilityDescription: nil)
        discoverItem.target = ToolbarMenuActionHandler.shared
        menu.addItem(discoverItem)
        
        // 自定义设置
        let settingsItem = NSMenuItem(title: "自定义设置", action: #selector(ToolbarMenuActionHandler.shared.openSettings), keyEquivalent: "")
        settingsItem.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: nil)
        settingsItem.target = ToolbarMenuActionHandler.shared
        menu.addItem(settingsItem)
        
        menu.addItem(.separator())
        
        // 禁用
        let disableItem = NSMenuItem(title: "禁用", action: #selector(ToolbarMenuActionHandler.shared.disableToolbar), keyEquivalent: "")
        disableItem.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: nil)
        disableItem.target = ToolbarMenuActionHandler.shared
        menu.addItem(disableItem)
        
        // 显示菜单 - 紧贴工具栏下方
        // 获取工具栏窗口位置，计算菜单显示的屏幕坐标
        if let window = SelectionToolbarManager.shared.toolbarWindow {
            let windowFrame = window.frame
            // 菜单显示在窗口左下角下方 (AppKit 坐标系 y 向上)
            let screenPoint = NSPoint(
                x: windowFrame.origin.x + 8,
                y: windowFrame.origin.y - 4  // 窗口底部再往下 4pt
            )
            // 使用 popUp 在屏幕坐标显示，positioning=nil 让菜单从该点向下展开
            menu.popUp(positioning: nil, at: screenPoint, in: nil)
        }
    }
}

// MARK: - Menu Action Handler (NSObject for Objective-C selectors)

@MainActor
@objc private class ToolbarMenuActionHandler: NSObject {
    static let shared = ToolbarMenuActionHandler()
    var onAction: ((ToolbarAction) -> Void)?
    
    @objc func handleMenuAction(_ sender: NSMenuItem) {
        if let action = sender.representedObject as? ToolbarAction {
            onAction?(action)
        }
    }
    
    @objc func openSettings() {
        SelectionToolbarManager.shared.hide()
        NotificationCenter.default.post(name: .openToolbarSettings, object: nil)
    }
    
    @objc func discoverMoreSkills() {
        SelectionToolbarManager.shared.hide()
        NotificationCenter.default.post(name: .openToolbarSettings, object: nil, userInfo: ["focusAddSkill": true])
    }
    
    @objc func disableToolbar() {
        SelectionToolbarManager.shared.hide()
        ToolbarConfigService.shared.isEnabled = false
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let openToolbarSettings = Notification.Name("openToolbarSettings")
}

// MARK: - 新工具栏按钮 (使用 ToolbarAction)

struct ToolbarActionButton: View {
    let action: ToolbarAction
    let onTap: () -> Void
    
    @EnvironmentObject var state: SelectionToolbarState
    @State private var isHovered = false
    @State private var isPressed = false
    
    private var isExecuting: Bool {
        state.executingActionId == action.id
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.md) {
                if isExecuting {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: DS.Layout.iconSizeToolbar, height: DS.Layout.iconSizeToolbar)
                } else {
                    Image(systemName: action.icon)
                        .font(.system(size: DS.Layout.iconSizeToolbar))
                        .foregroundStyle(DS.Colors.icon)
                }
                
                // 始终显示文字
                Text(action.name)
                    .font(.system(size: DS.Typography.fontSizeButton, weight: .medium, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .fixedSize()
            }
            .padding(.horizontal, DS.Spacing.xs)
            .frame(height: DS.Layout.toolbarButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: DS.CornerRadius.sm)
                    .fill(isPressed ? DS.Colors.buttonActive : (isHovered ? DS.Colors.buttonHover : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DS.Animation.fast) {
                isHovered = hovering
            }
            if hovering {
                SelectionToolbarManager.shared.resetAutoHideTimer()
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .disabled(isExecuting)
        .help(action.name)
    }
}

// MARK: - 旧工具栏按钮 (兼容，后续移除)

@available(*, deprecated, message: "Use ToolbarActionButton instead")
struct ToolbarButton: View {
    let action: SelectionToolbarActionType
    let onTap: () -> Void
    
    var body: some View {
        EmptyView()
    }
}

// MARK: - 执行状态指示器

struct ActionExecutingOverlay: View {
    let action: SelectionToolbarActionType
    @EnvironmentObject var state: SelectionToolbarState
    
    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("正在\(action.displayName)...")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textSecondary)
        }
        .padding(.horizontal, DS.Spacing.xxl)
        .padding(.vertical, DS.Spacing.xxl)
        .background(
            RoundedRectangle(cornerRadius: DS.CornerRadius.md)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.CornerRadius.md)
                        .fill(DS.Colors.toolbarBackground)
                )
        )
    }
}

// MARK: - 错误提示

struct ToolbarErrorView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DS.Colors.warning)
            
            Text(message)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textPrimary)
                .lineLimit(2)
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.CornerRadius.md)
                .fill(DS.Colors.error.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.CornerRadius.md)
                        .stroke(DS.Colors.error.opacity(0.3), lineWidth: DS.BorderWidth.thin)
                )
        )
    }
}

// MARK: - Preview

#Preview {
    SelectionToolbarView()
        .environmentObject(SelectionToolbarState.shared)
        .frame(width: 400, height: 80)
        .padding()
        .background(DS.Colors.settingsBackground)
}
