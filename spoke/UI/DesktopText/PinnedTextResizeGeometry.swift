import CoreGraphics

enum PinnedTextResizeGeometry {
    static func clampedFrame(
        proposedFrame: CGRect,
        originalFrame: CGRect,
        minimumSize: CGSize,
        region: PinnedTextWindow.ResizeRegion
    ) -> CGRect {
        let preserveRightEdge = region == .left || region == .topLeft || region == .bottomLeft
        let preserveTopEdge = region == .bottom || region == .bottomLeft || region == .bottomRight

        let targetWidth: CGFloat
        if preserveRightEdge {
            targetWidth = max(minimumSize.width, originalFrame.maxX - proposedFrame.minX)
        } else {
            targetWidth = max(minimumSize.width, proposedFrame.maxX - originalFrame.minX)
        }

        let targetHeight: CGFloat
        if preserveTopEdge {
            targetHeight = max(minimumSize.height, originalFrame.maxY - proposedFrame.minY)
        } else {
            targetHeight = max(minimumSize.height, proposedFrame.maxY - originalFrame.minY)
        }

        let originX = preserveRightEdge
            ? originalFrame.maxX - targetWidth
            : originalFrame.minX
        let originY = preserveTopEdge
            ? originalFrame.maxY - targetHeight
            : originalFrame.minY

        return CGRect(
            x: originX,
            y: originY,
            width: targetWidth,
            height: targetHeight
        )
    }
}
