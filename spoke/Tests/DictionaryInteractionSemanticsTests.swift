import Foundation
import Testing

@Suite("Dictionary 交互语义测试")
struct DictionaryInteractionSemanticsTests {
    @Test("字典列表与结果卡的主动作不再使用 onTapGesture")
    func dictionaryPrimaryActionsUseButtons() throws {
        let panelSource = try loadSource(at: ["UI", "Dictionary", "DictionaryPanelView.swift"])
        let resultSource = try loadSource(at: ["UI", "SelectionToolbar", "DictionaryResultView.swift"])
        let formattedSource = try loadSource(at: ["UI", "Dictionary", "FormattedDefinitionView.swift"])
        let historySource = try loadSource(at: ["UI", "MessagePanel", "SessionHistoryListView.swift"])
        let dictionarySettingsSource = try loadSource(at: ["UI", "Settings", "DictionarySettingsView.swift"])

        #expect(
            panelSource.contains("Button {") && panelSource.contains("state.confirmSelection()"),
            "DictionaryPanelView 的结果行点击应改为 Button"
        )
        #expect(
            !panelSource.contains(".onTapGesture {\n                                state.selectedIndex = index\n                                state.confirmSelection()"),
            "DictionaryPanelView 不应再用 onTapGesture 承担结果行主动作"
        )

        #expect(
            resultSource.contains("Button {") && resultSource.contains("onDismiss()"),
            "DictionaryResultView 的 dismiss 动作应改为 Button"
        )
        #expect(
            !resultSource.contains(".onTapGesture {\n            onDismiss()"),
            "DictionaryResultView 不应再用 onTapGesture 承担主 dismiss 动作"
        )

        #expect(
            formattedSource.contains("Button {") && formattedSource.contains("onWordTap?(cleanWord.lowercased())"),
            "FormattedDefinitionView 的可点击单词应改为 Button"
        )
        #expect(
            !formattedSource.contains(".onTapGesture {\n                            if cleanWord.count > 2 {"),
            "FormattedDefinitionView 不应再用 onTapGesture 承担单词跳转动作"
        )

        #expect(
            historySource.contains("Button {\n            copyContent()") || historySource.contains("Button {\n                copyContent()"),
            "SessionHistoryListView 的记录卡主动作应改为 Button"
        )
        #expect(
            !historySource.contains(".onTapGesture {\n            copyContent()"),
            "SessionHistoryListView 不应再用 onTapGesture 承担记录卡主动作"
        )

        #expect(
            dictionarySettingsSource.contains("Button {\n            onEdit()") || dictionarySettingsSource.contains("Button {\n                onEdit()"),
            "DictionarySettingsView 的词条行主动作应改为 Button"
        )
        #expect(
            !dictionarySettingsSource.contains(".onTapGesture {\n            onEdit()"),
            "DictionarySettingsView 不应再用 onTapGesture 承担词条行主动作"
        )
    }

    private func loadSource(at components: [String]) throws -> String {
        let testsFileURL = URL(fileURLWithPath: #filePath)
        let projectRoot = testsFileURL.deletingLastPathComponent().deletingLastPathComponent()
        let sourceURL = components.reduce(projectRoot) { partial, component in
            partial.appendingPathComponent(component, isDirectory: false)
        }

        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
