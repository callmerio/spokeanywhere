#if DEBUG
import CoreGraphics
import Foundation

private let liveCaptionCollapsedFocusBottomInset: CGFloat = 40

enum LiveCaptionCollapsedFocusTargetKind: Equatable {
    case pendingTranslation
    case finalizedTranslation
}

struct LiveCaptionCollapsedFocusTarget: Equatable {
    let kind: LiveCaptionCollapsedFocusTargetKind
    let viewportFrame: CGRect
    let targetFrame: CGRect
}

func liveCaptionCollapsedPreferredTarget(
    viewport: LiveCaptionProbeSnapshot?,
    pending: LiveCaptionProbeSnapshot?,
    finalized: LiveCaptionProbeSnapshot?
) -> LiveCaptionCollapsedFocusTarget? {
    guard let viewport else { return nil }

    if let pending {
        return LiveCaptionCollapsedFocusTarget(
            kind: .pendingTranslation,
            viewportFrame: viewport.frame,
            targetFrame: pending.frame
        )
    }

    if let finalized {
        return LiveCaptionCollapsedFocusTarget(
            kind: .finalizedTranslation,
            viewportFrame: viewport.frame,
            targetFrame: finalized.frame
        )
    }

    return nil
}

func liveCaptionCollapsedTopGap(
    viewportFrame: CGRect,
    targetFrame: CGRect
) -> CGFloat {
    targetFrame.minY - viewportFrame.minY
}

func liveCaptionCollapsedBottomGap(
    viewportFrame: CGRect,
    targetFrame: CGRect
) -> CGFloat {
    targetFrame.maxY - viewportFrame.maxY
}

func liveCaptionCollapsedScrollDelta(
    viewportFrame: CGRect,
    targetFrame: CGRect
) -> CGFloat {
    if targetFrame.height > viewportFrame.height {
        return liveCaptionCollapsedBottomGap(
            viewportFrame: viewportFrame,
            targetFrame: targetFrame
        )
    }

    let visibleBottomGap = viewportFrame.maxY - targetFrame.maxY
    if visibleBottomGap < liveCaptionCollapsedFocusBottomInset {
        return liveCaptionCollapsedFocusBottomInset - visibleBottomGap
    }

    if targetFrame.minY < viewportFrame.minY {
        return liveCaptionCollapsedTopGap(
            viewportFrame: viewportFrame,
            targetFrame: targetFrame
        )
    }

    return 0
}
#endif
