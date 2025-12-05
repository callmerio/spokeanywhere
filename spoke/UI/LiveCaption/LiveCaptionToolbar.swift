import SwiftUI

// MARK: - Live Caption Toolbar

/// 字幕工具栏
struct LiveCaptionToolbar: View {
    
    @ObservedObject var manager: LiveCaptionManager
    @Binding var isExpanded: Bool
    
    var onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // 识别语言选择（独立于全局设置）
            languageMenu
            
            Spacer()
            
            // 展开/收起
            expandButton
            
            // 关闭按钮
            closeButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(white: 0.1))
    }
    
    // MARK: - Components
    
    private var languageMenu: some View {
        Menu {
            ForEach(LiveCaptionManager.supportedLanguages, id: \.id) { lang in
                Button {
                    Task {
                        await manager.setLocale(lang.id)
                    }
                } label: {
                    HStack {
                        Text(lang.name)
                        if manager.captionLocale == lang.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.system(size: 12))
                Text(currentLanguageName)
                    .font(.system(size: 12))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundColor(.white.opacity(0.8))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
    
    private var expandButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11))
                Text(isExpanded ? "收起字幕" : "展开字幕")
                    .font(.system(size: 12))
            }
            .foregroundColor(.white.opacity(0.8))
        }
        .buttonStyle(.plain)
    }
    
    private var closeButton: some View {
        Button {
            onClose()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.5))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            // 可以添加 hover 效果
        }
    }
    
    // MARK: - Helpers
    
    private var currentLanguageName: String {
        LiveCaptionManager.supportedLanguages
            .first { $0.id == manager.captionLocale }?
            .name ?? "英语 (English)"
    }
}
