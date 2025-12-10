import SwiftUI

// MARK: - 配色

private enum ToolbarColors {
    static let background = Color(hex: "1F1F1F")
    static let border = Color.white.opacity(0.1)
    static let buttonHover = Color.white.opacity(0.1)
    static let buttonActive = Color.white.opacity(0.2)
    static let separator = Color.white.opacity(0.15)
    static let text = Color.white.opacity(0.95)
    static let textSecondary = Color.white.opacity(0.6)
    static let icon = Color.white.opacity(0.85)
}

private enum ToolbarLayout {
    static let height: CGFloat = 40
    static let buttonHeight: CGFloat = 32
    static let buttonPaddingH: CGFloat = 3
    static let logoButtonPaddingH: CGFloat = 10
    static let buttonCornerRadius: CGFloat = 6
    static let cornerRadius: CGFloat = 10  // 更小的圆角，更精致
    static let iconSize: CGFloat = 15
    static let fontSize: CGFloat = 13
    static let spacing: CGFloat = 2
    static let separatorWidth: CGFloat = 1
    static let separatorHeight: CGFloat = 20
}

// MARK: - 工具栏视图

struct SelectionToolbarView: View {
    @EnvironmentObject var state: SelectionToolbarState
    @ObservedObject private var configService = ToolbarConfigService.shared
    
    var body: some View {
        HStack(spacing: ToolbarLayout.spacing) {
            // 1. 左侧 Logo 菜单（点击触发下拉菜单）
            ToolbarLogoMenu {
                executeAction($0)
            }
            
            // Logo 分隔线
            ToolbarDivider()
            
            // 2. 动作按钮列表
            HStack(spacing: 2) {
                ForEach(Array(configService.visibleActions.enumerated()), id: \.element.id) { index, action in
                    ToolbarActionButton(action: action) {
                        executeAction(action)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: ToolbarLayout.height)
        .background(
            RoundedRectangle(cornerRadius: ToolbarLayout.cornerRadius)
                .fill(Color.black.opacity(0.3))  // 深色底色增加对比度
        )
        .background(
            RoundedRectangle(cornerRadius: ToolbarLayout.cornerRadius)
                .fill(.ultraThinMaterial)  // 更浓的毛璃璆
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ToolbarLayout.cornerRadius)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        // Apple 风格多层阴影：柔和扩散 + 底部重点
        .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 0.5)  // 紧贴边缘的细微阴影
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)   // 中层柔和阴影
        .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)  // 远层扩散阴影
    }
    
    private func executeAction(_ action: ToolbarAction) {
        state.executeToolbarAction(action)
    }
}

// MARK: - 分隔线

private struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(ToolbarColors.separator)
            .frame(width: ToolbarLayout.separatorWidth, height: ToolbarLayout.separatorHeight)
            .padding(.horizontal, 4)
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
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.6, green: 0.8, blue: 1.0), Color(red: 1.0, green: 0.6, blue: 1.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(red: 0.7, green: 0.5, blue: 1.0).opacity(0.5), radius: 2, x: 0, y: 0)  // 发光效果
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(ToolbarColors.textSecondary)
            }
            .padding(.horizontal, ToolbarLayout.logoButtonPaddingH)
            .frame(height: ToolbarLayout.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: ToolbarLayout.buttonCornerRadius)
                    .fill(isHovered ? ToolbarColors.buttonHover : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
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
            HStack(spacing: 8) {
                if isExecuting {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: ToolbarLayout.iconSize, height: ToolbarLayout.iconSize)
                } else {
                    Image(systemName: action.icon)
                        .font(.system(size: ToolbarLayout.iconSize))
                        .foregroundColor(ToolbarColors.icon)
                }
                
                // 始终显示文字
                Text(action.name)
                    .font(.system(size: ToolbarLayout.fontSize, weight: .medium, design: .rounded))
                    .foregroundColor(ToolbarColors.text)
                    .fixedSize()
            }
            .padding(.horizontal, ToolbarLayout.buttonPaddingH)
            .frame(height: ToolbarLayout.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: ToolbarLayout.buttonCornerRadius)
                    .fill(isPressed ? ToolbarColors.buttonActive : (isHovered ? ToolbarColors.buttonHover : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
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
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("正在\(action.displayName)...")
                .font(.system(size: 12))
                .foregroundColor(ToolbarColors.textSecondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: ToolbarLayout.cornerRadius)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: ToolbarLayout.cornerRadius)
                        .fill(ToolbarColors.background)
                )
        )
    }
}

// MARK: - 错误提示

struct ToolbarErrorView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(ToolbarColors.text)
                .lineLimit(2)
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(ToolbarColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: ToolbarLayout.cornerRadius)
                .fill(Color.red.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: ToolbarLayout.cornerRadius)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
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
        .background(Color.gray)
}
