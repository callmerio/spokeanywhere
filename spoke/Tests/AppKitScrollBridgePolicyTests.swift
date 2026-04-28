import CoreGraphics
import Foundation
import Testing
@testable import SpokenAnyWhere

@Suite("AppKitScroll bridge policy 测试")
struct AppKitScrollBridgePolicyTests {

    @Test("内容增长且用户未主动离底时允许追赶")
    func allowsCatchUpForContentGrowth() {
        #expect(
            appKitScrollShouldTreatAsContentGrowth(
                previouslyAtBottom: true,
                atBottom: false,
                scrollY: 96,
                lastScrollY: 98,
                maxScrollY: 140,
                lastMaxScrollY: 120
            )
        )
    }

    @Test("用户主动上滑时不应误判为内容增长追赶")
    func rejectsCatchUpForUserScrollAway() {
        #expect(
            !appKitScrollShouldTreatAsContentGrowth(
                previouslyAtBottom: true,
                atBottom: false,
                scrollY: 80,
                lastScrollY: 100,
                maxScrollY: 140,
                lastMaxScrollY: 120
            )
        )
    }

    @Test("gap 超过阈值且仍在合理范围内时应允许 catch-up")
    func allowsCatchUpWithinGapWindow() {
        #expect(
            appKitScrollShouldCatchUp(
                gap: 12,
                threshold: 5,
                maxAllowedGap: 500
            )
        )
    }

    @Test("gap 过大时应拒绝 catch-up，避免突兀跳跃")
    func rejectsCatchUpForHugeGap() {
        #expect(
            !appKitScrollShouldCatchUp(
                gap: 700,
                threshold: 5,
                maxAllowedGap: 500
            )
        )
    }

    @Test("overscroll 超过阈值时才触发 correction")
    func overscrollRequiresThreshold() {
        #expect(
            !appKitScrollShouldHandleOverscroll(
                scrollY: 112,
                maxScrollY: 100,
                overscrollThreshold: 15
            )
        )
        #expect(
            appKitScrollShouldHandleOverscroll(
                scrollY: 116,
                maxScrollY: 100,
                overscrollThreshold: 15
            )
        )
    }

    @Test("frame 变化处理应使用 trailing debounce 而不是前沿丢弃")
    func frameChangeHandlingUsesTrailingDebounce() throws {
        let source = try loadSource(at: ["UI", "LiveCaption", "AppKitScrollView.swift"])

        #expect(
            source.contains("pendingFrameChangeWorkItem"),
            "AppKitScrollView 应维护可取消的 frame-change work item"
        )
        #expect(
            !source.contains("guard now.timeIntervalSince(lastFrameChangeTime) > 0.05 else { return }"),
            "AppKitScrollView 不应继续使用前沿丢弃式 frame change 节流"
        )
    }

    @Test("programmatic scroll 期间不能直接吞掉所有 scroll 事件")
    func programmaticScrollStillAllowsInterruptionHandling() throws {
        let source = try loadSource(at: ["UI", "LiveCaption", "AppKitScrollView.swift"])

        #expect(
            !source.contains("@objc func scrollViewDidScroll(_ notification: Notification) {\n            guard !isScrollingProgrammatically else { return }"),
            "scrollViewDidScroll 不应在 programmatic scroll 期间直接 return"
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
