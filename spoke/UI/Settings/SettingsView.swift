import SwiftUI
import AVFoundation
import SwiftData
import AppKit

// MARK: - Main Settings View

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    @StateObject private var audioManager = AudioDeviceManager()
    @StateObject private var appSettings = AppSettings()
    @StateObject private var micTester = MicrophoneTester()
    
    enum SettingsTab: String, CaseIterable {
        case general = "常规"
        case model = "听写模型"
        case ai = "AI 处理"
        case tts = "语音合成"
        case shortcuts = "快捷键"
        case history = "历史记录"
        
        var icon: String {
            switch self {
            case .general: return "gear"
            case .model: return "waveform"
            case .ai: return "sparkles"
            case .tts: return "speaker.wave.2"
            case .shortcuts: return "keyboard"
            case .history: return "clock.arrow.circlepath"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧导航
            sideBar
            
            // 右侧内容
            contentArea
        }
        .frame(minWidth: 820, minHeight: 580)
        .background(Color(hex: "1a1a1a"))
    }
    
    // MARK: - Sidebar
    
    private var sideBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 顶部留白（为红绿灯）- 减少高度
            Spacer().frame(height: 20)
            
            // App 标题
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .semibold))
                Text("SpokenAnyWhere")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                SidebarButton(
                    title: tab.rawValue,
                    icon: tab.icon,
                    isSelected: selectedTab == tab
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                }
            }
            
            Spacer()
        }
        .frame(width: 180)
        .background(Color(hex: "141414"))
    }
    
    // MARK: - Content Area
    
    @ViewBuilder
    private var contentArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch selectedTab {
                case .general:
                    GeneralSettingsContent(
                        appSettings: appSettings,
                        audioManager: audioManager,
                        micTester: micTester
                    )
                case .model:
                    ModelsSettingsContent()
                case .ai:
                    AISettingsContent()
                case .tts:
                    TTSSettingsContent()
                case .shortcuts:
                    ShortcutsSettingsContent(appSettings: appSettings)
                case .history:
                    HistorySettingsContent()
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 28) // 减少顶部空间
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "1a1a1a"))
    }
}

// MARK: - Sidebar Button

struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 13))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
            .foregroundStyle(isSelected ? .white : .gray)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
}

// MARK: - Settings Card

struct SettingsCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(16)
        .background(Color(hex: "252525"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Settings Row

struct SettingsRow<Trailing: View>: View {
    let icon: String
    let title: String
    let description: String?
    let trailing: Trailing
    
    init(icon: String, title: String, description: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.icon = icon
        self.title = title
        self.description = description
        self.trailing = trailing()
    }
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.gray)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                
                if let desc = description {
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)
                }
            }
            
            Spacer()
            
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - General Settings

