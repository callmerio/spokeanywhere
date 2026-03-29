import AppKit
import Foundation

struct ScreenCaptureServiceDependencies {
    let openScreenCaptureSettings: () -> Void
}

@MainActor
extension ScreenCaptureServiceDependencies {
    static let live = ScreenCaptureServiceDependencies(
        openScreenCaptureSettings: {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    )
}
