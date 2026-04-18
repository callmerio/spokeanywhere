import AppKit
import Carbon.HIToolbox
import Testing
@testable import SpokenAnyWhere

@Suite("AppStatusMenuLabels 测试")
struct AppStatusMenuLabelsTests {
    @Test("make 只生成纯菜单标题，不把快捷键拼进标题")
    func makeCreatesPlainTitles() {
        let labels = AppStatusMenuLabels.make()

        #expect(labels.recording == "录音")
        #expect(labels.quickAsk == "Quick Ask")
    }

    @Test("菜单快捷键运行时会把字母键转换成原生 keyEquivalent")
    func shortcutDescriptorConvertsLetterKeys() throws {
        let recording = try #require(
            AppStatusMenuShortcutRuntime.shortcut(
                keyCode: kVK_ANSI_R,
                modifiers: Int(NSEvent.ModifierFlags.option.rawValue)
            )
        )
        let quickAsk = try #require(
            AppStatusMenuShortcutRuntime.shortcut(
                keyCode: kVK_ANSI_Q,
                modifiers: Int(NSEvent.ModifierFlags.option.rawValue)
            )
        )

        #expect(recording.keyEquivalent == "r")
        #expect(recording.modifierMask == .option)
        #expect(quickAsk.keyEquivalent == "q")
        #expect(quickAsk.modifierMask == .option)
    }
}
