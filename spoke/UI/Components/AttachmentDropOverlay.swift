import SwiftUI
import UniformTypeIdentifiers

// MARK: - Attachment Drop Overlay

/// 通用拖拽蒙版视图
/// 可复用于 QuickAsk、HUD 等多个入口
struct AttachmentDropOverlay: View {
    /// 圆角半径
    var cornerRadius: CGFloat = 16
    
    /// 是否显示
    var isVisible: Bool = true
    
    var body: some View {
        if isVisible {
            ZStack {
                // 半透明背景
                Color.black.opacity(0.6)
                
                // 蓝色背景
                Color.blue.opacity(0.15)
                
                // 虚线边框
                RoundedRectangle(cornerRadius: cornerRadius - 4)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    .foregroundStyle(Color.blue.opacity(0.6))
                    .padding(4)
                
                // 提示内容
                VStack(spacing: 12) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.blue)
                    
                    Text("拖放文件到这里")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.blue)
                    
                    Text("支持图片、文件、文件夹、ZIP")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.blue.opacity(0.7))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .transition(.opacity)
        }
    }
}

// MARK: - Drop Handler Modifier

/// 通用拖拽处理修饰符
struct AttachmentDropHandler: ViewModifier {
    /// 添加附件的回调
    let onAdd: (Attachment) -> Void
    
    /// 圆角半径（用于蒙版）
    var cornerRadius: CGFloat = 16
    
    @State private var isDragOver = false
    
    private let attachmentManager = AttachmentManager.shared
    
    func body(content: Content) -> some View {
        content
            .overlay {
                AttachmentDropOverlay(
                    cornerRadius: cornerRadius,
                    isVisible: isDragOver
                )
            }
            .onDrop(of: supportedTypes, isTargeted: $isDragOver) { providers in
                handleDrop(providers: providers)
                return true
            }
    }
    
    /// 支持的拖拽类型
    private var supportedTypes: [UTType] {
        [.image, .fileURL, .folder, .zip]
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        attachmentManager.handleDrop(providers: providers, onAdd: onAdd)
    }
}

// MARK: - View Extension

extension View {
    /// 添加通用拖拽处理
    func attachmentDropHandler(
        cornerRadius: CGFloat = 16,
        onAdd: @escaping (Attachment) -> Void
    ) -> some View {
        modifier(AttachmentDropHandler(onAdd: onAdd, cornerRadius: cornerRadius))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.opacity(0.8)
        
        VStack {
            Text("拖放文件到这里")
                .foregroundStyle(.white)
        }
        .frame(width: 340, height: 200)
        .attachmentDropHandler { attachment in
            print("Added: \(attachment.displayTitle)")
        }
    }
    .frame(width: 400, height: 300)
}
