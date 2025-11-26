import SwiftUI
import SwiftData

@main
struct SpokenAnyWhereApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
        .modelContainer(for: [HistoryItem.self, AppRule.self, AIProviderConfig.self])
        
        // No WindowGroup strictly needed if we only have Settings + HUD
        // But usually we want a main window or just Settings. 
        // Given PRD "UI 以「系统设置风格」多栏结构为主", Settings is the main view.
    }
}
