import SwiftUI

/// 过滤标签按钮
struct FilterChip: View {
    let title: String
    let badgeCount: Int
    let isActive: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))

                if badgeCount != 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(isActive ? Color.white.opacity(0.3) : color.opacity(0.3))
                        )
                }
            }
            .foregroundColor(isActive ? .white : color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isActive ? color : color.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(color.opacity(isActive ? 0 : 0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .fixedSize()  // 防止被压缩折叠
    }
}
