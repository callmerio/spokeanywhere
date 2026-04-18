import Carbon.HIToolbox
import SwiftUI

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

@MainActor
struct AppSettingsDependencies {
    let notificationCenter: NotificationCenter
    let updateLoginItemRegistration: (Bool) -> Void
    let applyDockVisibility: (Bool) -> Void
    let updateSelectionToolbarEnabled: (Bool) -> Void
}

@MainActor
class AppSettings: ObservableObject {
    @MainActor static let shared = AppSettings()
    private let dependencies: AppSettingsDependencies

    init() {
        self.dependencies = .live
    }
    
    @AppStorage("StartAtLogin") var startAtLogin: Bool = false {
        didSet {
            dependencies.updateLoginItemRegistration(startAtLogin)
        }
    }
    
    @AppStorage("ShowInDock") var showInDock: Bool = true {
        didSet {
            dependencies.applyDockVisibility(showInDock)
        }
    }
    
    @AppStorage("ShowInMenuBar") var showInMenuBar: Bool = true
    @AppStorage("PressEscToCancel") var pressEscToCancel: Bool = true
    @AppStorage("PlaySoundEffect") var playSoundEffect: Bool = true
    @AppStorage("RecordingMode") var recordingMode: RecordingMode = .mixed
    
    // MARK: - Real-time Typing
    
    /// 边说边打字功能开关
    /// 仅在支持流式输出的引擎下有效 (SpeechAnalyzer / SFSpeech)
    @AppStorage("RealtimeTypingEnabled") var realtimeTypingEnabled: Bool = false
    
    // MARK: - Clipboard History

    /// 剪贴板历史作为 LLM 上下文（替代之前的「包含剪贴板内容」）
    @AppStorage("ClipboardHistoryEnabled") var clipboardHistoryEnabled: Bool = false

    /// 剪贴板历史保存条数
    @AppStorage("ClipboardHistoryLimit") var clipboardHistoryLimit: Int = 30

    // MARK: - Diagnostics

    /// 启动诊断日志开关（运行时控制）
    /// 开启后会输出详细的启动步骤耗时和依赖初始化信息
    @AppStorage("StartupDiagnosticsEnabled") var startupDiagnosticsEnabled: Bool = false

    // MARK: - History Cleanup
    
    /// 是否启用历史记录自动清理
    @AppStorage("HistoryAutoCleanupEnabled") var historyAutoCleanupEnabled: Bool = true
    
    /// 历史记录保留天数（默认 30 天）
    @AppStorage("HistoryKeepDays") var historyKeepDays: Int = 30
    
    /// 历史记录最大条数（默认 500 条，0 表示不限制）
    @AppStorage("HistoryMaxCount") var historyMaxCount: Int = 500
    
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
        postNotification(Self.shortcutDidChangeNotification)
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
    
    // MARK: - Quick Ask Shortcut
    
    /// Quick Ask 快捷键 keyCode (默认: T = 17)
    @AppStorage("QuickAskKeyCode") var quickAskKeyCode: Int = kVK_ANSI_T {
        didSet { notifyQuickAskShortcutChange() }
    }
    
    /// Quick Ask 快捷键修饰符 (默认: Option = 524288)
    @AppStorage("QuickAskModifiers") var quickAskModifiers: Int = Int(NSEvent.ModifierFlags.option.rawValue) {
        didSet { notifyQuickAskShortcutChange() }
    }
    
    /// Quick Ask 快捷键变更通知
    static let quickAskShortcutDidChangeNotification = Notification.Name("QuickAskShortcutDidChange")
    
    private func notifyQuickAskShortcutChange() {
        postNotification(Self.quickAskShortcutDidChangeNotification)
    }
    
    /// 获取 Quick Ask 快捷键显示字符串
    var quickAskShortcutDisplayString: String {
        KeyComboFormatter.format(keyCode: quickAskKeyCode, modifiers: quickAskModifiers)
    }
    