struct GeneralSettingsContent: View {
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var audioManager: AudioDeviceManager
    @ObservedObject var micTester: MicrophoneTester
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 启动与行为
            Text("启动与行为")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.gray)
                .padding(.leading, 4)
            
            SettingsCard {
                SettingsRow(icon: "power", title: "开机自动启动", description: "登录时自动启动 SpokenAnyWhere") {
                    Toggle("", isOn: $appSettings.startAtLogin)
                        .toggleStyle(.switch)
                        .tint(.blue)
                }
                
                Divider().background(Color.white.opacity(0.06))
                
                SettingsRow(icon: "dock.rectangle", title: "在程序坞中显示") {
                    Toggle("", isOn: $appSettings.showInDock)
                        .toggleStyle(.switch)
                        .tint(.blue)
                }
                
                Divider().background(Color.white.opacity(0.06))
                
                SettingsRow(icon: "menubar.rectangle", title: "在菜单栏中显示图标") {
                    Toggle("", isOn: $appSettings.showInMenuBar)
                        .toggleStyle(.switch)
                        .tint(.blue)
                }
                
                Divider().background(Color.white.opacity(0.06))
                
                SettingsRow(icon: "escape", title: "按 ESC 键取消录音") {
                    Toggle("", isOn: $appSettings.pressEscToCancel)
                        .toggleStyle(.switch)
                        .tint(.blue)
                }
                
                Divider().background(Color.white.opacity(0.06))
                
                SettingsRow(icon: "speaker.wave.2", title: "播放提示音效", description: "开始/结束录音时播放声音") {
                    Toggle("", isOn: $appSettings.playSoundEffect)
                        .toggleStyle(.switch)
                        .tint(.blue)
                }
            }
            
            // 音频设置
            Text("音频设置")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.gray)
                .padding(.leading, 4)
                .padding(.top, 8)
            
            SettingsCard {
                SettingsRow(icon: "mic", title: "麦克风输入", description: "选择用于录音的麦克风设备") {
                    Picker("", selection: $audioManager.currentInputDeviceId) {
                        ForEach(audioManager.devices) { device in
                            Text(device.name).tag(device.id as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 180)
                    .tint(.white)
                }
                
                Divider().background(Color.white.opacity(0.06))
                
                // 真实麦克风测试
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 14) {
                        Image(systemName: "waveform")
                            .font(.system(size: 16))
                            .foregroundStyle(.gray)
                            .frame(width: 24)
                        
                        Text("麦克风测试")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        Button(micTester.isRunning ? "停止" : "测试") {
                            if micTester.isRunning {
                                micTester.stop()
                            } else {
                                micTester.start()
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(micTester.isRunning ? .red : .blue)
                    }
                    
                    // 音量条 - macOS 原生风格 (长条疏朗版)
                    HStack(spacing: 5) {
                        ForEach(0..<20) { index in
                            Capsule()
                                .fill(
                                    // 根据音量决定是否点亮
                                    (Float(index) / 20.0) < micTester.level ? Color.white : Color.white.opacity(0.2)
                                )
                                .frame(width: 6, height: 12)
                                .animation(.interactiveSpring(response: 0.1, dampingFraction: 0.5), value: micTester.level)
                        }
                    }
                    .padding(.leading, 38)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .onAppear {
            audioManager.refreshDevices()
        }
        .onDisappear {
            micTester.stop()
        }
    }
}

// MARK: - Models Settings

struct ModelsSettingsContent: View {
    @AppStorage("SelectedDictationModel") private var selectedModel: String = "apple_ondevice"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("语音转文字引擎")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.gray)
                .padding(.leading, 4)
            
            SettingsCard {
                ModelOptionRow(
                    icon: "apple.logo",
                    title: "Apple Dictation",
                    description: "系统内置，离线可用，隐私安全",
                    isSelected: selectedModel == "apple_ondevice",
                    isAvailable: true
                ) {
                    selectedModel = "apple_ondevice"
                }
                
                Divider().background(Color.white.opacity(0.06))
                
                ModelOptionRow(
                    icon: "cloud",
                    title: "OpenAI Whisper",
                    description: "云端处理，高精度，需要 API Key",
                    isSelected: selectedModel == "openai_whisper",
                    isAvailable: false,
                    comingSoon: true
                ) {
                    // Coming soon
                }
                
                Divider().background(Color.white.opacity(0.06))
                
                ModelOptionRow(
                    icon: "cpu",
                    title: "Whisper.cpp 本地",
                    description: "本地 CoreML 模型，完全离线",
                    isSelected: selectedModel == "local_whisper",
                    isAvailable: false,
                    comingSoon: true
                ) {
                    // Coming soon
                }
            }
        }
    }
}

struct ModelOptionRow: View {
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool
    let isAvailable: Bool
    var comingSoon: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isAvailable ? .gray : .gray.opacity(0.5))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(isAvailable ? .white : .gray)
                        
                        if comingSoon {
                            Text("Coming Soon")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.gray)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(.gray.opacity(0.7))
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
    }
}

// MARK: - AI Settings (Screenium 风格单列布局)

struct AISettingsContent: View {
    @State private var llmSettings = LLMSettings.shared
    @State private var showingAPIKeyInput = false
    @State private var apiKeyInput = ""
    @State private var expandedProfileId: UUID?
    @State private var isTesting = false
    @State private var testResult: TestResult?
    @State private var showConflictAlert = false
    @State private var showDeleteConfirm = false
    @State private var profileToDelete: UUID?
    @State private var modelRefreshTrigger = UUID() // 用于触发模型列表刷新
    @ObservedObject var appSettings = AppSettings.shared
    
