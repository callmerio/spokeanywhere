import AppKit
import Foundation

@available(macOS 12.3, *)
func runSystemAudioCaptureOnMain(
    _ service: SystemAudioCaptureService?,
    _ action: @escaping @MainActor (SystemAudioCaptureService) -> Void
) {
    runtimeRunOnMain(owner: service, action)
}

func openSystemAudioCaptureSettings(
    workspace: NSWorkspace = .shared
) {
    guard let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    ) else {
        return
    }
    workspace.open(url)
}
