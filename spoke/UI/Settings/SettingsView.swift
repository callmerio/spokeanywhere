import SwiftUI

private typealias DS = DesignTokens

// MARK: - Main Settings View

struct SettingsView: View {
    @State private var selectedTab: SettingsTab
    @StateObject private var audioManager = AudioDeviceManager()
    @StateObject private var appSettings = AppSettings()
    @StateObject private var micTester = MicrophoneTester()
    private let dependencies: SettingsViewDependencies

    let focusAddSkill: Bool

    init(
        initialTab: SettingsTab? = nil,
        focusAddSkill: Bool = false
    ) {
        self.init(initialTab: initialTab, focusAddSkill: focusAddSkill, dependencies: .live)
    }

    @MainActor
    init(
        initialTab: SettingsTab? = nil,
        focusAddSkill: Bool = false,
        dependencies: SettingsViewDependencies
    ) {
        self._selectedTab = State(initialValue: initialTab ?? .general)
        self.focusAddSkill = focusAddSkill
        self.dependencies = dependencies
    }

    enum SettingsTab: String, CaseIterable {
        case general = "常规"
        case screenshot = "截图"
        case toolbar = "划词工具栏"
        case model = "听写模型"
        case ai = "AI 处理"
        case dictionary = "词典"
        case tts = "语音合成"
        case shortcuts = "快捷键"
        case history = "历史记录"

        var icon: String {
            switch self {
            case .general: return "gear"
            case .screenshot: return "camera.viewfinder"
            case .toolbar: return "text.cursor"
            case .model: return "waveform"
            case .ai: return "sparkles"
            case .dictionary: return "book.closed"
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
        .background(DS.Colors.settingsBackground)
        .onReceive(dependencies.settingsSwitchToToolbarPublisher()) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = .toolbar
            }
        }
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
            .foregroundStyle(DS.Colors.textPrimary)
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
        .background(DS.Colors.settingsSidebarBackground)
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
                case .screenshot:
                    ScreenshotSettingsView()
                case .toolbar:
                    ToolbarSettingsView()
                case .model:
                    ModelsSettingsContent()
                case .ai:
                    AISettingsContent()
                case .dictionary:
                    DictionarySettingsContent()
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
        .background(DS.Colors.settingsBackground)
    }
}
