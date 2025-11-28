import SwiftUI

// MARK: - Attachment Picker Menu

/// 通用附件选择器菜单（加号按钮）
/// 可复用于 QuickAsk、HUD 等多个入口
/// - Hover 时从 paperclip 图标 fade 变成 plus 图标
/// - 处理文件夹/ZIP 时显示进度条
struct AttachmentPickerMenu: View {
    /// 添加附件的回调
    let onAdd: (Attachment) -> Void
    
    /// 按钮大小
    var buttonSize: CGFloat = 24
    
    @State private var isHovering = false
    @ObservedObject private var attachmentManager = AttachmentManager.shared
    
    /// 是否正在处理
    private var isProcessing: Bool {
        attachmentManager.processingState.isProcessing
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // 菜单按钮
            menuButton
            
            // 处理进度（处理中时显示）
            if isProcessing {
                processingIndicator
            }
        }
    }
    
    // MARK: - Menu Button
    
    private var menuButton: some View {
        Menu {
            // 从设备上传
            Button(action: pickFiles) {
                Label("从设备上传", systemImage: "doc.badge.plus")
            }
            
            Divider()
            
            // 导入文件夹（转为文本）
            Button(action: pickFolder) {
                Label("导入文件夹 (转为文本)", systemImage: "folder.badge.plus")
            }
            
            // 导入 ZIP（转为文本）
            Button(action: pickZIP) {
                Label("导入 ZIP (转为文本)", systemImage: "doc.zipper")
            }
            
            Divider()
            
            // 图库
            Button(action: pickFromPhotos) {
                Label("图库", systemImage: "photo.on.rectangle")
            }
            
            // 屏幕截图
            Button(action: captureScreen) {
                Label("屏幕截图", systemImage: "camera.viewfinder")
            }
            
        } label: {
            ZStack {
                // 默认图标（paperclip）- hover 时 fade out
                Image(systemName: "paperclip")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .opacity(isHovering ? 0 : 1)
                
                // Hover 图标（plus）- hover 时 fade in
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .opacity(isHovering ? 1 : 0)
            }
            .frame(width: buttonSize, height: buttonSize)
            .background(
                Circle()
                    .fill(isHovering ? Color.white.opacity(0.15) : Color.clear)
            )
            .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .disabled(isProcessing)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
    
    // MARK: - Processing Indicator
    
    private var processingIndicator: some View {
        HStack(spacing: 4) {
            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // 背景
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                    
                    // 进度
                    Capsule()
                        .fill(Color.blue.opacity(0.8))
                        .frame(width: geo.size.width * attachmentManager.processingState.progress)
                        .animation(.linear(duration: 0.1), value: attachmentManager.processingState.progress)
                }
            }
            .frame(width: 60, height: 4)
            
            // 文件数
            if case .processing(let current, let total, _) = attachmentManager.processingState {
                Text("\(current)/\(total)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }
    
    // MARK: - Actions
    
    private func pickFiles() {
        attachmentManager.pickFiles(onAdd: onAdd)
    }
    
    private func pickFolder() {
        attachmentManager.pickFolder(onAdd: onAdd)
    }
    
    private func pickZIP() {
        attachmentManager.pickZIP(onAdd: onAdd)
    }
    
    private func pickFromPhotos() {
        attachmentManager.pickFromPhotos(onAdd: onAdd)
    }
    
    private func captureScreen() {
        attachmentManager.captureScreen(onAdd: onAdd)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.opacity(0.8)
        
        AttachmentPickerMenu { attachment in
            print("Added: \(attachment.displayTitle)")
        }
    }
    .frame(width: 200, height: 100)
}
