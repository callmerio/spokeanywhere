import SwiftUI

private typealias DS = DesignTokens

// MARK: - UI Constants

private enum ModelSettingsColors {
    static let cardBackground = DS.Colors.settingsCardBackground
    static let borderColor = DS.Colors.settingsCardBorder
    static let dividerColor = DS.Colors.settingsCardBorder
    static let badgeBackground = DS.Colors.rowHover
    static let infoBackground = DS.Colors.accentInfo.opacity(0.1)
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
                .font(DS.Typography.caption.weight(.medium))
                .foregroundStyle(DS.Colors.textSecondary)
                .padding(.leading, DS.Spacing.xs)
            
            // Model Cards
            VStack(spacing: 0) {
                ForEach(modelManager.allModels) { model in
                    ModelCard(
                        model: model,
                        isSelected: modelManager.settings.selectedModelId == model.id,
                        roles: modelManager.roles(for: model.id),
                        settings: modelManager.settings.settings(for: model.id),
                        downloadState: modelManager.downloadState(for: model.id),
                        onSelect: {
                            selectModel(model)
                        },
                        onLocaleChange: { locale in
                            modelManager.updateSettings(for: model.id) { setting in
                                setting.locale = locale
                            }
                        },
                        onPrecompiledLMToggle: { enabled in
                            modelManager.updateSettings(for: model.id) { setting in
                                setting.enablePrecompiledLM = enabled
                            }
                        },
                        onDownload: {
                            modelToDownload = model
                            showDownloadAlert = true
                        },
                        onSetRole: { role in
                            modelManager.setModelRole(model.id, as: role)
                        },
                        canSetRole: { role in
                            modelManager.canSetRole(role, for: model.id)
                        }
                    )
                    
                    if model.id != modelManager.allModels.last?.id {
                        Divider()
                            .background(ModelSettingsColors.dividerColor)
                    }
                }
            }
            .background(ModelSettingsColors.cardBackground)
            .cornerRadius(DS.CornerRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: DS.CornerRadius.lg)
                    .strokeBorder(ModelSettingsColors.borderColor, lineWidth: DS.BorderWidth.thin)
            )
            
            // Info Card
            infoCard
            
            // Live Caption Audio Capture Mode (macOS 14+)
            if #available(macOS 14.0, *) {
                liveCaptionCaptureSettings
            }
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
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "info.circle")
                    .foregroundStyle(DS.Colors.accentInfo)
                Text("关于模型")
                    .font(DS.Typography.caption.weight(.medium))
                    .foregroundStyle(DS.Colors.textPrimary)
            }
            
            Text("• **Apple Dictation**: 系统内置，快速，支持预编译词典\n• **Apple SpeechTranscriber**: 更强模型 (~2GB)，更好的多语言支持")
                .font(DS.Typography.captionSmall)
                .foregroundStyle(DS.Colors.textSecondary)
                .lineSpacing(DS.LineSpacing.normal)
        }
        .padding(DS.Spacing.lg)
        .background(ModelSettingsColors.infoBackground)
        .cornerRadius(DS.CornerRadius.md)
    }
    
    private var liveCaptionCaptureSettings: some View {
        LiveCaptionCaptureSettingsSection()
    }
}

// MARK: - Live Caption Capture Settings Section

@available(macOS 14.0, *)
private struct LiveCaptionCaptureSettingsSection: View {
    @AppStorage("LiveCaptionCaptureMode") private var captureMode: String = LiveCaptionManager.CaptureMode.global.rawValue
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text("实时字幕音频源")
                .font(DS.Typography.caption.weight(.medium))
                .foregroundStyle(DS.Colors.textSecondary)
                .padding(.leading, DS.Spacing.xs)
            
            VStack(spacing: 0) {
                ForEach(LiveCaptionManager.CaptureMode.allCases, id: \.rawValue) { mode in
                    CaptureModeRow(
                        mode: mode,
                        isSelected: captureMode == mode.rawValue,
                        onSelect: {
                            captureMode = mode.rawValue
                        }
                    )
                    
                    if mode != LiveCaptionManager.CaptureMode.allCases.last {
                        Divider()
                            .background(ModelSettingsColors.dividerColor)
                    }
                }
            }
            .background(ModelSettingsColors.cardBackground)
            .cornerRadius(DS.CornerRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: DS.CornerRadius.lg)
                    .strokeBorder(ModelSettingsColors.borderColor, lineWidth: DS.BorderWidth.thin)
            )
            
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("• 切换模式后需重新启动实时字幕生效")
                Text("• 应用模式：取消选择将自动使用全局模式")
            }
            .font(DS.Typography.timestamp)
            .foregroundStyle(DS.Colors.textSecondary.opacity(0.7))
            .padding(.leading, DS.Spacing.xs)
        }
    }
}

// MARK: - Capture Mode Row

@available(macOS 14.0, *)
private struct CaptureModeRow: View {
    let mode: LiveCaptionManager.CaptureMode
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DS.Spacing.lg) {
                Image(systemName: mode == .global ? "speaker.wave.3" : "app.badge.checkmark")
                    .font(.system(size: DS.Layout.iconSizeToolbar))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .frame(width: DS.Layout.iconSizeLarge)
                
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(mode.displayName)
                        .font(DS.Typography.button.weight(.medium))
                        .foregroundStyle(DS.Colors.textPrimary)
                    
                    Text(mode.description)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.Colors.accentPrimary)
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Model Card

