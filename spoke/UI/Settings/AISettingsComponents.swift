import SwiftUI

private typealias DS = DesignTokens

// MARK: - Provider Icon View

struct ProviderIconView: View {
    let provider: LLMProviderType
    let size: CGFloat
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(iconBackground)
            
            Image(systemName: iconName)
                .font(.system(size: size * 0.45))
                .foregroundStyle(iconColor)
        }
        .frame(width: size, height: size)
    }
    
    private var iconName: String {
        switch provider {
        case .ollama: return "desktopcomputer"
        case .openai: return "bubble.left.and.bubble.right"
        case .anthropic: return "brain"
        case .googleGemini: return "sparkle"
        case .groq: return "bolt.fill"
        case .openRouter: return "arrow.triangle.branch"
        case .openAICompatible: return "server.rack"
        }
    }
    
    private var iconColor: Color {
        switch provider {
        case .ollama: return DS.Colors.textPrimary
        case .openai: return DS.Colors.success
        case .anthropic: return DS.Colors.warning
        case .googleGemini: return DS.Colors.accentPrimary
        case .groq: return DS.Colors.warning
        case .openRouter: return DS.Colors.accentProcessing
        case .openAICompatible: return DS.Colors.textSecondary
        }
    }
    
    private var iconBackground: Color {
        iconColor.opacity(0.15)
    }
}

// MARK: - Model Picker View (智能模型选择器)

struct ModelPickerView: View {
    @Binding var selectedModel: String
    let profile: ProviderProfile
    let placeholder: String
    let refreshTrigger: UUID
    
    @State private var isExpanded = false
    @State private var searchText = ""
    @State private var availableModels: [String] = []
    @State private var isLoading = false
    @State private var hasLoadedModels = false
    
    private var filteredModels: [String] {
        if searchText.isEmpty {
            return availableModels
        }
        return availableModels.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 主按钮/输入区域
            Button(action: { toggleExpanded() }, label: {
                HStack {
                    if isExpanded {
                        // 展开时显示搜索框
                        TextField(placeholder, text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundStyle(DS.Colors.textPrimary)
                            .onSubmit {
                                if !searchText.isEmpty {
                                    selectedModel = searchText
                                    isExpanded = false
                                }
                            }
                    } else {
                        // 收起时显示当前选择
                        Text(selectedModel.isEmpty ? placeholder : selectedModel)
                            .font(.system(size: 13))
                            .foregroundStyle(selectedModel.isEmpty ? DS.Colors.textSecondary : DS.Colors.textPrimary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(DS.Colors.rowHover)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isExpanded ? DS.Colors.accentPrimary.opacity(0.5) : Color.clear, lineWidth: 1)
                )
            })
            .buttonStyle(.plain)
            
            // 下拉列表
            if isExpanded {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // 模型列表
                        if filteredModels.isEmpty && !searchText.isEmpty {
                            // 搜索无结果时，允许使用输入的文本作为自定义模型
                            Button(action: {
                                selectedModel = searchText
                                isExpanded = false
                            }, label: {
                                HStack {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 12))
                                        .foregroundStyle(DS.Colors.accentPrimary)
                                    Text("使用 \"\(searchText)\"")
                                        .font(.system(size: 13))
                                        .foregroundStyle(DS.Colors.textPrimary)
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            })
                            .buttonStyle(.plain)
                        } else if filteredModels.isEmpty && availableModels.isEmpty && !isLoading {
                            // API 不支持或加载失败
                            Text("输入模型名称...")
                                .font(.system(size: 12))
                                .foregroundStyle(DS.Colors.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(filteredModels, id: \.self) { model in
                                Button(action: {
                                    selectedModel = model
                                    searchText = ""
                                    isExpanded = false
                                }, label: {
                                    HStack {
                                        Text(model)
                                            .font(.system(size: 13))
                                            .foregroundStyle(DS.Colors.textPrimary)
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        if model == selectedModel {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(DS.Colors.accentPrimary)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(model == selectedModel ? DS.Colors.rowHover : Color.clear)
                                    .contentShape(Rectangle())
                                })
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(DS.Colors.settingsCardBackground)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(DS.Colors.buttonHover, lineWidth: 1)
                )
                .padding(.top, 4)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isExpanded)
        .onChange(of: refreshTrigger) { _, _ in
            // API Key 更新后，重置并重新加载模型列表
            hasLoadedModels = false
            availableModels = []
            loadModels()
        }
    }
    
    private func toggleExpanded() {
        if !isExpanded {
            // 展开时加载模型列表
            isExpanded = true
            searchText = selectedModel // 预填当前选择
            
            if !hasLoadedModels {
                loadModels()
            }
        } else {
            // 收起时，如果有输入则使用输入值
            if !searchText.isEmpty && searchText != selectedModel {
                selectedModel = searchText
            }
            isExpanded = false
            searchText = ""
        }
    }
    
    private func loadModels() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            // 从 LLMSettings 获取最新的 profile（包含 API Key 引用）
            let currentProfile = LLMSettings.shared.profiles.first { $0.id == profile.id } ?? profile
            let models = await LLMSettings.shared.fetchModels(for: currentProfile)
            await MainActor.run {
                availableModels = models
                hasLoadedModels = true
                isLoading = false
            }
        }
    }
}

// MARK: - Add Service Button

struct AddServiceButton: View {
    let provider: LLMProviderType
    let action: () -> Void
    
    var body: some View {
        Button(action: action, label: {
            HStack(spacing: 8) {
                ProviderIconView(provider: provider, size: 24)
                
                Text(provider.displayName)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(DS.Colors.rowHover)
            .cornerRadius(DS.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(DS.Colors.buttonHover, lineWidth: 1)
            )
        })
        .buttonStyle(.plain)
    }
}

// MARK: - Profile API Key Sheet

struct ProfileAPIKeySheet: View {
    let profileName: String
    let providerType: LLMProviderType
    @Binding var apiKey: String
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    private var placeholder: String {
        switch providerType {
        case .googleGemini: return "AIza..."
        case .anthropic: return "sk-ant-..."
        case .openai: return "sk-..."
        case .groq: return "gsk_..."
        case .openRouter: return "sk-or-..."
        case .ollama: return "(可选)"
        case .openAICompatible: return "API Key"
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("设置 \(profileName) API Key")
                .font(.headline)
            
            SecureField(placeholder, text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
            
            Text("API Key 将安全存储在 macOS Keychain 中")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                Button("取消") { onCancel() }
                    .buttonStyle(.bordered)
                
                Button("保存") { onSave(apiKey) }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.isEmpty)
            }
        }
        .padding(30)
        .frame(width: 400)
    }
}

// MARK: - Shortcuts Settings
