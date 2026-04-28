import Foundation
import Testing

@Suite("快捷键宿主挂载策略测试")
struct KeyboardShortcutHostMountingTests {
    @Test("隐藏快捷键宿主应保持挂载，不应使用 hidden 移除")
    func shortcutHostsStayMounted() throws {
        let floatingSource = try loadSource(at: ["UI", "HUD", "FloatingCapsuleView.swift"])
        let quickAskSource = try loadSource(at: ["UI", "HUD", "QuickAskCapsuleView.swift"])
        let answerPanelSource = try loadSource(at: ["UI", "QuickAsk", "AnswerPanelView.swift"])

        for source in [floatingSource, quickAskSource, answerPanelSource] {
            #expect(
                !source.contains(".hidden()"),
                "快捷键宿主不应通过 hidden() 隐藏，否则可能被 SwiftUI 优化移除"
            )
            #expect(
                source.contains(".opacity(0)"),
                "快捷键宿主应通过 opacity(0) 保持挂载但不可见"
            )
            #expect(
                source.contains(".frame(width: 0, height: 0)"),
                "快捷键宿主应收缩到零尺寸，避免影响布局"
            )
        }
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