    /// 更新 Quick Ask 快捷键
    func updateQuickAskShortcut(keyCode: Int, modifiers: Int) {
        self.quickAskKeyCode = keyCode
        self.quickAskModifiers = modifiers
    }
    
    // MARK: - Selection Toolbar
    
    /// 选择工具栏是否启用
    @AppStorage("SelectionToolbarEnabled") var selectionToolbarEnabled: Bool = true {
        didSet {
            dependencies.updateSelectionToolbarEnabled(selectionToolbarEnabled)
        }
    }
    
    /// 选择工具栏自动隐藏延迟（秒）
    @AppStorage("SelectionToolbarAutoHideDelay") var selectionToolbarAutoHideDelay: Double = 5.0
    
    /// 选择工具栏是否显示按钮文字
    @AppStorage("SelectionToolbarShowText") var selectionToolbarShowText: Bool = true
    
    /// 选择工具栏是否启用 OCR 上下文
    @AppStorage("SelectionToolbarOCRContext") var selectionToolbarOCRContext: Bool = true
    
    // MARK: - Message Panel Shortcut
    
    /// Message Panel 快捷键 keyCode (默认: P = 35)
    @AppStorage("MessagePanelKeyCode") var messagePanelKeyCode: Int = kVK_ANSI_P {
        didSet { notifyMessagePanelShortcutChange() }
    }
    
    /// Message Panel 快捷键修饰符 (默认: Option = 524288)
    @AppStorage("MessagePanelModifiers") var messagePanelModifiers: Int = Int(NSEvent.ModifierFlags.option.rawValue) {
        didSet { notifyMessagePanelShortcutChange() }
    }
    
    /// Message Panel 快捷键变更通知
    static let messagePanelShortcutDidChangeNotification = Notification.Name("MessagePanelShortcutDidChange")
    
    private func notifyMessagePanelShortcutChange() {
        postNotification(Self.messagePanelShortcutDidChangeNotification)
    }
    
    /// 获取 Message Panel 快捷键显示字符串
    var messagePanelShortcutDisplayString: String {
        KeyComboFormatter.format(keyCode: messagePanelKeyCode, modifiers: messagePanelModifiers)
    }
    
    /// 更新 Message Panel 快捷键
    func updateMessagePanelShortcut(keyCode: Int, modifiers: Int) {
        self.messagePanelKeyCode = keyCode
        self.messagePanelModifiers = modifiers
    }

    // MARK: - Clipboard Pipeline Shortcut

    /// Clipboard Pipeline 快捷键 keyCode (默认: V = 9)
    @AppStorage("ClipboardPipelineKeyCode") var clipboardPipelineKeyCode: Int = kVK_ANSI_V {
        didSet { notifyClipboardPipelineShortcutChange() }
    }

    /// Clipboard Pipeline 快捷键修饰符 (默认: Option = 524288)
    @AppStorage("ClipboardPipelineModifiers") var clipboardPipelineModifiers: Int = Int(NSEvent.ModifierFlags.option.rawValue) {
        didSet { notifyClipboardPipelineShortcutChange() }
    }

    /// Clipboard Pipeline 快捷键变更通知
    static let clipboardPipelineShortcutDidChangeNotification = Notification.Name("ClipboardPipelineShortcutDidChange")

    private func notifyClipboardPipelineShortcutChange() {
        postNotification(Self.clipboardPipelineShortcutDidChangeNotification)
    }

    /// 获取 Clipboard Pipeline 快捷键显示字符串
    var clipboardPipelineShortcutDisplayString: String {
        KeyComboFormatter.format(keyCode: clipboardPipelineKeyCode, modifiers: clipboardPipelineModifiers)
    }

    /// 更新 Clipboard Pipeline 快捷键
    func updateClipboardPipelineShortcut(keyCode: Int, modifiers: Int) {
        self.clipboardPipelineKeyCode = keyCode
        self.clipboardPipelineModifiers = modifiers
    }
    
