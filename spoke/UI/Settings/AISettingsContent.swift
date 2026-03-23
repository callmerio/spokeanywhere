import SwiftUI

private typealias DS = DesignTokens

// MARK: - AI Settings (Screenium 风格单列布局)

@MainActor
struct AISettingsContentDependencies {
    let llmSettings: LLMSettings
    let appSettings: AppSettings
    let runConnectionTest: AISettingsConnectionTestRunner
}

enum AISettingsConnectionTestResult {
    case success
    case failure(String)
}

struct AISettingsContent: View {
    typealias TestResult = AISettingsConnectionTestResult

    @State private var llmSettings: LLMSettings
    @State private var showingAPIKeyInput = false
    @State private var apiKeyInput = ""
    @State private var expandedProfileId: UUID?
    @State private var isTesting = false
    @State private var testResult: TestResult?
    @State private var showConflictAlert = false
    @State private var showDeleteConfirm = false
    @State private var profileToDelete: UUID?
    @State private var modelRefreshTrigger = UUID() // 用于触发模型列表刷新
    @ObservedObject private var appSettings: AppSettings

    private let runConnectionTest: AISettingsConnectionTestRunner

    @MainActor
    init(
        dependencies: AISettingsContentDependencies
    ) {
        self._llmSettings = State(initialValue: dependencies.llmSettings)
        self.appSettings = dependencies.appSettings
        self.runConnectionTest = dependencies.runConnectionTest
    }

    @MainActor
    init() {
        self.init(dependencies: .live)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 启用开关
            SettingsCard {
                SettingsRow(icon: "sparkles", title: "启用 AI 处理", description: "语音转写后自动使用 AI 精炼文本") {
                    Toggle("", isOn: Binding(
                        get: { llmSettings.isEnabled },
                        set: { newValue in
                            if newValue && appSettings.realtimeTypingEnabled {
                                showConflictAlert = true
                            } else {
                                llmSettings.isEnabled = newValue
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .tint(DS.Colors.accentPrimary)
                }
            }
            .alert("冲突提示", isPresented: $showConflictAlert) {
                Button("关闭实时上屏并开启 AI") {
                    appSettings.realtimeTypingEnabled = false
                    llmSettings.isEnabled = true
                }
                Button("保持两者开启") { llmSettings.isEnabled = true }
                Button("取消", role: .cancel) {}
            } message: {
                Text("开启 AI 处理后，实时上屏会先输出原始转写，AI 完成后会再次输出精炼文本。\n\n建议关闭实时上屏，仅使用 AI 输出的最终结果。")
            }
            
            if llmSettings.isEnabled {
                // 已配置的服务列表
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(llmSettings.profiles) { profile in
                        ServiceCardRow(
                            profile: binding(for: profile),
                            isExpanded: expandedProfileId == profile.id,
                            isActive: llmSettings.selectedProfileId == profile.id,
                            isTranscription: llmSettings.transcriptionProfileId == profile.id,
                            isChat: llmSettings.chatProfileId == profile.id,
                            isSummary: llmSettings.summaryProfileId == profile.id,
                            hasAPIKey: llmSettings.hasAPIKey(for: profile.id),
                            modelRefreshTrigger: modelRefreshTrigger,
                            isTesting: expandedProfileId == profile.id ? $isTesting : .constant(false),
                            testResult: expandedProfileId == profile.id ? $testResult : .constant(nil),
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if expandedProfileId == profile.id {
                                        expandedProfileId = nil
                                    } else {
                                        expandedProfileId = profile.id
                                        testResult = nil
                                    }
                                }
                            },
                            onSetActive: {
                                llmSettings.selectedProfileId = profile.id
                            },
                            onSetTranscription: {
                                llmSettings.transcriptionProfileId = profile.id
                            },
                            onSetChat: {
                                llmSettings.chatProfileId = profile.id
                            },
                            onSetSummary: {
                                llmSettings.summaryProfileId = profile.id
                            },
                            onSetAPIKey: {
                                apiKeyInput = ""
                                llmSettings.selectedProfileId = profile.id
                                showingAPIKeyInput = true
                            },
                            onTest: { testConnection(for: profile) },
                            onDelete: {
                                profileToDelete = profile.id
                                showDeleteConfirm = true
                            },
                            onDuplicate: {
                                if let newProfile = llmSettings.duplicateProfile(profile.id) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        expandedProfileId = newProfile.id
                                    }
                                }
                            },
                            getAPIKey: {
                                llmSettings.getAPIKey(for: profile.id)
                            }
                        )
                    }
                }
                .background(Color(hex: "1e1e1e"))
                .cornerRadius(DS.CornerRadius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(DS.Colors.settingsCardBorder, lineWidth: 1)
                )
                
                // 添加服务区域
                VStack(alignment: .leading, spacing: 12) {
                    Text("添加服务")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.Colors.textSecondary)
                        .padding(.leading, 4)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ], spacing: 10) {
                        ForEach(LLMProviderType.allCases) { provider in
                            AddServiceButton(
                                provider: provider,
                                action: { createProfile(for: provider) }
                            )
                        }
                    }
                }
                
                // 底部选项
                VStack(alignment: .leading, spacing: 16) {
                    RefineSettingsCard(llmSettings: llmSettings)
                    QuickAskSettingsCard(llmSettings: llmSettings)
                }
            }
        }
        .sheet(isPresented: $showingAPIKeyInput) {
            if let profileId = llmSettings.selectedProfileId,
               let profile = llmSettings.selectedProfile {
                ProfileAPIKeySheet(
                    profileName: profile.name,
                    providerType: profile.providerType,
                    apiKey: $apiKeyInput,
                    onSave: { key in
                        try? llmSettings.setAPIKey(key, for: profileId)
                        showingAPIKeyInput = false
                        // 保存后触发模型列表刷新
                        modelRefreshTrigger = UUID()
                    },
                    onCancel: { showingAPIKeyInput = false }
                )
            }
        }
        .alert("确认删除", isPresented: $showDeleteConfirm) {
            Button("删除", role: .destructive) {
                if let id = profileToDelete {
                    if expandedProfileId == id {
                        expandedProfileId = nil
                    }
                    llmSettings.deleteProfile(id)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要删除这个配置文件吗？此操作不可撤销。")
        }
    }
    
    // MARK: - Helpers
    
    private func binding(for profile: ProviderProfile) -> Binding<ProviderProfile> {
        Binding(
            get: { llmSettings.profiles.first { $0.id == profile.id } ?? profile },
            set: { llmSettings.updateProfile($0) }
        )
    }
    
    private func createProfile(for type: LLMProviderType) {
        let existingCount = llmSettings.profilesByProvider[type]?.count ?? 0
        let name = existingCount > 0 ? "\(type.displayName) \(existingCount + 1)" : type.displayName
        let profile = llmSettings.createProfile(for: type, name: name)
        withAnimation(.easeInOut(duration: 0.2)) {
            expandedProfileId = profile.id
        }
    }
    
    private func testConnection(for profile: ProviderProfile) {
        runConnectionTest(profile, llmSettings) { isTesting, result in
            self.isTesting = isTesting
            self.testResult = result
        }
    }
}
