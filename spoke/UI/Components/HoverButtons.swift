import SwiftUI

private typealias DS = DesignTokens

// MARK: - Hover Close Button
/// 关闭按钮：hover 时圆形 → 圆角方形 + 背景变亮
/// 用于：Quick Chat toolbar, Message Panel 等
struct HoverCloseButton: View {
    let action: () -> Void
    var size: CGFloat = 22
    var iconSize: CGFloat = 12
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action, label: {
            Image(systemName: "xmark")
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(isHovered ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                .frame(width: size, height: size)
                .background(isHovered ? DS.Colors.buttonHoverStrong : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: isHovered ? size * 0.27 : size / 2))
                .animation(.easeInOut(duration: 0.2), value: isHovered)
        })
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Hover Action Button
/// 操作按钮：hover 时无背景 → 出现背景 + 圆角变化
/// 用于：新对话、收起等操作
struct HoverActionButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action, label: {
            label()
                .foregroundStyle(isHovered ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isHovered ? DS.Colors.buttonHover : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: isHovered ? 6 : 12))
                .animation(.easeInOut(duration: 0.2), value: isHovered)
        })
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Text + Icon Button

/// 文字 + 图标的操作按钮（复用 HoverActionButton）
struct HoverTextIconButton: View {
    let text: String
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        HoverActionButton(action: action, label: {
            HStack(spacing: 4) {
                Text(text)
                    .font(.system(size: 13, weight: .medium))
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
            }
        })
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 20) {
        HoverCloseButton(action: {})
        
        HoverTextIconButton(text: "收起", systemImage: "chevron.up", action: {})
        
        HoverActionButton(action: {}, label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                Text("新对话")
                    .font(.system(size: 13, weight: .medium))
            }
        })
    }
    .padding(20)
    .background(DS.Colors.overlayStrong)
}
