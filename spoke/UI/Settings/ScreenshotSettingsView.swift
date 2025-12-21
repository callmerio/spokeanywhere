import SwiftUI

private typealias DS = DesignTokens

struct ScreenshotSettingsView: View {
    @ObservedObject private var settings = ScreenshotSettings.shared
    @ObservedObject private var modelManager = ImageUpscalerModelManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("截图设置")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.gray)
                .padding(.leading, 4)
            
            SettingsCard {
                // Upscaling Mode
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "arrow.up.left.and.arrow.down.right.magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundStyle(.gray)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("放大画质增强")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                            Text("截图缩放时的清晰度优化策略")
                                .font(.system(size: 11))
                                .foregroundStyle(.gray)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    Picker("模式", selection: $settings.upscalingMode) {
                        ForEach(UpscalingMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                    .padding(.horizontal, 54) // Align with text
                    
                    if settings.upscalingMode == .ai {
                        Divider()
                            .background(DS.Colors.settingsCardBorder)
                            .padding(.horizontal, 16)
                        
                        // AI Model Status
                        aiModelSection
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    } else {
                        Spacer().frame(height: 16)
                    }
                }
            }
            
            // Copy Enhanced Image Toggle
            SettingsCard {
                Toggle(isOn: $settings.copyEnhancedImage) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 16))
                            .foregroundStyle(.gray)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("复制优化后图片")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                            Text("复制时使用 AI 增强后的高清图片")
                                .font(.system(size: 11))
                                .foregroundStyle(.gray)
                        }
                    }
                }
                .toggleStyle(.switch)
                .padding(16)
            }
        }
        .onAppear {
            modelManager.checkState()
        }
    }
    
    private var aiModelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Real-ESRGAN Model")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                    Text("深度学习 4x 超分辨率。处理较慢，但细节更丰富。")
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                statusBadge(for: modelManager.state)
            }
            
            // Action Area
            Group {
                switch modelManager.state {
                case .notDownloaded:
                    Button(action: { modelManager.downloadModel() }) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.down")
                            Text("下载模型 (~50MB)")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    
                case .downloading(let progress):
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .tint(.blue)
                        HStack {
                            Text("下载中...")
                            Spacer()
                            Text("\(Int(progress * 100))%")
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)
                    }
                    
                case .unziping:
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("解压安装中...")
                            .font(.system(size: 11))
                            .foregroundStyle(.gray)
                    }
                    
                case .compiled:
                    HStack {
                        Spacer()
                        Button(action: { modelManager.deleteModel() }) {
                            Label("删除模型", systemImage: "trash")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red.opacity(0.8))
                    }
                    
                case .failed(let error):
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text("错误: \(error)")
                                .font(.system(size: 11))
                                .foregroundStyle(.red)
                                .lineLimit(2)
                        }
                        Button("重试") { modelManager.downloadModel() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private func statusBadge(for state: ImageUpscalerDownloadState) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(stateColor(for: state))
                .frame(width: 6, height: 6)
            
            Text(stateText(for: state))
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(stateColor(for: state).opacity(0.1))
        .cornerRadius(12)
        .foregroundStyle(stateColor(for: state))
    }
    
    private func stateColor(for state: ImageUpscalerDownloadState) -> Color {
        switch state {
        case .notDownloaded: return .gray
        case .downloading: return .blue
        case .unziping: return .blue
        case .compiled: return .green
        case .failed: return .red
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