    enum TestResult {
        case success
        case failure(String)
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
                    .tint(.blue)
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
                            onSetAPIKey: {
                                apiKeyInput = ""
                                llmSettings.selectedProfileId = profile.id
                                showingAPIKeyInput = true
                            },
                            onTest: { testConnection(for: profile) },
                            onDelete: {
                                profileToDelete = profile.id
                                showDeleteConfirm = true
                            }
                        )
                    }
                }
                .background(Color(hex: "1e1e1e"))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )
                
                // 添加服务区域
                VStack(alignment: .leading, spacing: 12) {
                    Text("添加服务")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.gray)
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
                bottomOptionsSection
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
    
    // MARK: - 底部选项
    
    private var bottomOptionsSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                // 系统提示词（可折叠）
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        TextEditor(text: Binding(
                            get: { llmSettings.systemPrompt },
                            set: { llmSettings.systemPrompt = $0 }
                        ))
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .scrollContentBackground(.hidden)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                        .frame(height: 80)
                        
                        HStack {
                            Button("重置为默认") {
                                llmSettings.resetToDefaultPrompt()
                            }
                            .buttonStyle(.bordered)
                            .tint(.gray)
                            .controlSize(.small)
                            
                            Spacer()
                            
                            Text("\(llmSettings.systemPrompt.count) 字符")
                                .font(.system(size: 11))
                                .foregroundStyle(.gray)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Label("系统提示词", systemImage: "text.quote")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                }
                .tint(.gray)
                
                Divider().background(Color.white.opacity(0.06))
                
                // 上下文选项
                HStack(spacing: 24) {
                    Toggle(isOn: Binding(
                        get: { llmSettings.includeActiveApp },
                        set: { llmSettings.includeActiveApp = $0 }
                    )) {
                        Label("包含当前应用", systemImage: "app.badge")
                            .font(.system(size: 12))
                    }
                    .toggleStyle(.switch)
                    .tint(.blue)
                    
                    Toggle(isOn: Binding(
                        get: { llmSettings.includeClipboard },
                        set: { llmSettings.includeClipboard = $0 }
                    )) {
                        Label("包含剪贴板", systemImage: "doc.on.clipboard")
                            .font(.system(size: 12))
                    }
                    .toggleStyle(.switch)
                    .tint(.blue)
                }
            }
            .padding(16)
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
        guard let provider = llmSettings.createProvider(for: profile) else {
            testResult = .failure("未配置")
            return
        }
        
        isTesting = true
        testResult = nil
        
        Task {
            do {
                let success = try await provider.testConnection()
                await MainActor.run {
                    isTesting = false
                    testResult = success ? .success : .failure("连接失败")
                }
            } catch let error as LLMError {
                await MainActor.run {
                    isTesting = false
                    testResult = .failure(error.localizedDescription)
                }
            } catch {
                await MainActor.run {
                    isTesting = false
                    testResult = .failure("未知错误: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Service Card Row (可展开卡片)

struct ServiceCardRow: View {
    @Binding var profile: ProviderProfile
    let isExpanded: Bool
    let isActive: Bool
    let isTranscription: Bool
    let isChat: Bool
    let hasAPIKey: Bool
    let modelRefreshTrigger: UUID
    @Binding var isTesting: Bool
    @Binding var testResult: AISettingsContent.TestResult?
    let onTap: () -> Void
    let onSetActive: () -> Void
    let onSetTranscription: () -> Void
    let onSetChat: () -> Void
    let onSetAPIKey: () -> Void
    let onTest: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 主行（始终显示）
            HStack(spacing: 12) {
                // Provider 图标
                ProviderIconView(provider: profile.providerType, size: 32)
                
                // 名称和副标题
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                    
                    Text(profile.modelName.isEmpty ? profile.providerType.displayName : profile.modelName)
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                }
                
                // Badges
                HStack(spacing: 4) {
                    if isTranscription {
                        Text("转录")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(4)
                    }
                    
                    if isChat {
                        Text("对话")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.8))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // 配置按钮
                Button(action: onTap) {
                    Text(isExpanded ? "完成" : "配置")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(isExpanded ? Color.blue : Color.white.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // 展开的配置区域
            if isExpanded {
                Divider().background(Color.white.opacity(0.06))
                
                expandedContent
            }
        }
        .contextMenu {
            Button(action: onSetTranscription) {
                Label("设为转录模型", systemImage: "waveform")
            }
            
            Button(action: onSetChat) {
                Label("设为对话模型", systemImage: "bubble.left.and.bubble.right")
            }
            
            Divider()
            
            Button(action: onSetActive) {
                Label("设为默认", systemImage: "checkmark.circle")
            }
        }
    }
    
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 配置名称
            configRow(title: "名称") {
                TextField("配置名称", text: $profile.name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(6)
            }
            
            // API Key
            if profile.providerType.requiresAPIKey {
                configRow(title: "API Key") {
                    HStack {
                        if hasAPIKey {
                            HStack(spacing: 4) {
                                ForEach(0..<30, id: \.self) { _ in
                                    Circle()
                                        .fill(Color.white.opacity(0.6))
                                        .frame(width: 4, height: 4)
                                }
                            }
                            
                            Button(action: {}) {
                                Image(systemName: "eye.slash")
                                    .foregroundStyle(.gray)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("未配置")
                                .font(.system(size: 13))
                                .foregroundStyle(.orange)
                        }
                        
                        Spacer()
                        
                        Button(hasAPIKey ? "修改" : "设置") {
                            onSetAPIKey()
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.blue)
                        .buttonStyle(.plain)
                    }
                }
                
                // 官方文档链接
                if let docURL = providerDocURL {
                    HStack {
                        Spacer()
                        Link(destination: docURL) {
                            HStack(spacing: 4) {
                                Text("获取 API Key")
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.system(size: 11))
                            .foregroundStyle(.blue)
                        }
                    }
                    .padding(.top, -8)
                }
            }
            
            // 模型选择（智能下拉 + 手动输入）
            configRow(title: "模型") {
                ModelPickerView(
                    selectedModel: $profile.modelName,
                    profile: profile,
                    placeholder: profile.providerType.defaultModel,
                    refreshTrigger: modelRefreshTrigger
                )
            }
            
            // API 地址（仅当不是默认地址时显示）
            configRow(title: "API 地址") {
                TextField(profile.providerType.defaultBaseURL.isEmpty ? "https://api.example.com/v1" : profile.providerType.defaultBaseURL, text: $profile.baseURL)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(6)
            }
            
            Divider().background(Color.white.opacity(0.06))
            
            // 底部操作栏
            HStack {
                // 测试连接
                Button(action: onTest) {
                    HStack(spacing: 6) {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "network")
                                .font(.system(size: 12))
                        }
                        Text(isTesting ? "测试中..." : "测试连接")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(isTesting)
                
                if let result = testResult {
                    HStack(spacing: 4) {
                        switch result {
                        case .success:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("连接成功")
                                .foregroundStyle(.green)
                        case .failure(let msg):
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text(msg)
                                .foregroundStyle(.red)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .help(msg)
                        }
                    }
                    .font(.system(size: 11))
                }
                
                Spacer()
                
                // 删除按钮
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.8))
                        .padding(8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.02))
    }
    
    private func configRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.gray)
                .frame(width: 70, alignment: .leading)
            
            content()
        }
    }
    
    private var providerDocURL: URL? {
        switch profile.providerType {
        case .openai:
            return URL(string: "https://platform.openai.com/api-keys")
        case .anthropic:
            return URL(string: "https://console.anthropic.com/settings/keys")
        case .googleGemini:
            return URL(string: "https://aistudio.google.com/app/apikey")
        case .groq:
            return URL(string: "https://console.groq.com/keys")
        case .openRouter:
            return URL(string: "https://openrouter.ai/keys")
        case .ollama, .openAICompatible:
            return nil
        }
    }
}

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
        case .ollama: return .white
        case .openai: return .green
        case .anthropic: return .orange
        case .googleGemini: return .blue
        case .groq: return .orange
        case .openRouter: return .purple
        case .openAICompatible: return .gray
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
            Button(action: { toggleExpanded() }) {
                HStack {
                    if isExpanded {
                        // 展开时显示搜索框
                        TextField(placeholder, text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
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
                            .foregroundStyle(selectedModel.isEmpty ? .gray : .white)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.gray)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isExpanded ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
                )
            }
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
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.blue)
                                    Text("使用 \"\(searchText)\"")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.white)
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        } else if filteredModels.isEmpty && availableModels.isEmpty && !isLoading {
                            // API 不支持或加载失败
                            Text("输入模型名称...")
                                .font(.system(size: 12))
                                .foregroundStyle(.gray)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(filteredModels, id: \.self) { model in
                                Button(action: {
                                    selectedModel = model
                                    searchText = ""
                                    isExpanded = false
                                }) {
                                    HStack {
                                        Text(model)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        if model == selectedModel {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(model == selectedModel ? Color.white.opacity(0.05) : Color.clear)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color(hex: "252525"))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
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
        Button(action: action) {
            HStack(spacing: 8) {
                ProviderIconView(provider: provider, size: 24)
                
                Text(provider.displayName)
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
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

struct ShortcutsSettingsContent: View {
    @ObservedObject var appSettings: AppSettings
    @State private var isRecordingShortcut = false
    @State private var isRecordingQuickAskShortcut = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("全局快捷键")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.gray)
                .padding(.leading, 4)
            
            SettingsCard {
                SettingsRow(icon: "record.circle", title: "触发录音", description: "按下快捷键开始/停止录音") {
                    ShortcutRecorderButton(
                        isRecording: $isRecordingShortcut,
                        currentShortcut: appSettings.shortcutDisplayString,
                        onShortcutCaptured: { keyCode, modifiers in
                            appSettings.updateShortcut(keyCode: keyCode, modifiers: modifiers)
                        }
                    )
                }
                
                Divider().background(Color.white.opacity(0.06))
                
                SettingsRow(icon: "bubble.left.and.bubble.right", title: "Quick Ask", description: "快速向 AI 提问") {
                    ShortcutRecorderButton(
                        isRecording: $isRecordingQuickAskShortcut,
                        currentShortcut: appSettings.quickAskShortcutDisplayString,
                        onShortcutCaptured: { keyCode, modifiers in
                            appSettings.updateQuickAskShortcut(keyCode: keyCode, modifiers: modifiers)
                        }
                    )
                }
                
                Divider().background(Color.white.opacity(0.06))
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        Image(systemName: "hand.tap")
                            .font(.system(size: 16))
                            .foregroundStyle(.gray)
                            .frame(width: 24)
                        
                        Text("触发模式")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    
                    Picker("", selection: $appSettings.recordingMode) {
                        ForEach(AppSettings.RecordingMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.leading, 38)
                    
                    Text("智能混合：短按切换录音状态，长按保持录音（松开结束）")
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)
                        .padding(.leading, 38)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // 边说边打字
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $appSettings.realtimeTypingEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "keyboard")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("边说边打字")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white)
                                
                                Text("实时将语音转录输入到当前应用")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                    .toggleStyle(.switch)
                    
                    if appSettings.realtimeTypingEnabled {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                            Text("开启后，语音转录将直接输入到光标位置，HUD 仅显示波形")
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(.orange.opacity(0.8))
                        .padding(.leading, 38)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }
}

// MARK: - Shortcut Recorder Button

struct ShortcutRecorderButton: View {
    @Binding var isRecording: Bool
    let currentShortcut: String
    let onShortcutCaptured: (Int, Int) -> Void
    
    @State private var eventMonitor: Any?
    
    var body: some View {
        Button(action: { toggleRecording() }) {
            Text(isRecording ? "输入快捷键..." : currentShortcut)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isRecording ? Color.accentColor.opacity(0.3) : Color.white.opacity(0.1))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onDisappear {
            stopRecording()
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        
        // 使用 NSEvent.addLocalMonitorForEvents 监听键盘事件
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            
            // Escape 取消录制
            if event.keyCode == 53 {
                self.stopRecording()
                return nil
            }
            
            // 必须有修饰键
            guard !modifiers.isEmpty else { return event }
            
            // 忽略纯修饰键按下
            let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
            if modifierKeyCodes.contains(event.keyCode) { return event }
            
            // 捕获快捷键
            let keyCode = Int(event.keyCode)
            let modifiersRaw = Int(modifiers.rawValue)
            
            self.onShortcutCaptured(keyCode, modifiersRaw)
            self.stopRecording()
            
            return nil
        }
    }
    
    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

// MARK: - History Settings

struct HistorySettingsContent: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HistoryItem.createdAt, order: .reverse) private var historyItems: [HistoryItem]
    @State private var searchText = ""
    
    /// 按日期分组的历史记录
    private var groupedItems: [(String, [HistoryItem])] {
        let filtered = historyItems.filter { item in
            searchText.isEmpty || item.rawText.localizedCaseInsensitiveContains(searchText)
        }
        
        let grouped = Dictionary(grouping: filtered) { item -> String in
            let calendar = Calendar.current
            if calendar.isDateInToday(item.createdAt) {
                return "今天"
            } else if calendar.isDateInYesterday(item.createdAt) {
                return "昨天"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy年M月d日"
                return formatter.string(from: item.createdAt)
            }
        }
        
        // 按日期排序（今天 > 昨天 > 具体日期倒序）
        return grouped.sorted { lhs, rhs in
            if lhs.key == "今天" { return true }
            if rhs.key == "今天" { return false }
            if lhs.key == "昨天" { return true }
            if rhs.key == "昨天" { return false }
            return lhs.key > rhs.key
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 搜索栏
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.gray)
                TextField("搜索", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
            }
            .padding(10)
            .background(Color(hex: "252525"))
            .cornerRadius(8)
            .padding(.bottom, 20)
            
            // 列表
            if historyItems.isEmpty {
                emptyStateView
            } else if groupedItems.isEmpty {
                noResultsView
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(groupedItems, id: \.0) { dateString, items in
                            VStack(alignment: .leading, spacing: 12) {
                                // 日期分组标题
                                Text(dateString)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.top, 4)
                                
                                // 该日期下的记录
                                VStack(spacing: 8) {
                                    ForEach(items) { item in
                                        HistoryItemRow(
                                            item: item,
                                            onDelete: { deleteItem(item) }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 40))
                .foregroundStyle(.gray.opacity(0.4))
            Text("还没有录音记录")
                .font(.system(size: 14))
                .foregroundStyle(.gray)
            Text("使用快捷键开始录音后，记录会显示在这里")
                .font(.system(size: 12))
                .foregroundStyle(.gray.opacity(0.6))
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.gray.opacity(0.4))
            Text("没有找到匹配的记录")
                .font(.system(size: 14))
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private func deleteItem(_ item: HistoryItem) {
        // 删除音频文件
        if let audioPath = item.audioPath {
            let audioURL = HistoryManager.shared.audioStorageURL.appendingPathComponent(audioPath)
            try? FileManager.default.removeItem(at: audioURL)
        }
        modelContext.delete(item)
    }
}

// MARK: - Reprocess Sheet

struct ReprocessSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: HistoryItem
    
    @State private var customPrompt = ""
    @State private var isProcessing = false
    @State private var resultText: String?
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题
            HStack {
                Text("重新处理")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.gray)
                }
                .buttonStyle(.plain)
            }
            
            // 原始文本预览
            VStack(alignment: .leading, spacing: 8) {
                Text("原始文本")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.gray)
                Text(item.rawText)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(3)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
            }
            
            // 自定义 Prompt 输入
            VStack(alignment: .leading, spacing: 8) {
                Text("自定义指令（可选）")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.gray)
                TextEditor(text: $customPrompt)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(height: 80)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                Text("留空则使用当前系统 Prompt")
                    .font(.system(size: 11))
                    .foregroundStyle(.gray.opacity(0.6))
            }
            
            // 结果显示
            if let result = resultText {
                VStack(alignment: .leading, spacing: 8) {
                    Text("处理结果")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.green)
                    Text(result)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        .textSelection(.enabled)
                }
            }
            
            // 错误信息
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
            
            Spacer()
            
            // 操作按钮
            HStack(spacing: 12) {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                
                Button(action: reprocess) {
                    HStack(spacing: 6) {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isProcessing ? "处理中..." : "重新处理")
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(hex: "a78bfa"))
                .foregroundStyle(.white)
                .cornerRadius(8)
                .disabled(isProcessing)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .frame(width: 400, height: 420)
        .background(Color(hex: "252525"))
    }
    
    private func reprocess() {
        isProcessing = true
        errorMessage = nil
        resultText = nil
        
        Task {
            let prompt = customPrompt.isEmpty ? nil : customPrompt
            let result = await HistoryManager.shared.reprocess(item, with: prompt ?? LLMSettings.shared.systemPrompt)
            
            await MainActor.run {
                isProcessing = false
                switch result {
                case .success(let text):
                    resultText = text
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct HistoryItemRow: View {
    let item: HistoryItem
    var onDelete: () -> Void
    
    @ObservedObject private var audioPlayer = AudioPlayerService.shared
    @State private var isHovering = false
    @State private var showCopied = false
    @State private var isReprocessing = false
    
    /// 当前是否正在播放此条目的音频
    private var isPlayingThis: Bool {
        guard let audioPath = item.audioPath else { return false }
        let url = HistoryManager.shared.audioStorageURL.appendingPathComponent(audioPath)
        return audioPlayer.isPlaying(url: url)
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "a h:mm"
        formatter.amSymbol = "上午"
        formatter.pmSymbol = "下午"
        return formatter.string(from: item.createdAt)
    }
    
    private var displayText: String {
        item.processedText ?? item.rawText
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // 左侧：时间戳 + 内容
            VStack(alignment: .leading, spacing: 8) {
                // 时间戳
                Text(timeString)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.gray.opacity(0.7))
                
                // 内容
                Text(displayText)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(4)
                    .lineSpacing(3)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // 右侧：操作按钮
            HStack(spacing: 10) {
                // 复制按钮 - 更透明磨砂
                Button(action: copyToClipboard) {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13))
                        .foregroundStyle(showCopied ? .green : .white.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help("复制")
                
                // 播放按钮 - 蓝色透明磨砂
                Button(action: togglePlay) {
                    Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "5a9fd4"))
                        .frame(width: 32, height: 32)
                        .background(Color(hex: "5a9fd4").opacity(isPlayingThis ? 0.25 : 0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help(isPlayingThis ? "暂停" : "播放")
                .opacity(item.audioPath != nil ? 1 : 0.3)
                .disabled(item.audioPath == nil)
                
                // 重处理按钮 - 紫色透明磨砂
                Button(action: reprocess) {
                    Group {
                        if isReprocessing {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 13, height: 13)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13))
                        }
                    }
                    .foregroundStyle(Color(hex: "a78bfa"))
                    .frame(width: 32, height: 32)
                    .background(Color(hex: "a78bfa").opacity(isReprocessing ? 0.25 : 0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help("重新处理")
                .disabled(isReprocessing)
                
                // 删除按钮 - 红色透明磨砂
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "ff6b6b"))
                        .frame(width: 32, height: 32)
                        .background(Color(hex: "ff4444").opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help("删除")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(hex: "2a2a2a"))
        .cornerRadius(12)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(displayText, forType: .string)
        
        withAnimation {
            showCopied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopied = false
            }
        }
    }
    
    private func togglePlay() {
        guard let audioPath = item.audioPath else { return }
        let url = HistoryManager.shared.audioStorageURL.appendingPathComponent(audioPath)
        
        if isPlayingThis {
            // 正在播放此条目，暂停
            audioPlayer.pause()
        } else if audioPlayer.currentURL == url {
            // 暂停了此条目，继续播放
            audioPlayer.resume()
        } else {
            // 播放新的音频
            do {
                try audioPlayer.play(url)
            } catch {
                print("❌ 播放失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func reprocess() {
        isReprocessing = true
        
        Task {
            // 使用当前系统 Prompt 重处理
            let result = await HistoryManager.shared.reprocess(item, with: LLMSettings.shared.systemPrompt)
            
            await MainActor.run {
                isReprocessing = false
                
                switch result {
                case .success:
                    // 成功后 item.processedText 已更新，SwiftData 会自动刷新 UI
                    break
                case .failure(let error):
                    print("❌ 重处理失败: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("History Item Row") {
    let item = HistoryItem(
        rawText: "这是一段测试文本，用来预览历史记录行的样式效果。",
        processedText: "这是经过 LLM 处理后的文本，用来预览历史记录行的样式效果。",
        audioPath: "test.caf"
    )
    
    return VStack(spacing: 12) {
        HistoryItemRow(item: item, onDelete: {})
        
        HistoryItemRow(
            item: HistoryItem(rawText: "短文本测试"),
            onDelete: {}
        )
        
        HistoryItemRow(
            item: HistoryItem(
                rawText: "这是一段很长很长的文本，用来测试多行显示的效果。这是一段很长很长的文本，用来测试多行显示的效果。这是一段很长很长的文本，用来测试多行显示的效果。",
                audioPath: nil
            ),
            onDelete: {}
        )
    }
    .padding()
    .background(Color(hex: "1a1a1a"))
}

#Preview("History Settings") {
    HistorySettingsContent()
        .frame(width: 500, height: 400)
        .background(Color(hex: "1a1a1a"))
        .modelContainer(for: HistoryItem.self, inMemory: true)
}

// MARK: - Microphone Tester

@MainActor
class MicrophoneTester: ObservableObject {
    @Published var level: Float = 0
    @Published var isRunning = false
    
    private var audioEngine: AVAudioEngine?
    
    func start() {
        guard !isRunning else { return }
        
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }
        
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }
        
        do {
            try engine.start()
            isRunning = true
        } catch {
            print("❌ Failed to start audio engine: \(error)")
        }
    }
    
    func stop() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRunning = false
        level = 0
    }
    
    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        var sumSquares: Float = 0
        
        for i in stride(from: 0, to: frameLength, by: 4) {
            let sample = channelData[i]
            sumSquares += sample * sample
        }
        
        let rms = sqrt(sumSquares / Float(frameLength / 4))
        let newLevel = min((rms * 5.0) + (sqrt(rms) * 2.0), 1.0)
        
        Task { @MainActor in
            self.level = newLevel
        }
    }
}

// MARK: - TTS Settings

struct TTSSettingsContent: View {
    @ObservedObject private var settings = TTSSettings.shared
    @ObservedObject private var ttsService = TTSService.shared
    @State private var isTesting = false
    @State private var testText = "你好，这是语音合成测试。Hello, this is a TTS test."
    @State private var testStartTime: Date?
    @State private var latencyMs: Int?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 服务选择
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("语音合成服务")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    ForEach(TTSProvider.allCases, id: \.self) { provider in
                        TTSProviderRow(
                            provider: provider,
                            isSelected: settings.provider == provider,
                            onSelect: { settings.provider = provider }
                        )
                    }
                }
            }
            
            // Edge TTS 配置
            if settings.provider == .edge {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 20) {
                        // 标题区
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Edge TTS 配置")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                            
                            Text("使用微软 Edge 浏览器的 TTS 服务，免费且音质好")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider().opacity(0.3)
                        
                        // 语音选择
                        VStack(alignment: .leading, spacing: 8) {
                            Text("语音角色")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                            
                            Picker("", selection: $settings.edgeVoice) {
                                ForEach(EdgeVoice.allCases, id: \.self) { voice in
                                    Text(voice.displayName).tag(voice)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // 语速
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("语速")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.9))
                                
                                Spacer()
                                
                                Text("\(settings.edgeRate >= 0 ? "+" : "")\(settings.edgeRate)%")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.15))
                                    .cornerRadius(4)
                            }
                            
                            Slider(value: Binding(
                                get: { Double(settings.edgeRate) },
                                set: { settings.edgeRate = Int($0) }
                            ), in: -50...100, step: 10)
                            .tint(.blue)
                        }
                        
                        // 音调
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("音调")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.9))
                                
                                Spacer()
                                
                                Text("\(settings.edgePitch >= 0 ? "+" : "")\(settings.edgePitch)Hz")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.purple)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.15))
                                    .cornerRadius(4)
                            }
                            
                            Slider(value: Binding(
                                get: { Double(settings.edgePitch) },
                                set: { settings.edgePitch = Int($0) }
                            ), in: -50...50, step: 5)
                            .tint(.purple)
                        }
                    }
                }
            }
            
            // 系统 TTS 配置
            if settings.provider == .system {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("系统语音配置")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        
                        HStack {
                            Text("语速")
                                .font(.system(size: 12))
                                .foregroundStyle(.gray)
                            
                            Slider(value: $settings.systemRate, in: 0...1, step: 0.1)
                            
                            Text(String(format: "%.1f", settings.systemRate))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.gray)
                                .frame(width: 40)
                        }
                    }
                }
            }
            
            // 朗读设置
            SettingsCard {
                VStack(alignment: .leading, spacing: 20) {
                    Text("朗读设置")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Divider().opacity(0.3)
                    
                    // 自动朗读
                    HStack(spacing: 12) {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 16))
                            .foregroundStyle(.blue)
                            .frame(width: 28)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("自动朗读回复")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                            Text("AI 回复后自动开始朗读")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $settings.autoReadAloud)
                            .toggleStyle(.switch)
                            .tint(.blue)
                    }
                    
                    // 分块大小
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "square.grid.3x3")
                                .font(.system(size: 14))
                                .foregroundStyle(.green)
                                .frame(width: 28)
                            
                            Text("分块大小")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                            
                            Spacer()
                            
                            Text("\(settings.chunkSize) 字")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(4)
                        }
                        
                        HStack(spacing: 12) {
                            Text("50")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            
                            Slider(value: Binding(
                                get: { Double(settings.chunkSize) },
                                set: { settings.chunkSize = Int($0) }
                            ), in: 50...500, step: 50)
                            .tint(.green)
                            
                            Text("500")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 40)
                        
                        Text("分块朗读可减少首次响应延迟，数值越小延迟越低")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 40)
                    }
                }
            }
            
            // 测试区域
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("测试语音")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        // 延迟显示
                        if let latency = latencyMs {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text("首音延迟: \(latency)ms")
                                    .font(.system(size: 11, design: .monospaced))
                            }
                            .foregroundStyle(latency < 1000 ? .green : (latency < 2000 ? .orange : .red))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(4)
                        }
                    }
                    
                    // 测试文本输入
                    TextEditor(text: $testText)
                        .font(.system(size: 12))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(height: 80)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                    
                    // 进度显示
                    if isTesting && ttsService.totalChunks > 1 {
                        HStack(spacing: 8) {
                            ProgressView(value: Double(ttsService.currentChunkIndex + 1), total: Double(ttsService.totalChunks))
                                .progressViewStyle(.linear)
                                .tint(.blue)
                            
                            Text("\(ttsService.currentChunkIndex + 1)/\(ttsService.totalChunks)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.gray)
                        }
                    }
                    
                    // 按钮区域
                    HStack(spacing: 12) {
                        Button(action: testTTS) {
                            HStack(spacing: 6) {
                                if ttsService.isSynthesizing {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: isTesting ? "stop.fill" : "play.fill")
                                }
                                Text(isTesting ? (ttsService.isSynthesizing ? "合成中..." : "播放中") : "开始测试")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isTesting ? Color.orange : Color.blue)
                            .foregroundStyle(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        // 重置按钮
                        Button(action: { latencyMs = nil }) {
                            Image(systemName: "arrow.counterclockwise")
                                .padding(10)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.gray)
                        .help("重置延迟统计")
                    }
                    
                    // 提示
                    Text("测试将使用当前分块设置 (\(settings.chunkSize)字/块)")
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)
                }
            }
        }
        .onChange(of: ttsService.isPlaying) { _, isPlaying in
            if !isPlaying && isTesting {
                isTesting = false
            }
            // 计算首音延迟
            if isPlaying, let startTime = testStartTime {
                latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)
                testStartTime = nil
            }
        }
    }
    
    private func testTTS() {
        if isTesting {
            TTSService.shared.stop()
            isTesting = false
            testStartTime = nil
        } else {
            isTesting = true
            testStartTime = Date()  // 记录开始时间
            TTSService.shared.speak(testText)
        }
    }
}

// MARK: - TTS Provider Row

private struct TTSProviderRow: View {
    let provider: TTSProvider
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? .blue : .gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                    
                    Text(provider.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)
                }
                
                Spacer()
            }
            .padding(12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
