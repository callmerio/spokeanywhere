import SwiftUI

private typealias DS = DesignTokens

// MARK: - Live Caption Toolbar

/// 字幕工具栏
struct LiveCaptionToolbar: View {
    
    @ObservedObject var manager: LiveCaptionManager
    @Binding var isExpanded: Bool
    
    var onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // 应用模式时显示当前应用名或重试状态
            if manager.captureMode == LiveCaptionManager.CaptureMode.appPicker.rawValue {
                if let appName = manager.currentAppName {
                    appNameButton(appName)
                } else if manager.isRetrying {
                    // 重试中但 appName 被清空
                    retryingIndicator
                }
            }
            
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
        .background(DS.Colors.toolbarBackground)
    }
    
    // MARK: - App Name Button
    
    private func appNameButton(_ appName: String) -> some View {
        Button {
            manager.reselectApp()
        } label: {
            HStack(spacing: 4) {
                if manager.isRetrying {
                    // 重试中显示旋转图标
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.8)
                    Text("正在重连...")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 10))
                    Text(appName)
                        .font(.system(size: 12))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
            }
            .foregroundStyle(manager.isRetrying ? .orange : DS.Colors.textPrimary)
        }
        .buttonStyle(.plain)
        .help(manager.isRetrying ? "正在尝试重新连接..." : "点击重新选择应用")
    }
    
    /// 重试中指示器（无应用名时显示）
    private var retryingIndicator: some View {
        HStack(spacing: 4) {
            ProgressView()
                .controlSize(.mini)
                .scaleEffect(0.8)
            Text("正在重连...")
                .font(.system(size: 12))
        }
        .foregroundStyle(.orange)
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
            .foregroundStyle(DS.Colors.textPrimary)
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
                Image(
                    systemName: isExpanded
                        ? "arrow.down.right.and.arrow.up.left"
                        : "arrow.up.left.and.arrow.down.right"
                )
                    .font(.system(size: 11))
                Text(isExpanded ? "收起字幕" : "展开字幕")
                    .font(.system(size: 12))
            }
            .foregroundStyle(DS.Colors.textPrimary)
        }
        .buttonStyle(.plain)
    }
    
    private var closeButton: some View {
        Button {
            onClose()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(DS.Colors.textPlaceholder)
        }
        .buttonStyle(.plain)
        .onHover { _ in
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