/// 单个模型卡片组件
/// 显示模型信息、选择状态、下载状态和配置选项
@available(macOS 26.0, *)
struct ModelCard: View {
    let model: TranscriptionModelDefinition
    let isSelected: Bool
    let roles: [TranscriptionModelRole]
    let settings: PerModelSettings
    let downloadState: ModelDownloadState
    let onSelect: () -> Void
    let onLocaleChange: (String) -> Void
    let onPrecompiledLMToggle: (Bool) -> Void
    let onDownload: () -> Void
    let onSetRole: (TranscriptionModelRole) -> Void
    let canSetRole: (TranscriptionModelRole) -> Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Header Row
            HStack(spacing: DS.Spacing.lg) {
                // Icon
                modelIcon
                
                // Title & Description
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.md) {
                        Text(model.displayName)
                            .font(.system(size: DS.Typography.fontSizeContent, weight: .medium))
                            .foregroundStyle(model.isAvailable ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                        
                        // Role Badges
                        ForEach(roles, id: \.self) { role in
                            RoleBadge(role: role)
                        }
                        
                        if model.isComingSoon {
                            Text("Coming Soon")
                                .font(.system(size: DS.Typography.fontSizeTimestamp, weight: .bold))
                                .foregroundStyle(DS.Colors.textSecondary)
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xxs)
                                .background(DS.Colors.buttonHover)
                                .cornerRadius(DS.CornerRadius.xs)
                        }
                        
                        if let minOS = model.minimumOS {
                            Text(minOS)
                                .font(.system(size: DS.Typography.fontSizeTimestamp))
                                .foregroundStyle(DS.Colors.textSecondary.opacity(0.7))
                        }
                    }
                    
                    Text(model.subtitle)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(DS.Colors.textSecondary)
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
        .padding(DS.Spacing.xl)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .opacity(model.isAvailable ? 1.0 : 0.6)
        .contextMenu {
            // 设为转录模型
            if canSetRole(.transcription) {
                Button {
                    onSetRole(.transcription)
                } label: {
                    Label("设为转录模型", systemImage: TranscriptionModelRole.transcription.icon)
                }
            }
            
            // 设为实时字幕模型（仅支持流式的模型显示）
            if canSetRole(.liveCaption) {
                Button {
                    onSetRole(.liveCaption)
                } label: {
                    Label("设为实时字幕模型", systemImage: TranscriptionModelRole.liveCaption.icon)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var modelIcon: some View {
        ZStack {
            Circle()
                .fill(model.isAvailable ? DS.Colors.accentPrimary.opacity(0.2) : DS.Colors.textSecondary.opacity(0.1))
                .frame(width: DS.Layout.iconBackdropSize, height: DS.Layout.iconBackdropSize)
            
            Image(systemName: model.iconName)
                .font(.system(size: DS.Layout.iconSizeMedium))
                .foregroundStyle(model.isAvailable ? DS.Colors.accentPrimary : DS.Colors.textSecondary)
        }
    }
    
    @ViewBuilder
    private var selectionIndicator: some View {
        switch downloadState {
        case .notNeeded:
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: DS.Layout.iconSizeStandard))
                    .foregroundStyle(DS.Colors.accentPrimary)
            }
            
        case .notDownloaded:
            Button(action: onDownload) {
                HStack(spacing: DS.Spacing.xxs) {
                    Image(systemName: "arrow.down.circle")
                    if let size = model.sizeString {
                        Text(size)
                            .font(DS.Typography.captionSmall)
                    }
                }
                .foregroundStyle(DS.Colors.accentPrimary)
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
                    .font(.system(size: DS.Layout.iconSizeStandard))
                    .foregroundStyle(DS.Colors.accentPrimary)
            }
            // Not selected but downloaded: show nothing (download complete)
            
        case .failed:
            Button(action: onDownload) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(DS.Colors.error)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var optionsRow: some View {
        HStack(spacing: DS.Spacing.xl) {
            // Language Selector
            if model.needsLanguageSelection {
                HStack(spacing: DS.Spacing.md) {
                    Text("语言:")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                    
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
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .toggleStyle(.checkbox)
            }
            
            Spacer()
        }
        .padding(.leading, DS.Layout.iconBackdropSize + DS.Spacing.lg)
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
                    .font(DS.Typography.timestamp)
                Text(model.source == .api ? "云端" : "本地")
                    .font(DS.Typography.timestamp)
            }
            .foregroundStyle(DS.Colors.textSecondary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(ModelSettingsColors.badgeBackground)
            .cornerRadius(DS.CornerRadius.xs)
            
            Spacer()
        }
        .padding(.leading, DS.Layout.iconBackdropSize + DS.Spacing.lg)
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
        HStack(spacing: DS.Spacing.xxs) {
            Image(systemName: icon)
                .font(DS.Typography.timestamp)
                .foregroundStyle(DS.Colors.textSecondary)
            
            HStack(spacing: 2) {
                ForEach(0..<maxValue, id: \.self) { i in
                    Circle()
                        .fill(i < value ? DS.Colors.accentPrimary : DS.Colors.textSecondary.opacity(0.3))
                        .frame(width: DS.Spacing.sm, height: DS.Spacing.sm)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
        .background(ModelSettingsColors.badgeBackground)
        .cornerRadius(DS.CornerRadius.xs)
    }
}

// MARK: - Role Badge

/// 角色徽章组件（类似 AI 配置中的"转录"、"对话"标签）
struct RoleBadge: View {
    let role: TranscriptionModelRole
    
    var body: some View {
        Text(role.displayName)
            .font(DS.Typography.timestamp.weight(.bold))
            .foregroundStyle(DS.Colors.textPrimary)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background(badgeColor)
            .cornerRadius(DS.CornerRadius.xs)
    }
    
    private var badgeColor: Color {
        let color = role.badgeColor
        return Color(red: color.red, green: color.green, blue: color.blue).opacity(0.8)
    }
}
