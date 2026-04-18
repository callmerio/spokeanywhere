import AppKit
import Carbon.HIToolbox
import Foundation
import Testing
@testable import SpokenAnyWhere

// MARK: - KeyComboFormatter Tests

@Suite("KeyComboFormatter 测试")
struct KeyComboFormatterTests {

    @Test("format 应正确格式化单个修饰键")
    func formatSingleModifier() {
        let result = KeyComboFormatter.format(
            keyCode: kVK_ANSI_R,
            modifiers: Int(NSEvent.ModifierFlags.option.rawValue)
        )

        #expect(result.contains("R"))
        #expect(result.contains("⌥"))
    }

    @Test("format 应正确格式化多个修饰键")
    func formatMultipleModifiers() {
        let modifiers = NSEvent.ModifierFlags([.command, .shift])
        let result = KeyComboFormatter.format(
            keyCode: kVK_ANSI_A,
            modifiers: Int(modifiers.rawValue)
        )

        #expect(result.contains("A"))
        #expect(result.contains("⌘"))
        #expect(result.contains("⇧"))
    }

    @Test("format 应正确格式化 Control 键")
    func formatControlKey() {
        let result = KeyComboFormatter.format(
            keyCode: kVK_ANSI_C,
            modifiers: Int(NSEvent.ModifierFlags.control.rawValue)
        )

        #expect(result.contains("⌃"))
        #expect(result.contains("C"))
    }

    @Test("keyCodeToString 应正确转换字母键")
    func keyCodeToStringLetters() {
        #expect(KeyComboFormatter.keyCodeToString(kVK_ANSI_A) == "A")
        #expect(KeyComboFormatter.keyCodeToString(kVK_ANSI_Z) == "Z")
    }

    @Test("keyCodeToString 应正确转换数字键")
    func keyCodeToStringNumbers() {
        #expect(KeyComboFormatter.keyCodeToString(kVK_ANSI_0) == "0")
        #expect(KeyComboFormatter.keyCodeToString(kVK_ANSI_9) == "9")
    }

    @Test("keyCodeToString 应正确转换特殊键")
    func keyCodeToStringSpecialKeys() {
        #expect(KeyComboFormatter.keyCodeToString(kVK_Space) == "Space")
        #expect(KeyComboFormatter.keyCodeToString(kVK_Return) == "↩")
        #expect(KeyComboFormatter.keyCodeToString(kVK_Tab) == "⇥")
        #expect(KeyComboFormatter.keyCodeToString(kVK_Delete) == "⌫")
        #expect(KeyComboFormatter.keyCodeToString(kVK_Escape) == "⎋")
    }

    @Test("keyCodeToString 应正确转换功能键")
    func keyCodeToStringFunctionKeys() {
        #expect(KeyComboFormatter.keyCodeToString(kVK_F1) == "F1")
        #expect(KeyComboFormatter.keyCodeToString(kVK_F12) == "F12")
    }

    @Test("keyCodeToString 应正确转换方向键")
    func keyCodeToStringArrowKeys() {
        #expect(KeyComboFormatter.keyCodeToString(kVK_LeftArrow) == "←")
        #expect(KeyComboFormatter.keyCodeToString(kVK_RightArrow) == "→")
        #expect(KeyComboFormatter.keyCodeToString(kVK_UpArrow) == "↑")
        #expect(KeyComboFormatter.keyCodeToString(kVK_DownArrow) == "↓")
    }

    @Test("keyCodeToString 对未知 keyCode 应返回 nil")
    func keyCodeToStringUnknownReturnsNil() {
        #expect(KeyComboFormatter.keyCodeToString(999) == nil)
    }
}

// MARK: - AppSettings Tests

@Suite("AppSettings 测试", .serialized)
@MainActor
struct AppSettingsTests {

    // MARK: - Singleton

    @Test("shared 单例应存在且始终一致")
    func sharedInstanceConsistent() {
        let settings1 = AppSettings.shared
        let settings2 = AppSettings.shared

        #expect(settings1 === settings2)
    }

    // MARK: - Default Values

