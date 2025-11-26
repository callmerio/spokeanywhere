import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("常规", systemImage: "gear")
                }
            
            ModelsSettingsView()
                .tabItem {
                    Label("听写模型", systemImage: "waveform")
                }
            
            PromptSettingsView()
                .tabItem {
                    Label("AI 提示", systemImage: "brain")
                }
            
            HistoryView()
                .tabItem {
                    Label("历史记录", systemImage: "clock")
                }
        }
        .frame(width: 800, height: 500)
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        Text("常规设置 (To Be Implemented)")
    }
}

struct ModelsSettingsView: View {
    var body: some View {
        Text("模型管理 (To Be Implemented)")
    }
}

struct PromptSettingsView: View {
    var body: some View {
        Text("Prompt & Rules (To Be Implemented)")
    }
}

struct HistoryView: View {
    var body: some View {
        Text("历史记录 (To Be Implemented)")
    }
}
