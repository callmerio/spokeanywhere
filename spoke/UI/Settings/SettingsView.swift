import SwiftUI
import AVFoundation
import SwiftData

// MARK: - Main Settings View

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    @StateObject private var audioManager = AudioDeviceManager()
    @StateObject private var appSettings = AppSettings()
    @StateObject private var micTester = MicrophoneTester()
    
    enum SettingsTab: String, CaseIterable {
        case general = "常规"
        case model = "听写模型"
        case shortcuts = "快捷键"
        case history = "历史记录"
        
        var icon: String {
            switch self {
            case .general: return "gear"
            case .model: return "waveform"
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
        .frame(minWidth: 700, minHeight: 480)
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

// MARK: - Shortcuts Settings

struct ShortcutsSettingsContent: View {
    @ObservedObject var appSettings: AppSettings
    @State private var isRecordingShortcut = false
    
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
    @Query(sort: \HistoryItem.createdAt, order: .reverse) private var historyItems: [HistoryItem]
    @State private var searchText = ""
    @State private var filterDate: DateFilter = .all
    
    enum DateFilter: String, CaseIterable {
        case all = "全部"
        case today = "今天"
        case week = "最近7天"
    }
    
    var filteredItems: [HistoryItem] {
        historyItems.filter { item in
            let matchesSearch = searchText.isEmpty || item.rawText.localizedCaseInsensitiveContains(searchText)
            let matchesDate: Bool
            
            switch filterDate {
            case .all: matchesDate = true
            case .today: matchesDate = Calendar.current.isDateInToday(item.createdAt)
            case .week:
                let date7DaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
                matchesDate = item.createdAt >= date7DaysAgo
            }
            
            return matchesSearch && matchesDate
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 搜索和过滤
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.gray)
                    TextField("搜索历史记录...", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                }
                .padding(10)
                .background(Color(hex: "252525"))
                .cornerRadius(8)
                
                Picker("", selection: $filterDate) {
                    ForEach(DateFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            
            // 列表
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.gray.opacity(0.5))
                    Text("没有找到记录")
                        .font(.system(size: 14))
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(filteredItems) { item in
                        HistoryItemRow(item: item)
                    }
                }
            }
        }
    }
}

struct HistoryItemRow: View {
    let item: HistoryItem
    @State private var isPlaying = false
    
    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(item.rawText)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .textSelection(.enabled)
                
                // 音频条
                if item.audioPath != nil {
                    HStack(spacing: 10) {
                        Button(action: { isPlaying.toggle() }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)
                        
                        Text("00:15")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.gray)
                    }
                }
                
                // 元信息
                HStack {
                    Label("听写", systemImage: "mic.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.gray)
                    
                    Spacer()
                    
                    Text(item.createdAt, style: .relative)
                        .font(.system(size: 10))
                        .foregroundStyle(.gray)
                }
            }
            .padding(14)
        }
    }
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
