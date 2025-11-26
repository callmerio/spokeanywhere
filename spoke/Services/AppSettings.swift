import SwiftUI
import ServiceManagement
import Carbon.HIToolbox

// MARK: - Key Combo Formatter

enum KeyComboFormatter {
    /// 将 keyCode 和 modifiers 格式化为可读字符串
    static func format(keyCode: Int, modifiers: Int) -> String {
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        
        if let keyName = keyCodeToString(keyCode) {
            parts.append(keyName)
        }
        
        return parts.joined(separator: " + ")
    }
    
    /// keyCode 转换为可读字符
    static func keyCodeToString(_ keyCode: Int) -> String? {
        let keyCodeMap: [Int: String] = [
            kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
            kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
            kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
            kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
            kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
            kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
            kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
            kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
            kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
            kVK_ANSI_8: "8", kVK_ANSI_9: "9",
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫",
            kVK_Escape: "⎋", kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
            kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9",
            kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=",
            kVK_ANSI_LeftBracket: "[", kVK_ANSI_RightBracket: "]",
            kVK_ANSI_Semicolon: ";", kVK_ANSI_Quote: "'",
            kVK_ANSI_Comma: ",", kVK_ANSI_Period: ".", kVK_ANSI_Slash: "/",
            kVK_ANSI_Backslash: "\\", kVK_ANSI_Grave: "`"
        ]
        return keyCodeMap[keyCode]
    }
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
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
    
    // MARK: - Shortcut Settings
    
    /// 快捷键 keyCode (默认: R = 15)
    @AppStorage("ShortcutKeyCode") var shortcutKeyCode: Int = kVK_ANSI_R {
        didSet { notifyShortcutChange() }
    }
    
    /// 快捷键修饰符 (默认: Option = 524288)
    @AppStorage("ShortcutModifiers") var shortcutModifiers: Int = Int(NSEvent.ModifierFlags.option.rawValue) {
        didSet { notifyShortcutChange() }
    }
    
    /// 快捷键变更通知
    static let shortcutDidChangeNotification = Notification.Name("ShortcutDidChange")
    
    private func notifyShortcutChange() {
        NotificationCenter.default.post(name: Self.shortcutDidChangeNotification, object: nil)
    }
    
    /// 获取快捷键显示字符串
    var shortcutDisplayString: String {
        KeyComboFormatter.format(keyCode: shortcutKeyCode, modifiers: shortcutModifiers)
    }
    
    /// 更新快捷键
    func updateShortcut(keyCode: Int, modifiers: Int) {
        self.shortcutKeyCode = keyCode
        self.shortcutModifiers = modifiers
    }
    
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
