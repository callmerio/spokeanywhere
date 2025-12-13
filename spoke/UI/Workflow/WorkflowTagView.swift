import SwiftUI

/// Workflow 标签视图（方框样式，带关闭按钮）
/// 用于：Quick Ask 输入框、Answer Panel 用户消息、Answer Panel 输入框
struct WorkflowTagView: View {
    let keyword: String
    var showRemoveButton: Bool = true
    var onRemove: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 4) {
            Text("/\(keyword)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
            
            if showRemoveButton, let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

/// 用于消息气泡中的只读 Workflow 标签（无关闭按钮）
struct WorkflowTagBadge: View {
    let keyword: String
    
    var body: some View {
        WorkflowTagView(keyword: keyword, showRemoveButton: false)
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
