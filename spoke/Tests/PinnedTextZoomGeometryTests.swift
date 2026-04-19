import AppKit
import Testing
@testable import SpokenAnyWhere

@Suite("PinnedTextZoomGeometry tests")
@MainActor
struct PinnedTextZoomGeometryTests {
    @Test("maximum clamp keeps width and height on the same scale factor while still enlarging the viewport")
    func maximumClampKeepsWidthAndHeightOnSameScaleFactor() {
        let base = CGSize(width: 300, height: 150)
        let scaled = PinnedTextZoomGeometry.scaledViewportSize(
            baseViewport: base,
            zoomRatio: 3.0,
            minimumSize: CGSize(width: 220, height: 120),
            maximumSize: CGSize(width: 760, height: 540)
        )

        #expect(scaled.width == 760)
        #expect(scaled.height == 380)
        #expect(scaled.width > base.width)
        #expect(scaled.height > base.height)
        #expect(scaled.width < base.width * 3.0)
        #expect(abs((scaled.width / base.width) - (scaled.height / base.height)) <= 0.0001)
    }

    @Test("minimum clamp also preserves a single scale factor while lifting the viewport above the raw zoom result")
    func minimumClampAlsoPreservesSingleScaleFactor() {
        let base = CGSize(width: 320, height: 240)
        let scaled = PinnedTextZoomGeometry.scaledViewportSize(
            baseViewport: base,
            zoomRatio: 0.3,
            minimumSize: CGSize(width: 220, height: 120),
            maximumSize: CGSize(width: 760, height: 540)
        )

        #expect(scaled.width == 220)
        #expect(scaled.height == 165)
        #expect(scaled.width > base.width * 0.3)
        #expect(scaled.height > base.height * 0.3)
        #expect(abs((scaled.width / base.width) - (scaled.height / base.height)) <= 0.0001)
    }
}
