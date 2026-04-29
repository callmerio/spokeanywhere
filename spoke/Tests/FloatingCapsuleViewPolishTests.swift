import Foundation
import Testing
@testable import SpokenAnyWhere

@Suite("FloatingCapsuleView 收口测试")
@MainActor
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

        var didOpenSettings = false
        let view = FloatingCapsuleView(
            state: RecordingState(),
            openSettingsAction: {
                didOpenSettings = true
            }
        )

        view.openSettingsAction?()

        #expect(didOpenSettings, "FloatingCapsuleView 应保留并触发注入的设置动作")
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

        #expect(
            !floatingCapsuleShouldUpdateMeasuredHeight(currentHeight: 100, newHeight: 100.4),
            "高度差在默认容差内时不应触发状态写入"
        )
        #expect(
            floatingCapsuleShouldUpdateMeasuredHeight(currentHeight: 100, newHeight: 100.6),
            "高度差超过默认容差时应触发状态写入"
        )
        #expect(
            !floatingCapsuleShouldUpdateMeasuredHeight(currentHeight: 100, newHeight: 100.9, tolerance: 1),
            "自定义容差应参与高度 guard 判断"
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
