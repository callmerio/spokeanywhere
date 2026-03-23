import AppKit
import Foundation
import ScreenCaptureKit

@MainActor
extension ScreenshotManagerDependencies {
    static let live = ScreenshotManagerDependencies(
        enhancementPath: {
            switch ScreenshotSettings.shared.upscalingMode {
            case .none:
                return "none"
            case .basic:
                return "basic"
            case .ai:
                return "ai-fallback"
            }
        },
        copyEnhancedImageEnabled: { ScreenshotSettings.shared.copyEnhancedImage },
        resetBlurDiagnostics: {
            if #available(macOS 12.3, *) {
                ScreenCaptureBlurService.shared.resetDiagnostics()
            }
        },
        blurMainDispatchP95: {
            if #available(macOS 12.3, *) {
                return ScreenCaptureBlurService.shared.getBlurMainDispatchP95()
            }
            return 0
        },
        blurCoverage: {
            if #available(macOS 12.3, *) {
                return ScreenCaptureBlurService.shared.coverageBlur
            }
            return false
        },
        captureScreen: { screen in
            await ScreenCaptureService.shared.captureScreen(screen)
        },
        copyImageToPasteboard: { image in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
        },
        openScreenCaptureSettings: {
            SystemAudioCaptureService.openScreenCaptureSettings()
        }
    )
}

