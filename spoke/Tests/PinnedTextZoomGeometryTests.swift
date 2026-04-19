import AppKit
import Testing
@testable import SpokenAnyWhere

@Suite("PinnedTextZoomGeometry tests")
@MainActor
struct PinnedTextZoomGeometryTests {
    @Test("uniform clamp keeps width and height on the same scale factor")
    func uniformClampKeepsWidthAndHeightOnSameScaleFactor() {
        let base = CGSize(width: 300, height: 150)
        let scaled = PinnedTextZoomGeometry.scaledViewportSize(
            baseViewport: base,
            zoomRatio: 2.0,
            minimumSize: CGSize(width: 220, height: 120),
            maximumSize: CGSize(width: 760, height: 540)
        )

        #expect(abs((scaled.width / base.width) - (scaled.height / base.height)) <= 0.0001)
    }

    @Test("minimum clamp also preserves a single scale factor")
    func minimumClampAlsoPreservesSingleScaleFactor() {
        let base = CGSize(width: 320, height: 240)
        let scaled = PinnedTextZoomGeometry.scaledViewportSize(
            baseViewport: base,
            zoomRatio: 0.3,
            minimumSize: CGSize(width: 220, height: 120),
            maximumSize: CGSize(width: 760, height: 540)
        )

        #expect(abs((scaled.width / base.width) - (scaled.height / base.height)) <= 0.0001)
    }
}
