import Foundation
import Testing

@Suite("FloatingCapsuleView 收口测试")
struct FloatingCapsuleViewPolishTests {
    @Test("设置入口应通过注入动作而非直接依赖 AppDelegate")
    func settingsOpenPathIsInjected() throws {
        let source = try loadSource(at: ["UI", "HUD", "FloatingCapsuleView.swift"])

        #expect(
            source.contains("var openSettingsAction: (() -> Void)?"),
            "FloatingCapsuleView 应暴露注入式 openSettingsAction"
        )
        #expect(
            source.contains("openSettingsAction?()"),
            "FloatingCapsuleView 应通过注入动作打开设置"
        )
        #expect(
            !source.contains("NSApp.delegate as? AppDelegate"),
            "FloatingCapsuleView 不应直接依赖 AppDelegate 打开设置"
        )
    }

    @Test("内容高度更新应通过 helper 做相等性 guard")
    func measuredHeightUpdatesAreGuarded() throws {
        let source = try loadSource(at: ["UI", "HUD", "FloatingCapsuleView.swift"])
        let helperSource = try loadSource(at: ["UI", "HUD", "FloatingCapsuleRuntimeHelpers.swift"])

        #expect(
            helperSource.contains("floatingCapsuleShouldUpdateMeasuredHeight"),
            "FloatingCapsuleRuntimeHelpers 应提供高度更新 guard helper"
        )
        #expect(
            source.contains("floatingCapsuleShouldUpdateMeasuredHeight"),
            "FloatingCapsuleView 应通过 helper 判断是否需要写入高度状态"
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
