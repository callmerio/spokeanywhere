import SwiftUI
import ServiceManagement

class AppSettings: ObservableObject {
    @AppStorage("StartAtLogin") var startAtLogin: Bool = false {
        didSet {
            if #available(macOS 13.0, *) {
                if startAtLogin {
                    try? SMAppService.mainApp.register()
                } else {
                    try? SMAppService.mainApp.unregister()
                }
            }
        }
    }
    
    @AppStorage("ShowInDock") var showInDock: Bool = true {
        didSet {
            if showInDock {
                NSApp.setActivationPolicy(.regular)
            } else {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
    
    @AppStorage("ShowInMenuBar") var showInMenuBar: Bool = true
    @AppStorage("PressEscToCancel") var pressEscToCancel: Bool = true
    @AppStorage("PlaySoundEffect") var playSoundEffect: Bool = true
    @AppStorage("RecordingMode") var recordingMode: RecordingMode = .mixed
    
    enum RecordingMode: String, CaseIterable, Identifiable {
        case hold = "hold"
        case toggle = "toggle"
        case mixed = "mixed"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .hold: return "按住录音 (Hold)"
            case .toggle: return "切换录音 (Toggle)"
            case .mixed: return "智能混合 (Hybrid)"
            }
        }
    }
}
