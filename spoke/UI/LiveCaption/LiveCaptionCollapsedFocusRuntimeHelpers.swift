import AppKit
import CoreGraphics
import Foundation

private let liveCaptionCollapsedFocusBottomInset: CGFloat = 40
private let liveCaptionCollapsedPaddingTolerance: CGFloat = 4

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
        let bottomGap = liveCaptionCollapsedBottomGap(
            viewportFrame: viewportFrame,
            targetFrame: targetFrame
        )
        if abs(bottomGap) <= liveCaptionCollapsedPaddingTolerance {
            return 0
        }
        return bottomGap
    }

    let topGap = liveCaptionCollapsedTopGap(
        viewportFrame: viewportFrame,
        targetFrame: targetFrame
    )
    if abs(topGap) <= liveCaptionCollapsedPaddingTolerance {
        return 0
    }
    if topGap < 0 {
        return topGap
    }

    let visibleBottomGap = viewportFrame.maxY - targetFrame.maxY
    let adjustedFocusBottomInset = liveCaptionCollapsedFocusBottomInset - liveCaptionCollapsedPaddingTolerance
    if visibleBottomGap < adjustedFocusBottomInset {
        let desiredDelta = liveCaptionCollapsedFocusBottomInset - visibleBottomGap
        return min(desiredDelta, topGap)
    }

    return 0
}

func liveCaptionCollapsedAdditionalBottomPadding(
    viewportFrame: CGRect,
    targetFrame: CGRect
) -> CGFloat {
    let visibleBottomGap = viewportFrame.maxY - targetFrame.maxY
    let desiredBottomGap: CGFloat =
        targetFrame.height > viewportFrame.height ? 0 : liveCaptionCollapsedFocusBottomInset
    let adjustedDesiredBottomGap = max(0, desiredBottomGap - liveCaptionCollapsedPaddingTolerance)

    return max(0, adjustedDesiredBottomGap - visibleBottomGap)
}

func liveCaptionMeasureTextHeight(
    text: String,
    fontSize: CGFloat,
    width: CGFloat,
    lineSpacing: CGFloat
) -> CGFloat {
    let resolvedText = text.isEmpty ? " " : text
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineBreakMode = .byWordWrapping
    paragraphStyle.lineSpacing = lineSpacing

    let rect = (resolvedText as NSString).boundingRect(
        with: CGSize(width: width, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: [
            .font: NSFont.systemFont(ofSize: fontSize),
            .paragraphStyle: paragraphStyle
        ]
    )

    return ceil(rect.height)
}

func liveCaptionCollapsedEstimatedPendingBlockHeight(
    originalText: String,
    translationText: String,
    textWidth: CGFloat,
    originalFontSize: CGFloat,
    translationFontSize: CGFloat,
    originalLineSpacing: CGFloat,
    translationLineSpacing: CGFloat,
    interTextSpacing: CGFloat
) -> CGFloat {
    let originalHeight = liveCaptionMeasureTextHeight(
        text: originalText,
        fontSize: originalFontSize,
        width: textWidth,
        lineSpacing: originalLineSpacing
    )
    let translationHeight = liveCaptionMeasureTextHeight(
        text: translationText,
        fontSize: translationFontSize,
        width: textWidth,
        lineSpacing: translationLineSpacing
    )

    return originalHeight + interTextSpacing + translationHeight
}

func liveCaptionCollapsedDynamicBottomPadding(
    viewportHeight: CGFloat,
    targetKind: LiveCaptionCollapsedFocusTargetKind,
    targetText: String,
    pendingLineActive: Bool,
    pendingOriginalText: String,
    pendingTranslationText: String,
    textWidth: CGFloat,
    originalFontSize: CGFloat,
    translationFontSize: CGFloat,
    originalLineSpacing: CGFloat,
    translationLineSpacing: CGFloat,
    interTextSpacing: CGFloat,
    itemSpacing: CGFloat,
    baseBottomPadding: CGFloat
) -> CGFloat {
    let targetHeight = liveCaptionMeasureTextHeight(
        text: targetText,
        fontSize: translationFontSize,
        width: textWidth,
        lineSpacing: translationLineSpacing
    )
    let desiredBottomGap = targetHeight > viewportHeight
        ? CGFloat(0)
        : max(0, liveCaptionCollapsedFocusBottomInset - liveCaptionCollapsedPaddingTolerance)

    var trailingHeight = baseBottomPadding
    if targetKind == .finalizedTranslation && pendingLineActive {
        trailingHeight += itemSpacing
        trailingHeight += liveCaptionCollapsedEstimatedPendingBlockHeight(
            originalText: pendingOriginalText,
            translationText: pendingTranslationText,
            textWidth: textWidth,
            originalFontSize: originalFontSize,
            translationFontSize: translationFontSize,
            originalLineSpacing: originalLineSpacing,
            translationLineSpacing: translationLineSpacing,
            interTextSpacing: interTextSpacing
        )
    }

    return max(0, desiredBottomGap - trailingHeight)
}
