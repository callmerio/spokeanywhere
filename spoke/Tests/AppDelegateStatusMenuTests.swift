import AppKit
import Carbon.HIToolbox
import Testing
@testable import SpokenAnyWhere

@Suite("AppDelegate 状态菜单测试", .serialized)
@MainActor
struct AppDelegateStatusMenuTests {
    @Test("setupMenuBar 会初始化菜单标题和 action")
    func setupMenuBarInitializesTitlesAndActions() {
        let settings = AppSettings.shared
        let originalShortcutKeyCode = settings.shortcutKeyCode
        let originalShortcutModifiers = settings.shortcutModifiers
        let originalQuickAskKeyCode = settings.quickAskKeyCode
        let originalQuickAskModifiers = settings.quickAskModifiers
        let delegate = AppDelegate()

        defer {
            delegate.testingTearDownStatusMenu()
            settings.updateShortcut(keyCode: originalShortcutKeyCode, modifiers: originalShortcutModifiers)
            settings.updateQuickAskShortcut(keyCode: originalQuickAskKeyCode, modifiers: originalQuickAskModifiers)
        }

        settings.updateShortcut(keyCode: kVK_ANSI_R, modifiers: Int(NSEvent.ModifierFlags.option.rawValue))
        settings.updateQuickAskShortcut(keyCode: kVK_ANSI_Q, modifiers: Int(NSEvent.ModifierFlags.option.rawValue))

        delegate.testingSetupMenuBar()

        #expect(delegate.testingRecordingMenuTitle == "录音")
        #expect(delegate.testingQuickAskMenuTitle == "Quick Ask")
        #expect(delegate.testingRecordingMenuAction == #selector(AppDelegate.toggleRecordingFromMenu))
        #expect(delegate.testingQuickAskMenuAction == #selector(AppDelegate.triggerQuickAskFromMenu))
        #expect(delegate.testingRecordingMenuKeyEquivalent == "r")
        #expect(delegate.testingQuickAskMenuKeyEquivalent == "q")
        #expect(delegate.testingRecordingMenuModifierMask == .option)
        #expect(delegate.testingQuickAskMenuModifierMask == .option)
    }

    @Test("重复安装 observer 后，菜单仍会刷新原生快捷键显示")
    func reinstallShortcutObserverRefreshesNativeShortcutDisplay() async {
        let settings = AppSettings.shared
        let originalShortcutKeyCode = settings.shortcutKeyCode
        let originalShortcutModifiers = settings.shortcutModifiers
        let originalQuickAskKeyCode = settings.quickAskKeyCode
        let originalQuickAskModifiers = settings.quickAskModifiers
        let delegate = AppDelegate()

        defer {
            delegate.testingTearDownStatusMenu()
            settings.updateShortcut(keyCode: originalShortcutKeyCode, modifiers: originalShortcutModifiers)
            settings.updateQuickAskShortcut(keyCode: originalQuickAskKeyCode, modifiers: originalQuickAskModifiers)
        }

        delegate.testingSetupMenuBar()
        delegate.testingReinstallShortcutObserver()

        settings.updateShortcut(keyCode: kVK_ANSI_T, modifiers: Int(NSEvent.ModifierFlags.command.rawValue))
        settings.updateQuickAskShortcut(keyCode: kVK_ANSI_W, modifiers: Int(NSEvent.ModifierFlags.command.rawValue))
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(delegate.testingRecordingMenuTitle == "录音")
        #expect(delegate.testingQuickAskMenuTitle == "Quick Ask")
        #expect(delegate.testingRecordingMenuKeyEquivalent == "t")
        #expect(delegate.testingQuickAskMenuKeyEquivalent == "w")
        #expect(delegate.testingRecordingMenuModifierMask == .command)
        #expect(delegate.testingQuickAskMenuModifierMask == .command)
    }
}
