import SwiftUI

private typealias DS = DesignTokens

struct ScreenshotSettingsView: View {
    @ObservedObject private var settings = ScreenshotSettings.shared
    @ObservedObject private var modelManager = ImageUpscalerModelManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            Text("截图设置")
                .font(DS.Typography.caption.weight(.medium))
                .foregroundStyle(DS.Colors.textSecondary)
                .padding(.leading, DS.Spacing.xs)
            
            SettingsCard {
                // Upscaling Mode
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    HStack {
                        Image(systemName: "arrow.up.left.and.arrow.down.right.magnifyingglass")
                            .font(.system(size: DS.Layout.iconSizeMedium))
                            .foregroundStyle(DS.Colors.textSecondary)
                            .frame(width: DS.Layout.iconSizeLarge)
                        
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text("放大画质增强")
                                .font(DS.Typography.button.weight(.medium))
                                .foregroundStyle(DS.Colors.textPrimary)
                            Text("截图缩放时的清晰度优化策略")
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.top, DS.Spacing.xl)
                    
                    Picker("模式", selection: $settings.upscalingMode) {
                        ForEach(UpscalingMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                    .padding(.horizontal, DS.Layout.iconBackdropSize + DS.Spacing.lg) // Align with text
                    
                    if settings.upscalingMode == .ai {
                        Divider()
                            .background(DS.Colors.settingsCardBorder)
                            .padding(.horizontal, DS.Spacing.xl)
                        
                        // AI Model Status
                        aiModelSection
                            .padding(.horizontal, DS.Spacing.xl)
                            .padding(.bottom, DS.Spacing.xl)
                    } else {
                        Spacer().frame(height: DS.Spacing.xl)
                    }
                }
            }
            
            // Copy Enhanced Image Toggle
            SettingsCard {
                Toggle(isOn: $settings.copyEnhancedImage) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: DS.Layout.iconSizeMedium))
                            .foregroundStyle(DS.Colors.textSecondary)
                            .frame(width: DS.Layout.iconSizeLarge)
                        
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text("复制优化后图片")
                                .font(DS.Typography.button.weight(.medium))
                                .foregroundStyle(DS.Colors.textPrimary)
                            Text("复制时使用 AI 增强后的高清图片")
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                    }
                }
                .toggleStyle(.switch)
                .padding(DS.Spacing.xl)
            }
        }
        .onAppear {
            modelManager.checkState()
        }
    }
    
    private var aiModelSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Real-ESRGAN Model")
                        .font(DS.Typography.button.weight(.medium))
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text("深度学习 4x 超分辨率。处理较慢，但细节更丰富。")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                statusBadge(for: modelManager.state)
            }
            
            // Action Area
            Group {
                switch modelManager.state {
                case .notDownloaded:
                    Button {
                        modelManager.downloadModel()
                    } label: {
                        HStack {
                            Image(systemName: "icloud.and.arrow.down")
                            Text("下载模型 (~50MB)")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.Colors.accentPrimary)
                    
                case .downloading(let progress):
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .tint(DS.Colors.accentPrimary)
                        HStack {
                            Text("下载中...")
                            Spacer()
                            Text("\(Int(progress * 100))%")
                        }
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(DS.Colors.textSecondary)
                    }
                    
                case .unziping:
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("解压安装中...")
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                    
                case .compiled:
                    HStack {
                        Spacer()
                        Button {
                            modelManager.deleteModel()
                        } label: {
                            Label("删除模型", systemImage: "trash")
                                .font(DS.Typography.captionSmall)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(DS.Colors.error.opacity(0.8))
                    }
                    
                case .failed(let error):
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(DS.Colors.error)
                            Text("错误: \(error)")
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(DS.Colors.error)
                                .lineLimit(2)
                        }
                        Button("重试") { modelManager.downloadModel() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
        }
        .padding(DS.Spacing.lg)
        .background(DS.Colors.rowHover)
        .cornerRadius(DS.CornerRadius.md)
    }
    
    @ViewBuilder
    private func statusBadge(for state: ImageUpscalerDownloadState) -> some View {
        HStack(spacing: DS.Spacing.xxs) {
            Circle()
                .fill(stateColor(for: state))
                .frame(width: DS.Spacing.sm, height: DS.Spacing.sm)
            
            Text(stateText(for: state))
                .font(DS.Typography.captionSmall.weight(.medium))
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
        .background(stateColor(for: state).opacity(0.1))
        .cornerRadius(DS.CornerRadius.lg)
        .foregroundStyle(stateColor(for: state))
    }
    
    private func stateColor(for state: ImageUpscalerDownloadState) -> Color {
        switch state {
        case .notDownloaded: return DS.Colors.textSecondary
        case .downloading: return DS.Colors.accentPrimary
        case .unziping: return DS.Colors.accentPrimary
        case .compiled: return DS.Colors.success
        case .failed: return DS.Colors.error
        }
    }
    
    private func stateText(for state: ImageUpscalerDownloadState) -> String {
        switch state {
        case .notDownloaded: return "Not Installed"
        case .downloading: return "Downloading"
        case .unziping: return "Installing"
        case .compiled: return "Ready"
        case .failed: return "Error"
        }
    }
}