    // MARK: - Live Caption Shortcut
    
    /// Live Caption 快捷键 keyCode (默认: S = 1)
    @AppStorage("LiveCaptionKeyCode") var liveCaptionKeyCode: Int = kVK_ANSI_S {
        didSet { notifyLiveCaptionShortcutChange() }
    }
    
    /// Live Caption 快捷键修饰符 (默认: Option = 524288)
    @AppStorage("LiveCaptionModifiers") var liveCaptionModifiers: Int = Int(NSEvent.ModifierFlags.option.rawValue) {
        didSet { notifyLiveCaptionShortcutChange() }
    }
    
    /// Live Caption 快捷键变更通知
    static let liveCaptionShortcutDidChangeNotification = Notification.Name("LiveCaptionShortcutDidChange")
    
    private func notifyLiveCaptionShortcutChange() {
        postNotification(Self.liveCaptionShortcutDidChangeNotification)
    }
    
    /// 获取 Live Caption 快捷键显示字符串
    var liveCaptionShortcutDisplayString: String {
        KeyComboFormatter.format(keyCode: liveCaptionKeyCode, modifiers: liveCaptionModifiers)
    }
    
    /// 更新 Live Caption 快捷键
    func updateLiveCaptionShortcut(keyCode: Int, modifiers: Int) {
        self.liveCaptionKeyCode = keyCode
        self.liveCaptionModifiers = modifiers
    }
    
    // MARK: - Screenshot Shortcut
    
    /// Screenshot 快捷键 keyCode (默认: A = 0)
    @AppStorage("ScreenshotKeyCode") var screenshotKeyCode: Int = kVK_ANSI_A {
        didSet { notifyScreenshotShortcutChange() }
    }
    
    /// Screenshot 快捷键修饰符 (默认: Option = 524288)
    @AppStorage("ScreenshotModifiers") var screenshotModifiers: Int = Int(NSEvent.ModifierFlags.option.rawValue) {
        didSet { notifyScreenshotShortcutChange() }
    }
    
    /// Screenshot 快捷键变更通知
    static let screenshotShortcutDidChangeNotification = Notification.Name("ScreenshotShortcutDidChange")
    
    private func notifyScreenshotShortcutChange() {
        postNotification(Self.screenshotShortcutDidChangeNotification)
    }
    
    /// 获取 Screenshot 快捷键显示字符串
    var screenshotShortcutDisplayString: String {
        KeyComboFormatter.format(keyCode: screenshotKeyCode, modifiers: screenshotModifiers)
    }
    
    /// 更新 Screenshot 快捷键
    func updateScreenshotShortcut(keyCode: Int, modifiers: Int) {
        self.screenshotKeyCode = keyCode
        self.screenshotModifiers = modifiers
    }
    
    // MARK: - Live Caption Settings
    
    /// 实时字幕翻译目标语言
    @AppStorage("LiveCaptionTargetLanguage") var liveCaptionTargetLanguage: String = "zh-Hans"
    
    /// 实时字幕源语言
    @AppStorage("LiveCaptionSourceLanguage") var liveCaptionSourceLanguage: String = "en-US"
    
    /// 是否显示原文
    @AppStorage("LiveCaptionShowOriginal") var liveCaptionShowOriginal: Bool = true
    
    /// 是否启用翻译
    @AppStorage("LiveCaptionTranslationEnabled") var liveCaptionTranslationEnabled: Bool = true
    
    enum RecordingMode: String, CaseIterable, Identifiable {
        case hold
        case toggle
        case mixed
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .hold: return "按住录音 (Hold)"
            case .toggle: return "切换录音 (Toggle)"
            case .mixed: return "智能混合 (Hybrid)"
            }
        }
    }

    private func postNotification(_ name: Notification.Name) {
        dependencies.notificationCenter.post(name: name, object: nil)
    }
}
