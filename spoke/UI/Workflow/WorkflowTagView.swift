import SwiftUI

private enum TagDesign {
    static let fontSize: CGFloat = 12
    static let closeIconSize: CGFloat = 8
    static let closeButtonPadding: CGFloat = 6
    static let horizontalPadding: CGFloat = 8
    static let verticalPadding: CGFloat = 6
    static let cornerRadius: CGFloat = 6
    static let textOpacity: Double = 0.9
    static let iconOpacity: Double = 0.5
    static let backgroundOpacity: Double = 0.15
}

/// Workflow 标签视图（方框样式，可选关闭按钮）
/// 用于：Quick Ask 输入框、Answer Panel 用户消息、Answer Panel 输入框
struct WorkflowTagView: View {
    let keyword: String
    var onRemove: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 4) {
            Text("/\(keyword)")
                .font(.system(size: TagDesign.fontSize, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(TagDesign.textOpacity))
            
            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: TagDesign.closeIconSize, weight: .bold))
                        .foregroundStyle(.white.opacity(TagDesign.iconOpacity))
                }
                .buttonStyle(.plain)
                .padding(TagDesign.closeButtonPadding)
                .contentShape(Rectangle())
                .accessibilityLabel("移除 \(keyword) 工作流")
            }
        }
        .padding(.horizontal, TagDesign.horizontalPadding)
        .padding(.vertical, TagDesign.verticalPadding)
        .background(Color.white.opacity(TagDesign.backgroundOpacity))
        .clipShape(RoundedRectangle(cornerRadius: TagDesign.cornerRadius))
    }
}

/// 用于消息气泡中的只读 Workflow 标签（无关闭按钮）
struct WorkflowTagBadge: View {
    let keyword: String
    
    var body: some View {
        WorkflowTagView(keyword: keyword)
    }
}

#Preview {
    VStack(spacing: 16) {
        WorkflowTagView(keyword: "translate") {
            print("Remove")
        }
        
        WorkflowTagBadge(keyword: "cc")
    }
    .padding()
    .background(Color.black)
}
