import CoreGraphics

@MainActor
enum PinnedTextZoomGeometry {
    static func scaledViewportSize(
        baseViewport: CGSize,
        zoomRatio: CGFloat,
        minimumSize: CGSize,
        maximumSize: CGSize
    ) -> CGSize {
        let target = CGSize(
            width: baseViewport.width * zoomRatio,
            height: baseViewport.height * zoomRatio
        )

        let maxScale = min(
            maximumSize.width / max(target.width, 0.0001),
            maximumSize.height / max(target.height, 0.0001),
            1.0
        )
        let minScale = max(
            minimumSize.width / max(target.width, 0.0001),
            minimumSize.height / max(target.height, 0.0001),
            1.0
        )

        let factor: CGFloat
        if target.width > maximumSize.width || target.height > maximumSize.height {
            factor = maxScale
        } else if target.width < minimumSize.width || target.height < minimumSize.height {
            factor = minScale
        } else {
            factor = 1.0
        }

        return CGSize(
            width: target.width * factor,
            height: target.height * factor
        )
    }
}
