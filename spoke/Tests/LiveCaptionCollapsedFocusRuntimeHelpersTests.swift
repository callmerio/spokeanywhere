#if DEBUG
import CoreGraphics
import Testing
@testable import SpokenAnyWhere

@Suite("LiveCaptionCollapsedFocusRuntimeHelpers 测试")
struct LiveCaptionCollapsedFocusRuntimeHelpersTests {

    @Test("pending translation 优先作为 collapsed 焦点")
    func pendingTranslationWinsOverFinalized() {
        let viewport = LiveCaptionProbeSnapshot(
            slot: .viewportCollapsed,
            frame: CGRect(x: 0, y: 0, width: 300, height: 220),
            textLength: 0
        )
        let pending = LiveCaptionProbeSnapshot(
            slot: .pendingCollapsed,
            frame: CGRect(x: 0, y: 170, width: 280, height: 30),
            textLength: 24
        )
        let finalized = LiveCaptionProbeSnapshot(
            slot: .finalizedCollapsed,
            frame: CGRect(x: 0, y: 130, width: 280, height: 60),
            textLength: 88
        )

        let target = liveCaptionCollapsedPreferredTarget(
            viewport: viewport,
            pending: pending,
            finalized: finalized
        )

        #expect(target?.kind == .pendingTranslation)
        #expect(target?.targetFrame == pending.frame)
    }

    @Test("可放下的最新中文应被完整露出")
    func fittingTargetRequestsFullReveal() {
        let viewport = CGRect(x: 0, y: 0, width: 300, height: 200)
        let target = CGRect(x: 0, y: 150, width: 280, height: 40)

        #expect(liveCaptionCollapsedScrollDelta(viewportFrame: viewport, targetFrame: target) == 30)
    }

    @Test("超高中文默认对齐结尾而不是强行显示顶部")
    func oversizedTargetAnchorsToBottomEdge() {
        let viewport = CGRect(x: 0, y: 0, width: 300, height: 200)
        let target = CGRect(x: 0, y: 40, width: 280, height: 260)

        #expect(liveCaptionCollapsedScrollDelta(viewportFrame: viewport, targetFrame: target) == 100)
    }

    @Test("目标已经完整可见时不再请求额外滚动")
    func fullyVisibleTargetNeedsNoAdjustment() {
        let viewport = CGRect(x: 0, y: 0, width: 300, height: 220)
        let target = CGRect(x: 0, y: 120, width: 280, height: 60)

        #expect(liveCaptionCollapsedScrollDelta(viewportFrame: viewport, targetFrame: target) == 0)
    }

    @Test("bottom focus band 不应以裁掉顶部为代价")
    func bottomFocusBandClampsToKeepTopVisible() {
        let viewport = CGRect(x: 0, y: 0, width: 300, height: 100)
        let target = CGRect(x: 0, y: 5, width: 280, height: 90)

        let delta = liveCaptionCollapsedScrollDelta(viewportFrame: viewport, targetFrame: target)

        #expect(delta == 5)
        #expect(target.minY - delta >= viewport.minY)
    }
}
#endif
