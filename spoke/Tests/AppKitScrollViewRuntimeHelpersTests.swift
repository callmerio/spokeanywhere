import CoreGraphics
import Testing
@testable import SpokenAnyWhere

@Suite("AppKitScrollViewRuntimeHelpers 测试")
struct AppKitScrollViewRuntimeHelpersTests {

    @Test("大 gap 仍然应触发追底，避免长句增长后停止跟随")
    func largeGapStillNeedsCatchUp() {
        #expect(appKitScrollNeedsCatchUp(gap: 640, threshold: 5))
    }

    @Test("内容增长应被识别为需要追赶，而不是用户主动离开")
    func contentGrowthAndStableScrollStayPinned() {
        #expect(appKitScrollContentGrew(maxScrollY: 980, lastMaxScrollY: 420))
        #expect(!appKitScrollUserScrolledAwayFromBottom(currentY: 420, lastScrollY: 420))
    }

    @Test("用户主动向上离开底部时不应误判为内容增长追底")
    func userScrollAwayDetectionRemainsIntact() {
        #expect(appKitScrollUserScrolledAwayFromBottom(currentY: 300, lastScrollY: 420))
        #expect(!appKitScrollUserScrolledAwayFromBottom(currentY: 418, lastScrollY: 420))
    }

    @Test("非法滚动几何不会产出目标坐标")
    func invalidScrollMetricsAreRejected() {
        #expect(appKitScrollTargetMetrics(contentHeight: .infinity, clipHeight: 200, extraOffset: 8) == nil)
        #expect(appKitScrollTargetMetrics(contentHeight: 600, clipHeight: .nan, extraOffset: 8) == nil)
    }

    @Test("合法滚动几何会产出 maxScrollY 与 targetY")
    func validScrollMetricsProduceTarget() {
        let metrics = appKitScrollTargetMetrics(contentHeight: 600, clipHeight: 200, extraOffset: 8)

        #expect(metrics?.maxScrollY == 400)
        #expect(metrics?.targetY == 408)
    }

    @Test("显式 delta 滚动请求会被限制在合法范围内")
    func explicitScrollAdjustmentClampsToRange() {
        #expect(
            appKitScrollResolvedOrigin(
                currentY: 408,
                deltaY: 40,
                maxScrollY: 400,
                extraOffset: 8
            ) == 408
        )
        #expect(
            appKitScrollResolvedOrigin(
                currentY: 408,
                deltaY: -60,
                maxScrollY: 400,
                extraOffset: 8
            ) == 348
        )
        #expect(
            appKitScrollResolvedOrigin(
                currentY: 15,
                deltaY: -30,
                maxScrollY: 400,
                extraOffset: 8
            ) == 0
        )
    }
}
