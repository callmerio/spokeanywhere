import SwiftUI

private typealias DS = DesignTokens

/// 来源应用图标视图（带光晕效果 + hover 覆盖标签）
struct SourceAppIconView: View {
    let sourceApp: SourceAppInfo
    let glowColor: Color
    var typeName: String = ""  // 类型名称（转录/润色）

    @State private var isHovered = false

    /// hover 提示文本
    private var hoverText: String {
        if !typeName.isEmpty && !sourceApp.name.isEmpty {
            return "\(sourceApp.name) · \(typeName)"
        } else if !typeName.isEmpty {
            return typeName
        } else {
            return sourceApp.name
        }
    }

    var body: some View {
        ZStack {
            // 光晕效果
            Circle()
                .fill(glowColor.opacity(0.4))
                .frame(width: 26, height: 26)
                .blur(radius: 4)

            // 应用图标
            Group {
                if let icon = sourceApp.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
            .frame(width: 18, height: 18)
            .clipShape(RoundedRectangle(cornerRadius: DS.CornerRadius.xs))
        }
        .frame(width: 26, height: 26)
        .contentShape(Rectangle())  // 扩大 hover 响应区域
        .onHover { hovering in
            // 🍑 移除动画，避免卡死
            isHovered = hovering
        }
        // 覆盖标签（用 overlay 实现悬浮）
        .overlay(alignment: .leading) {
            if isHovered && !hoverText.isEmpty {
                HStack(spacing: 6) {
                    // 小图标
                    Group {
                        if let icon = sourceApp.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            Image(systemName: "app.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(DS.Colors.textPrimary)
                        }
                    }
                    .frame(width: 14, height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: DS.CornerRadius.xs))

                    Text(hoverText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    ZStack {
                        // 磨砂背景
                        VisualEffectBlur(material: .hudWindow, cornerRadius: 6)
                        // 渐变遮罩
                        LinearGradient(
                            colors: [
                                glowColor.opacity(0.3),
                                glowColor.opacity(0.1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: DS.CornerRadius.sm))
                .shadow(color: DS.Colors.overlayDark, radius: 4, x: 0, y: 2)
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))
                .fixedSize()
                .allowsHitTesting(false)  // 不响应鼠标，防止闪烁
            }
        }
        .zIndex(100)  // 确保在最上层
    }
}
