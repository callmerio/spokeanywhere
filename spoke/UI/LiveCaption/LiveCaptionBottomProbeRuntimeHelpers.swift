import CoreGraphics
import Foundation
import OSLog
import SwiftUI

enum LiveCaptionProbeSlot: String {
    case viewportCollapsed
    case viewportExpanded
    case pendingCollapsed
    case pendingExpanded
    case finalizedCollapsed
    case finalizedExpanded
}

private let liveCaptionProbeLogger = Logger(subsystem: AppIdentity.logSubsystem, category: "LiveCaptionProbe")
private let liveCaptionProbeEnabledEnvKey = "SPOKE_DEBUG_LIVECAPTION_PROBE"
private let liveCaptionProbeBootstrapFilePath = "/tmp/spoke-livecaption-probe-enabled.txt"

struct LiveCaptionProbeSnapshot: Equatable {
    let slot: LiveCaptionProbeSlot
    let frame: CGRect
    let textLength: Int
}

struct LiveCaptionProbePreferenceKey: PreferenceKey {
    static let defaultValue: [LiveCaptionProbeSlot: LiveCaptionProbeSnapshot] = [:]

    static func reduce(value: inout [LiveCaptionProbeSlot: LiveCaptionProbeSnapshot], nextValue: () -> [LiveCaptionProbeSlot: LiveCaptionProbeSnapshot]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

func liveCaptionProbeIsEnabled(
    _ environment: [String: String] = ProcessInfo.processInfo.environment,
    fileManager: FileManager = .default,
    bootstrapFilePath: String = liveCaptionProbeBootstrapFilePath
) -> Bool {
    guard let raw = environment[liveCaptionProbeEnabledEnvKey]?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased() else {
        guard fileManager.fileExists(atPath: bootstrapFilePath),
              let raw = try? String(contentsOfFile: bootstrapFilePath, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !raw.isEmpty else {
            return false
        }

        return raw == "1" || raw == "true" || raw == "yes" || raw == "on"
    }

    guard !raw.isEmpty else { return false }
    return raw == "1" || raw == "true" || raw == "yes" || raw == "on"
}

func liveCaptionProbeFrameIsFinite(_ frame: CGRect) -> Bool {
    frame.minX.isFinite &&
    frame.minY.isFinite &&
    frame.width.isFinite &&
    frame.height.isFinite
}

func liveCaptionBottomGap(viewportFrame: CGRect, targetFrame: CGRect) -> CGFloat {
    viewportFrame.maxY - targetFrame.maxY
}

func liveCaptionBottomIsVisible(viewportFrame: CGRect, targetFrame: CGRect, tolerance: CGFloat = 1) -> Bool {
    targetFrame.maxY <= viewportFrame.maxY + tolerance
}

func liveCaptionLogBottomProbe(
    mode: String,
    snapshots: [LiveCaptionProbeSlot: LiveCaptionProbeSnapshot],
    isAtBottom: Bool,
    isUserSelecting: Bool,
    scrollTrigger: Int
) {
#if DEBUG
    guard liveCaptionProbeIsEnabled() else { return }

    let viewportSlot: LiveCaptionProbeSlot = mode == "expanded" ? .viewportExpanded : .viewportCollapsed
    let pendingSlot: LiveCaptionProbeSlot = mode == "expanded" ? .pendingExpanded : .pendingCollapsed
    let finalizedSlot: LiveCaptionProbeSlot = mode == "expanded" ? .finalizedExpanded : .finalizedCollapsed

    guard let viewport = snapshots[viewportSlot] else { return }
    let target = snapshots[pendingSlot] ?? snapshots[finalizedSlot]
    guard let target else { return }
    guard liveCaptionProbeFrameIsFinite(viewport.frame), liveCaptionProbeFrameIsFinite(target.frame) else { return }

    let gap = liveCaptionBottomGap(viewportFrame: viewport.frame, targetFrame: target.frame)
    let bottomVisible = liveCaptionBottomIsVisible(viewportFrame: viewport.frame, targetFrame: target.frame)

    liveCaptionProbeLogger.debug(
        "📏 probe mode=\(mode, privacy: .public) target=\(target.slot.rawValue, privacy: .public) textLength=\(target.textLength, privacy: .public) gap=\(gap, privacy: .public) bottomVisible=\(bottomVisible, privacy: .public) isAtBottom=\(isAtBottom, privacy: .public) isUserSelecting=\(isUserSelecting, privacy: .public) scrollTrigger=\(scrollTrigger, privacy: .public)"
    )
#else
    _ = mode
    _ = snapshots
    _ = isAtBottom
    _ = isUserSelecting
    _ = scrollTrigger
#endif
}

extension View {
    func liveCaptionProbeFrame(slot: LiveCaptionProbeSlot, textLength: Int = 0) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: LiveCaptionProbePreferenceKey.self,
                    value: [
                        slot: LiveCaptionProbeSnapshot(
                            slot: slot,
                            frame: geo.frame(in: .global),
                            textLength: textLength
                        )
                    ]
                )
            }
        )
    }
}
