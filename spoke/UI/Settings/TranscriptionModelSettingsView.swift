import SwiftUI

// MARK: - UI Constants

private enum ModelSettingsColors {
    static let cardBackground = Color(hex: "252525")
    static let borderColor = Color.white.opacity(0.06)
    static let dividerColor = Color.white.opacity(0.06)
    static let badgeBackground = Color.white.opacity(0.05)
    static let infoBackground = Color.blue.opacity(0.1)
}

// MARK: - Transcription Model Settings View

/// 转录模型设置视图
/// - 显示所有可用模型卡片
/// - 支持语言选择和预编译 LM 开关
/// - 显示模型能力评级
@available(macOS 26.0, *)
struct TranscriptionModelSettingsView: View {
    private let modelManager = TranscriptionModelManager.shared
    @State private var showDownloadAlert = false
    @State private var modelToDownload: TranscriptionModelDefinition?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section Title
            Text("语音转文字引擎")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.gray)
                .padding(.leading, 4)
            
            // Model Cards
            VStack(spacing: 0) {
                ForEach(modelManager.allModels) { model in
                    ModelCard(
                        model: model,
                        isSelected: modelManager.settings.selectedModelId == model.id,
                        settings: modelManager.settings.settings(for: model.id),
                        downloadState: modelManager.downloadState(for: model.id),
                        onSelect: {
                            selectModel(model)
                        },
                        onLocaleChange: { locale in
                            modelManager.updateSettings(for: model.id) { s in
                                s.locale = locale
                            }
                        },
                        onPrecompiledLMToggle: { enabled in
                            modelManager.updateSettings(for: model.id) { s in
                                s.enablePrecompiledLM = enabled
                            }
                        },
                        onDownload: {
                            modelToDownload = model
                            showDownloadAlert = true
                        }
                    )
                    
                    if model.id != modelManager.allModels.last?.id {
                        Divider()
                            .background(ModelSettingsColors.dividerColor)
                    }
                }
            }
            .background(ModelSettingsColors.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(ModelSettingsColors.borderColor, lineWidth: 1)
            )
            
            // Info Card
            infoCard
        }
        .alert("下载模型", isPresented: $showDownloadAlert) {
            Button("下载") {
                if let model = modelToDownload {
                    Task {
                        await modelManager.downloadModel(model.id)
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let model = modelToDownload {
                Text("下载 \(model.displayName) (\(model.sizeString ?? "未知大小"))？这可能需要一些时间。")
            }
        }
    }
    
    private func selectModel(_ model: TranscriptionModelDefinition) {
        guard model.isAvailable else { return }
        
        if model.requiresDownload && !modelManager.downloadState(for: model.id).isReady {
            modelToDownload = model
            showDownloadAlert = true
        } else {
            modelManager.selectModel(model.id)
        }
    }
    
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                Text("关于模型")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            }
            
            Text("• **Apple Dictation**: 系统内置，快速，支持预编译词典\n• **Apple SpeechTranscriber**: 更强模型 (~2GB)，更好的多语言支持")
                .font(.system(size: 11))
                .foregroundStyle(.gray)
                .lineSpacing(4)
        }
        .padding(12)
        .background(ModelSettingsColors.infoBackground)
        .cornerRadius(8)
    }
}

// MARK: - Model Card

/// 单个模型卡片组件
/// 显示模型信息、选择状态、下载状态和配置选项
@available(macOS 26.0, *)
struct ModelCard: View {
    let model: TranscriptionModelDefinition
    let isSelected: Bool
    let settings: PerModelSettings
    let downloadState: ModelDownloadState
    let onSelect: () -> Void
    let onLocaleChange: (String) -> Void
    let onPrecompiledLMToggle: (Bool) -> Void
    let onDownload: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Row
            HStack(spacing: 12) {
                // Icon
                modelIcon
                
                // Title & Description
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(model.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(model.isAvailable ? .white : .gray)
                        
                        if model.isComingSoon {
                            Text("Coming Soon")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.gray)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        if let minOS = model.minimumOS {
                            Text(minOS)
                                .font(.system(size: 9))
                                .foregroundStyle(.gray.opacity(0.7))
                        }
                    }
                    
                    Text(model.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)
                }
                
                Spacer()
                
                // Selection / Download
                selectionIndicator
            }
            
            // Options Row (only for selected model)
            if isSelected && model.isAvailable {
                optionsRow
            }
            
            // Capabilities Row
            if isSelected {
                capabilitiesRow
            }
        }
        .padding(16)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .opacity(model.isAvailable ? 1.0 : 0.6)
    }
    
    // MARK: - Subviews
    
    private var modelIcon: some View {
        ZStack {
            Circle()
                .fill(model.isAvailable ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                .frame(width: 40, height: 40)
            
            Image(systemName: model.iconName)
                .font(.system(size: 16))
                .foregroundStyle(model.isAvailable ? .blue : .gray)
        }
    }
    
    @ViewBuilder
    private var selectionIndicator: some View {
        switch downloadState {
        case .notNeeded:
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
            }
            
        case .notDownloaded:
            Button(action: onDownload) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                    if let size = model.sizeString {
                        Text(size)
                            .font(.system(size: 11))
                    }
                }
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            
        case .downloading(let progress):
            ProgressView(value: progress)
                .progressViewStyle(.circular)
                .frame(width: 20, height: 20)
            
        case .downloaded:
            // Only show checkmark for selected model
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
            }
            // Not selected but downloaded: show nothing (download complete)
            
        case .failed:
            Button(action: onDownload) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var optionsRow: some View {
        HStack(spacing: 16) {
            // Language Selector
            if model.needsLanguageSelection {
                HStack(spacing: 8) {
                    Text("语言:")
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                    
                    Picker("", selection: Binding(
                        get: { settings.locale },
                        set: { onLocaleChange($0) }
                    )) {
                        ForEach(model.supportedLocales, id: \.self) { locale in
                            Text(Locale.current.localizedString(forIdentifier: locale) ?? locale)
                                .tag(locale)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }
            }
            
            // Precompiled LM Toggle
            if model.supportsPrecompiledLM {
                Toggle(isOn: Binding(
                    get: { settings.enablePrecompiledLM },
                    set: { onPrecompiledLMToggle($0) }
                )) {
                    Text("预编译词典")
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                }
                .toggleStyle(.checkbox)
            }
            
            Spacer()
        }
        .padding(.leading, 52)
    }
    
    private var capabilitiesRow: some View {
        HStack(spacing: 12) {
            // Accuracy
            CapabilityBadge(
                icon: "target",
                label: "精度",
                value: model.accuracy.rawValue,
                maxValue: 5
            )
            
            // Speed
            CapabilityBadge(
                icon: "bolt",
                label: "速度",
                value: model.speed.rawValue,
                maxValue: 5
            )
            
            // Source
            HStack(spacing: 4) {
                Image(systemName: model.source == .api ? "cloud" : "house")
                    .font(.system(size: 10))
                Text(model.source == .api ? "云端" : "本地")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.gray)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(ModelSettingsColors.badgeBackground)
            .cornerRadius(4)
            
            Spacer()
        }
        .padding(.leading, 52)
    }
}

// MARK: - Capability Badge

/// 能力评级徽章组件

struct CapabilityBadge: View {
    let icon: String
    let label: String
    let value: Int
    let maxValue: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.gray)
            
            HStack(spacing: 2) {
                ForEach(0..<maxValue, id: \.self) { i in
                    Circle()
                        .fill(i < value ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(ModelSettingsColors.badgeBackground)
        .cornerRadius(4)
    }
}