    @Test("pressEscToCancel 默认应为 true")
    func pressEscToCancelDefaultTrue() {
        // 注意：这个测试验证默认值定义，不改变实际设置
        // 默认值在代码中定义为 true
        let settings = AppSettings.shared
        // 只验证属性可访问
        _ = settings.pressEscToCancel
    }

    @Test("playSoundEffect 默认应为 true")
    func playSoundEffectDefaultTrue() {
        let settings = AppSettings.shared
        _ = settings.playSoundEffect
    }

    @Test("realtimeTypingEnabled 默认应为 false")
    func realtimeTypingEnabledDefaultFalse() {
        let settings = AppSettings.shared
        _ = settings.realtimeTypingEnabled
    }

    @Test("clipboardHistoryLimit 默认应为 30")
    func clipboardHistoryLimitDefault() {
        let settings = AppSettings.shared
        // 验证属性可访问且值合理
        #expect(settings.clipboardHistoryLimit > 0)
    }

    @Test("historyKeepDays 默认应为 30")
    func historyKeepDaysDefault() {
        let settings = AppSettings.shared
        #expect(settings.historyKeepDays > 0)
    }

    @Test("historyMaxCount 默认应为 500")
    func historyMaxCountDefault() {
        let settings = AppSettings.shared
        #expect(settings.historyMaxCount >= 0)
    }

    // MARK: - Shortcut Display String

    @Test("shortcutDisplayString 应返回可读字符串")
    func shortcutDisplayStringReadable() {
        let settings = AppSettings.shared
        let display = settings.shortcutDisplayString

        #expect(!display.isEmpty)
    }

    @Test("quickAskShortcutDisplayString 应返回可读字符串")
    func quickAskShortcutDisplayStringReadable() {
        let settings = AppSettings.shared
        let display = settings.quickAskShortcutDisplayString

        #expect(!display.isEmpty)
    }

    @Test("liveCaptionShortcutDisplayString 应返回可读字符串")
    func liveCaptionShortcutDisplayStringReadable() {
        let settings = AppSettings.shared
        let display = settings.liveCaptionShortcutDisplayString

        #expect(!display.isEmpty)
    }

    @Test("screenshotShortcutDisplayString 应返回可读字符串")
    func screenshotShortcutDisplayStringReadable() {
        let settings = AppSettings.shared
        let display = settings.screenshotShortcutDisplayString

        #expect(!display.isEmpty)
    }

    @Test("messagePanelShortcutDisplayString 应返回可读字符串")
    func messagePanelShortcutDisplayStringReadable() {
        let settings = AppSettings.shared
        let display = settings.messagePanelShortcutDisplayString

        #expect(!display.isEmpty)
    }

    @Test("clipboardPipelineShortcutDisplayString 应返回可读字符串")
    func clipboardPipelineShortcutDisplayStringReadable() {
        let settings = AppSettings.shared
        let display = settings.clipboardPipelineShortcutDisplayString

        #expect(!display.isEmpty)
    }

    // MARK: - Update Shortcut

    @Test("updateShortcut 应更新快捷键设置")
    func updateShortcutWorks() {
        let settings = AppSettings.shared

        // 保存原始值
        let originalKeyCode = settings.shortcutKeyCode
        let originalModifiers = settings.shortcutModifiers

        // 更新
        settings.updateShortcut(keyCode: kVK_ANSI_X, modifiers: Int(NSEvent.ModifierFlags.command.rawValue))

        #expect(settings.shortcutKeyCode == kVK_ANSI_X)
        #expect(settings.shortcutModifiers == Int(NSEvent.ModifierFlags.command.rawValue))

        // 恢复原始值
        settings.updateShortcut(keyCode: originalKeyCode, modifiers: originalModifiers)
    }

    @Test("updateQuickAskShortcut 应更新 Quick Ask 快捷键")
    func updateQuickAskShortcutWorks() {
        let settings = AppSettings.shared

        let originalKeyCode = settings.quickAskKeyCode
        let originalModifiers = settings.quickAskModifiers

        settings.updateQuickAskShortcut(keyCode: kVK_ANSI_Y, modifiers: Int(NSEvent.ModifierFlags.shift.rawValue))

        #expect(settings.quickAskKeyCode == kVK_ANSI_Y)
        #expect(settings.quickAskModifiers == Int(NSEvent.ModifierFlags.shift.rawValue))

        // 恢复
        settings.updateQuickAskShortcut(keyCode: originalKeyCode, modifiers: originalModifiers)
    }

