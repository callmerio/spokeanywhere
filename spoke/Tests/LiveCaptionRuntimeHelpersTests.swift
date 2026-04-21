import Foundation
import Testing
@testable import SpokenAnyWhere

@Suite("LiveCaptionRuntimeHelpers 测试")
@MainActor
struct LiveCaptionRuntimeHelpersTests {

    @Test("scroll sync key 会在 pendingTranslation 变化时更新")
    func scrollSyncKeyTracksPendingTranslation() {
        let id = UUID()

        let before = makeLiveCaptionScrollSyncKey(
            lastItemID: id,
            pendingText: "long source line",
            pendingTranslation: "short translation",
            translationRevision: 0
        )
        let after = makeLiveCaptionScrollSyncKey(
            lastItemID: id,
            pendingText: "long source line",
            pendingTranslation: "short translation that keeps growing",
            translationRevision: 0
        )

        #expect(before != after)
    }

    @Test("scroll sync key 会在新增句子时更新")
    func scrollSyncKeyTracksLastItemIdentity() {
        let before = makeLiveCaptionScrollSyncKey(
            lastItemID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"),
            pendingText: "",
            pendingTranslation: "",
            translationRevision: 0
        )
        let after = makeLiveCaptionScrollSyncKey(
            lastItemID: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"),
            pendingText: "",
            pendingTranslation: "",
            translationRevision: 0
        )

        #expect(before != after)
    }

    @Test("scroll sync key 会在 finalized translation 版本变化时更新")
    func scrollSyncKeyTracksFinalizedTranslationRevision() {
        let id = UUID()

        let before = makeLiveCaptionScrollSyncKey(
            lastItemID: id,
            pendingText: "",
            pendingTranslation: "",
            translationRevision: 1
        )
        let after = makeLiveCaptionScrollSyncKey(
            lastItemID: id,
            pendingText: "",
            pendingTranslation: "",
            translationRevision: 2
        )

        #expect(before != after)
    }

    @Test("collapsed 模式保留最近三条 finalized item")
    func collapsedVisibleItemsKeepRecentTail() {
        let visible = liveCaptionCollapsedVisibleItems(from: ["first", "second", "third", "fourth"])

        #expect(visible == ["second", "third", "fourth"])
    }

    @Test("collapsed 模式在没有 finalized item 时保持空数组")
    func collapsedVisibleItemsStayEmptyForEmptyInput() {
        let visible: [Int] = liveCaptionCollapsedVisibleItems(from: [])

        #expect(visible.isEmpty)
    }

    @Test("collapsed 模式在条目不足三条时保留全部")
    func collapsedVisibleItemsKeepAllWhenShort() {
        let visible = liveCaptionCollapsedVisibleItems(from: ["first", "second"])

        #expect(visible == ["first", "second"])
    }

    @Test("collapsed 焦点 pin 打开时即使不在 document bottom 也继续允许自动跟随")
    func collapsedFocusPinKeepsAutoScrollAlive() {
        #expect(
            liveCaptionShouldAutoScrollCollapsed(
                isAtBottom: false,
                isFocusPinned: true,
                isUserSelecting: false
            )
        )
        #expect(
            !liveCaptionShouldAutoScrollCollapsed(
                isAtBottom: false,
                isFocusPinned: false,
                isUserSelecting: false
            )
        )
    }

}
