#if DEBUG
import CoreGraphics
import Foundation
import Testing
@testable import SpokenAnyWhere

@Suite("LiveCaptionBottomProbeRuntimeHelpers 测试")
struct LiveCaptionBottomProbeRuntimeHelpersTests {

    @Test("bottom gap 为正时表示目标仍在底边之上")
    func bottomGapIsPositiveWhenTargetFits() {
        let viewport = CGRect(x: 0, y: 0, width: 300, height: 200)
        let target = CGRect(x: 0, y: 120, width: 280, height: 60)

        #expect(liveCaptionBottomGap(viewportFrame: viewport, targetFrame: target) == 20)
        #expect(liveCaptionBottomIsVisible(viewportFrame: viewport, targetFrame: target))
    }

    @Test("bottom gap 为负时表示目标底部已被裁出可视区")
    func bottomGapIsNegativeWhenTargetOverflows() {
        let viewport = CGRect(x: 0, y: 0, width: 300, height: 200)
        let target = CGRect(x: 0, y: 150, width: 280, height: 70)

        #expect(liveCaptionBottomGap(viewportFrame: viewport, targetFrame: target) == -20)
        #expect(!liveCaptionBottomIsVisible(viewportFrame: viewport, targetFrame: target))
    }

    @Test("probe 默认关闭，避免扰动普通 debug 启动")
    func probeDisabledByDefault() {
        #expect(!liveCaptionProbeIsEnabled([:]))
        #expect(!liveCaptionProbeIsEnabled(["SPOKE_DEBUG_LIVECAPTION_PROBE": "0"]))
    }

    @Test("probe 仅在显式环境变量开启时启用")
    func probeCanBeExplicitlyEnabled() {
        #expect(liveCaptionProbeIsEnabled(["SPOKE_DEBUG_LIVECAPTION_PROBE": "1"]))
        #expect(liveCaptionProbeIsEnabled(["SPOKE_DEBUG_LIVECAPTION_PROBE": "true"]))
    }

    @Test("非有限 frame 会被过滤掉")
    func nonFiniteFrameIsRejected() {
        #expect(!liveCaptionProbeFrameIsFinite(CGRect(x: CGFloat.infinity, y: 0, width: 10, height: 10)))
        #expect(liveCaptionProbeFrameIsFinite(CGRect(x: 0, y: 0, width: 10, height: 10)))
    }

    @Test("probe 可从 bootstrap 文件启用，供 open 模式验收使用")
    func probeCanBeEnabledFromBootstrapFile() throws {
        let bootstrapFilePath = FileManager.default.temporaryDirectory
            .appendingPathComponent("live-caption-probe-\(UUID().uuidString).txt")
            .path

        try "1".write(
            toFile: bootstrapFilePath,
            atomically: true,
            encoding: .utf8
        )
        defer {
            try? FileManager.default.removeItem(atPath: bootstrapFilePath)
        }

        #expect(
            liveCaptionProbeIsEnabled(
                [:],
                fileManager: FileManager.default,
                bootstrapFilePath: bootstrapFilePath
            )
        )
    }
}
#endif
