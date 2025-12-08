import SwiftUI

// MARK: - 配色

private enum ToolbarColors {
    static let background = Color.black.opacity(0.75)
    static let buttonHover = Color.white.opacity(0.15)
    static let buttonActive = Color.white.opacity(0.25)
    static let separator = Color.white.opacity(0.2)
    static let text = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let icon = Color.white.opacity(0.9)
}

private enum ToolbarLayout {
    static let height: CGFloat = 36
    static let buttonPaddingH: CGFloat = 12
    static let buttonPaddingV: CGFloat = 6
    static let cornerRadius: CGFloat = 8
    static let iconSize: CGFloat = 14
    static let spacing: CGFloat = 2
    static let separatorWidth: CGFloat = 1
    static let separatorHeight: CGFloat = 20
}

// MARK: - 工具栏视图

struct SelectionToolbarView: View {
    @EnvironmentObject var state: SelectionToolbarState
    
    var body: some View {
        HStack(spacing: ToolbarLayout.spacing) {
            ForEach(Array(state.config.enabledActions.enumerated()), id: \.element) { index, action in
                if index > 0 {
                    Divider()
                        .frame(width: ToolbarLayout.separatorWidth, height: ToolbarLayout.separatorHeight)
                        .background(ToolbarColors.separator)
                }
                
                ToolbarButton(action: action) {
                    state.executeAction(action)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: ToolbarLayout.cornerRadius)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: ToolbarLayout.cornerRadius)
                        .fill(ToolbarColors.background)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: ToolbarLayout.cornerRadius))
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
    }
}

// MARK: - 工具栏按钮

struct ToolbarButton: View {
    let action: SelectionToolbarActionType
    let onTap: () -> Void
    
    @EnvironmentObject var state: SelectionToolbarState
    @State private var isHovered = false
    @State private var isPressed = false
    
    /// 是否正在执行此动作
    private var isExecuting: Bool {
        if case .executing(let executingAction) = state.phase {
            return executingAction == action
        }
        return false
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if isExecuting {
                    // 执行中显示加载动画
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: ToolbarLayout.iconSize, height: ToolbarLayout.iconSize)
                } else {
                    Image(systemName: action.iconName)
                        .font(.system(size: ToolbarLayout.iconSize, weight: .medium))
                        .foregroundColor(isHovered ? action.iconColor : ToolbarColors.icon)
                }
                
                if state.config.showButtonText {
                    Text(action.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ToolbarColors.text)
                }
            }
            .padding(.horizontal, ToolbarLayout.buttonPaddingH)
            .padding(.vertical, ToolbarLayout.buttonPaddingV)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isPressed ? ToolbarColors.buttonActive : (isHovered ? ToolbarColors.buttonHover : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
            // 鼠标悬停时重置自动隐藏定时器
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
        .help(action.shortcutHint.map { "\(action.displayName) (\($0))" } ?? action.displayName)
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
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
        .frame(width: 300, height: 60)
        .background(Color.gray)
}