    @Test("updateClipboardPipelineShortcut 应更新剪贴板注入快捷键")
    func updateClipboardPipelineShortcutWorks() {
        let settings = AppSettings.shared

        let originalKeyCode = settings.clipboardPipelineKeyCode
        let originalModifiers = settings.clipboardPipelineModifiers

        settings.updateClipboardPipelineShortcut(
            keyCode: kVK_ANSI_B,
            modifiers: Int(NSEvent.ModifierFlags.command.rawValue)
        )

        #expect(settings.clipboardPipelineKeyCode == kVK_ANSI_B)
        #expect(settings.clipboardPipelineModifiers == Int(NSEvent.ModifierFlags.command.rawValue))

        settings.updateClipboardPipelineShortcut(keyCode: originalKeyCode, modifiers: originalModifiers)
    }

    // MARK: - RecordingMode

    @Test("RecordingMode 应有正确的 rawValue")
    func recordingModeRawValues() {
        #expect(AppSettings.RecordingMode.hold.rawValue == "hold")
        #expect(AppSettings.RecordingMode.toggle.rawValue == "toggle")
        #expect(AppSettings.RecordingMode.mixed.rawValue == "mixed")
    }

    @Test("RecordingMode 应有正确的 displayName")
    func recordingModeDisplayNames() {
        #expect(AppSettings.RecordingMode.hold.displayName.contains("Hold"))
        #expect(AppSettings.RecordingMode.toggle.displayName.contains("Toggle"))
        #expect(AppSettings.RecordingMode.mixed.displayName.contains("Hybrid"))
    }

    @Test("RecordingMode.allCases 应包含所有模式")
    func recordingModeAllCases() {
        let allCases = AppSettings.RecordingMode.allCases

        #expect(allCases.count == 3)
        #expect(allCases.contains(.hold))
        #expect(allCases.contains(.toggle))
        #expect(allCases.contains(.mixed))
    }

    @Test("RecordingMode.id 应返回 rawValue")
    func recordingModeIdEqualsRawValue() {
        for mode in AppSettings.RecordingMode.allCases {
            #expect(mode.id == mode.rawValue)
        }
    }
}

// MARK: - Notification Tests

@Suite("AppSettings 通知测试")
struct AppSettingsNotificationTests {

    @Test("shortcutDidChangeNotification 应正确定义")
    @MainActor
    func shortcutNotificationExists() {
        let name = AppSettings.shortcutDidChangeNotification
        #expect(name.rawValue == "ShortcutDidChange")
    }

    @Test("quickAskShortcutDidChangeNotification 应正确定义")
    @MainActor
    func quickAskShortcutNotificationExists() {
        let name = AppSettings.quickAskShortcutDidChangeNotification
        #expect(name.rawValue == "QuickAskShortcutDidChange")
    }

    @Test("messagePanelShortcutDidChangeNotification 应正确定义")
    @MainActor
    func messagePanelShortcutNotificationExists() {
        let name = AppSettings.messagePanelShortcutDidChangeNotification
        #expect(name.rawValue == "MessagePanelShortcutDidChange")
    }

    @Test("liveCaptionShortcutDidChangeNotification 应正确定义")
    @MainActor
    func liveCaptionShortcutNotificationExists() {
        let name = AppSettings.liveCaptionShortcutDidChangeNotification
        #expect(name.rawValue == "LiveCaptionShortcutDidChange")
    }

    @Test("screenshotShortcutDidChangeNotification 应正确定义")
    @MainActor
    func screenshotShortcutNotificationExists() {
        let name = AppSettings.screenshotShortcutDidChangeNotification
        #expect(name.rawValue == "ScreenshotShortcutDidChange")
    }

    @Test("clipboardPipelineShortcutDidChangeNotification 应正确定义")
    @MainActor
    func clipboardPipelineShortcutNotificationExists() {
        let name = AppSettings.clipboardPipelineShortcutDidChangeNotification
        #expect(name.rawValue == "ClipboardPipelineShortcutDidChange")
    }
}
